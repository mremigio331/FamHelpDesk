"""Helper class for managing Grab item reviews."""

import time
from typing import Optional, List, Dict, Any, Tuple
from aws_lambda_powertools import Logger

from models.base import FamHelpDeskBaseModel
from models.grab_item_review import GrabItemReviewModel
from models.grab_request import GrabRequestModel, GrabRequestStatus
from models.grab_request_item import GrabRequestItemModel
from helpers.grab_photo_helper import GrabPhotoHelper
from exceptions.grab_exceptions import (
    GrabRequestNotFoundException,
    InvalidGrabStatusTransitionException,
    GrabUnauthorizedException,
    InvalidStarRatingException,
    CommentTooLongException,
    InvalidItemIdException,
    ReviewWindowExpiredException,
)


# 48-hour window in seconds
REVIEW_WINDOW_SECONDS = 48 * 60 * 60


class GrabReviewHelper:
    """Helper class for creating, validating, and querying Grab item reviews."""

    def __init__(
        self,
        stage: str = None,
        table_name: str = None,
        notification_queue_url: str = None,
        photos_bucket: Optional[str] = None,
    ):
        self.logger = Logger()
        self.photos_bucket = photos_bucket
        GrabItemReviewModel.set_stage_and_table(
            stage, table_name, notification_queue_url
        )
        GrabRequestModel.set_stage_and_table(stage, table_name, notification_queue_url)
        GrabRequestItemModel.set_stage_and_table(
            stage, table_name, notification_queue_url
        )

    def validate_item_ratings(
        self,
        item_ratings: List[Dict[str, Any]],
        request_items: List[Dict[str, Any]],
    ) -> None:
        """
        Validate item ratings against the request's items.

        Checks:
        - star_rating is an integer between 1 and 5 inclusive
        - comment is at most 500 characters (if provided)
        - all item_ids belong to the request

        Args:
            item_ratings: List of dicts with item_id, star_rating, and optional comment
            request_items: List of item dicts from the request (with item_id field)

        Raises:
            InvalidStarRatingException: If star_rating is not 1-5
            CommentTooLongException: If comment exceeds 500 characters
            InvalidItemIdException: If item_id doesn't belong to the request
        """
        valid_item_ids = {item["item_id"] for item in request_items}

        for rating in item_ratings:
            # Validate star_rating
            star_rating = rating.get("star_rating")
            if not isinstance(star_rating, int) or star_rating < 1 or star_rating > 5:
                raise InvalidStarRatingException(
                    f"Star rating must be an integer between 1 and 5, got: {star_rating}"
                )

            # Validate comment length
            comment = rating.get("comment")
            if comment is not None and len(comment) > 500:
                raise CommentTooLongException(
                    f"Comment must be at most 500 characters, got: {len(comment)}"
                )

            # Validate item_id belongs to the request
            item_id = rating.get("item_id")
            if item_id not in valid_item_ids:
                raise InvalidItemIdException(
                    f"Item ID {item_id} does not belong to this request"
                )

    def create_reviews(
        self,
        family_id: str,
        request_id: str,
        reviewer_id: str,
        reviewee_id: str,
        item_ratings: List[Dict[str, Any]],
        items: List[Dict[str, Any]],
    ) -> List[dict]:
        """
        Create review records for each rated item. Writes dual records:
        - GRAB_REVIEW#{request_id}#ITEM#{item_id} (request-scoped)
        - USER_REVIEW#{reviewee_id}#{created_at}#{review_id} (user profile-scoped)

        Args:
            family_id: The family ID
            request_id: The request ID
            reviewer_id: The user submitting reviews (Requestor)
            reviewee_id: The user being reviewed (Claimer)
            item_ratings: List of dicts with item_id, star_rating, and optional comment
            items: List of item dicts from the request (with item_id and name fields)

        Returns:
            List of created review dicts
        """
        # Build item_id -> item_name lookup
        item_name_map = {item["item_id"]: item["name"] for item in items}

        now = FamHelpDeskBaseModel.now_epoch()
        pk = GrabItemReviewModel.create_pk(family_id)
        created_reviews = []

        for rating in item_ratings:
            item_id = rating["item_id"]
            review_id = FamHelpDeskBaseModel.generate_random_id("R")
            item_name = item_name_map.get(item_id, "Unknown Item")

            # Create the request-scoped record (GRAB_REVIEW#)
            review_sk = GrabItemReviewModel.create_review_sk(request_id, item_id)
            review_record = GrabItemReviewModel(
                pk=pk,
                sk=review_sk,
                review_id=review_id,
                family_id=family_id,
                request_id=request_id,
                item_id=item_id,
                item_name=item_name,
                reviewer_id=reviewer_id,
                reviewee_id=reviewee_id,
                star_rating=rating["star_rating"],
                created_at=now,
            )
            if rating.get("comment"):
                review_record.comment = rating["comment"]
            review_record.save()

            # Create the user profile-scoped record (USER_REVIEW#)
            user_review_sk = GrabItemReviewModel.create_user_review_sk(
                reviewee_id, now, review_id
            )
            user_review_record = GrabItemReviewModel(
                pk=pk,
                sk=user_review_sk,
                review_id=review_id,
                family_id=family_id,
                request_id=request_id,
                item_id=item_id,
                item_name=item_name,
                reviewer_id=reviewer_id,
                reviewee_id=reviewee_id,
                star_rating=rating["star_rating"],
                created_at=now,
            )
            if rating.get("comment"):
                user_review_record.comment = rating["comment"]
            user_review_record.save()

            created_reviews.append(
                GrabItemReviewModel.clean_returned_review(review_record)
            )

        self.logger.info(
            f"Created {len(created_reviews)} reviews for request {request_id} "
            f"in family {family_id}"
        )

        return created_reviews

    def submit_late_reviews(
        self,
        family_id: str,
        request_id: str,
        user_id: str,
        item_ratings: List[Dict[str, Any]],
    ) -> List[dict]:
        """
        Submit or update reviews within the 48-hour grace window after confirmation.

        Validates:
        - Request exists and is in CONFIRMED status
        - confirmed_at is within the last 48 hours
        - user_id is the requestor of the request
        - item_ratings are valid

        Args:
            family_id: The family ID
            request_id: The request ID
            user_id: The user submitting reviews (must be the requestor)
            item_ratings: List of dicts with item_id, star_rating, and optional comment

        Returns:
            List of created/updated review dicts

        Raises:
            GrabRequestNotFoundException: If request not found
            InvalidGrabStatusTransitionException: If request is not CONFIRMED
            ReviewWindowExpiredException: If 48-hour window has passed
            GrabUnauthorizedException: If user is not the requestor
            InvalidStarRatingException: If star_rating is not 1-5
            CommentTooLongException: If comment exceeds 500 characters
            InvalidItemIdException: If item_id doesn't belong to the request
        """
        # Get the request record
        request = self._get_request_record(family_id, request_id)

        # Check request status is CONFIRMED
        if request.status != GrabRequestStatus.CONFIRMED.value:
            raise InvalidGrabStatusTransitionException(
                f"Cannot submit reviews for request with status {request.status}. "
                f"Request must be CONFIRMED."
            )

        # Check 48-hour window
        now = int(time.time())
        confirmed_at = int(request.confirmed_at)
        if now - confirmed_at > REVIEW_WINDOW_SECONDS:
            raise ReviewWindowExpiredException(
                "The 48-hour review window has expired for this request"
            )

        # Check authorization - user must be the requestor
        if user_id != request.requestor_id:
            raise GrabUnauthorizedException(
                "Only the requestor can submit reviews for this request"
            )

        # Get request items for validation
        items = self._get_request_items(family_id, request_id)
        request_items = [{"item_id": item["item_id"]} for item in items]

        # Validate item ratings
        self.validate_item_ratings(item_ratings, request_items)

        # Create or update reviews (overwrite existing)
        pk = GrabItemReviewModel.create_pk(family_id)
        now_epoch = FamHelpDeskBaseModel.now_epoch()
        item_name_map = {item["item_id"]: item["name"] for item in items}
        reviewee_id = request.claimer_id

        created_reviews = []

        for rating in item_ratings:
            item_id = rating["item_id"]
            item_name = item_name_map.get(item_id, "Unknown Item")

            # Check if a review already exists for this item
            review_sk = GrabItemReviewModel.create_review_sk(request_id, item_id)
            existing_review = self._get_existing_review(pk, review_sk)

            if existing_review:
                # Update existing review
                existing_review.star_rating = rating["star_rating"]
                existing_review.comment = rating.get("comment")
                existing_review.updated_at = now_epoch
                existing_review.save()

                # Also update the USER_REVIEW# record
                user_review_sk = GrabItemReviewModel.create_user_review_sk(
                    reviewee_id,
                    int(existing_review.created_at),
                    existing_review.review_id,
                )
                existing_user_review = self._get_existing_review(pk, user_review_sk)
                if existing_user_review:
                    existing_user_review.star_rating = rating["star_rating"]
                    existing_user_review.comment = rating.get("comment")
                    existing_user_review.updated_at = now_epoch
                    existing_user_review.save()

                created_reviews.append(
                    GrabItemReviewModel.clean_returned_review(existing_review)
                )
            else:
                # Create new review records
                review_id = FamHelpDeskBaseModel.generate_random_id("R")

                # Request-scoped record
                review_record = GrabItemReviewModel(
                    pk=pk,
                    sk=review_sk,
                    review_id=review_id,
                    family_id=family_id,
                    request_id=request_id,
                    item_id=item_id,
                    item_name=item_name,
                    reviewer_id=user_id,
                    reviewee_id=reviewee_id,
                    star_rating=rating["star_rating"],
                    created_at=now_epoch,
                )
                if rating.get("comment"):
                    review_record.comment = rating["comment"]
                review_record.save()

                # User profile-scoped record
                user_review_sk = GrabItemReviewModel.create_user_review_sk(
                    reviewee_id, now_epoch, review_id
                )
                user_review_record = GrabItemReviewModel(
                    pk=pk,
                    sk=user_review_sk,
                    review_id=review_id,
                    family_id=family_id,
                    request_id=request_id,
                    item_id=item_id,
                    item_name=item_name,
                    reviewer_id=user_id,
                    reviewee_id=reviewee_id,
                    star_rating=rating["star_rating"],
                    created_at=now_epoch,
                )
                if rating.get("comment"):
                    user_review_record.comment = rating["comment"]
                user_review_record.save()

                created_reviews.append(
                    GrabItemReviewModel.clean_returned_review(review_record)
                )

        self.logger.info(
            f"Submitted {len(created_reviews)} late reviews for request {request_id} "
            f"in family {family_id} by user {user_id}"
        )

        return created_reviews

    def get_reviews_for_request(self, family_id: str, request_id: str) -> List[dict]:
        """
        Get all reviews for a specific Grab Request.

        Queries records with sk begins_with GRAB_REVIEW#{request_id}#ITEM#

        Args:
            family_id: The family ID
            request_id: The request ID

        Returns:
            List of review dicts
        """
        pk = GrabItemReviewModel.create_pk(family_id)
        sk_prefix = f"GRAB_REVIEW#{request_id}#ITEM#"

        results = list(
            GrabItemReviewModel.query(
                hash_key=pk,
                range_key_condition=GrabItemReviewModel.sk.startswith(sk_prefix),
            )
        )

        reviews = [GrabItemReviewModel.clean_returned_review(item) for item in results]

        self.logger.info(
            f"Retrieved {len(reviews)} reviews for request {request_id} "
            f"in family {family_id}"
        )

        return reviews

    def get_review_profile(
        self,
        family_id: str,
        user_id: str,
        limit: int = 20,
        last_key: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Get the review profile for a user within a family.

        Queries USER_REVIEW#{user_id}# records, computes average_rating and
        total_review_count, and returns paginated results sorted by created_at
        descending. Enriches reviews with presigned photo URLs for public photos.

        Args:
            family_id: The family ID
            user_id: The user whose review profile to retrieve
            limit: Page size (default 20)
            last_key: DynamoDB LastEvaluatedKey for pagination

        Returns:
            Dict with user_id, average_rating, total_review_count, reviews, last_key
        """
        pk = GrabItemReviewModel.create_pk(family_id)
        sk_prefix = f"USER_REVIEW#{user_id}#"

        # First, get ALL user reviews to compute aggregate stats
        all_results = list(
            GrabItemReviewModel.query(
                hash_key=pk,
                range_key_condition=GrabItemReviewModel.sk.startswith(sk_prefix),
                scan_index_forward=False,
            )
        )

        total_review_count = len(all_results)

        if total_review_count == 0:
            return {
                "user_id": user_id,
                "average_rating": None,
                "total_review_count": 0,
                "reviews": [],
                "last_key": None,
            }

        # Compute average rating
        total_stars = sum(int(item.star_rating) for item in all_results)
        average_rating = round(total_stars / total_review_count, 1)

        # Apply pagination
        query_kwargs = {
            "hash_key": pk,
            "range_key_condition": GrabItemReviewModel.sk.startswith(sk_prefix),
            "scan_index_forward": False,
            "limit": limit,
        }
        if last_key:
            query_kwargs["last_evaluated_key"] = last_key

        paginated_results = GrabItemReviewModel.query(**query_kwargs)
        page_items = []
        result_last_key = None

        paginated_review_models = list(paginated_results)

        # Batch-get associated GrabRequestItemModel records for photo enrichment
        item_map = self._batch_get_items_for_reviews(family_id, paginated_review_models)

        # Build enriched review responses
        photo_helper = GrabPhotoHelper(photos_bucket=self.photos_bucket)

        for review_model in paginated_review_models:
            review_dict = GrabItemReviewModel.clean_returned_review(review_model)
            review_dict = self._enrich_review_with_photo(
                review_dict, review_model, item_map, photo_helper
            )
            page_items.append(review_dict)

        result_last_key = paginated_results.last_evaluated_key

        return {
            "user_id": user_id,
            "average_rating": average_rating,
            "total_review_count": total_review_count,
            "reviews": page_items,
            "last_key": result_last_key,
        }

    def get_average_ratings_for_family(
        self, family_id: str
    ) -> Dict[str, Tuple[float, int]]:
        """
        Get average ratings for all users in a family for leaderboard integration.

        Queries all USER_REVIEW# records in the family, groups by reviewee_id,
        and computes average rating and count per user.

        Args:
            family_id: The family ID

        Returns:
            Dict mapping user_id to tuple of (average_rating, total_review_count)
        """
        pk = GrabItemReviewModel.create_pk(family_id)
        sk_prefix = "USER_REVIEW#"

        results = list(
            GrabItemReviewModel.query(
                hash_key=pk,
                range_key_condition=GrabItemReviewModel.sk.startswith(sk_prefix),
            )
        )

        # Group by reviewee_id
        user_ratings: Dict[str, List[int]] = {}
        for item in results:
            reviewee_id = item.reviewee_id
            if reviewee_id not in user_ratings:
                user_ratings[reviewee_id] = []
            user_ratings[reviewee_id].append(int(item.star_rating))

        # Compute averages
        result: Dict[str, Tuple[float, int]] = {}
        for uid, ratings in user_ratings.items():
            count = len(ratings)
            avg = round(sum(ratings) / count, 1)
            result[uid] = (avg, count)

        self.logger.info(
            f"Computed average ratings for {len(result)} users in family {family_id}"
        )

        return result

    def _batch_get_items_for_reviews(
        self,
        family_id: str,
        reviews: List[GrabItemReviewModel],
    ) -> Dict[str, GrabRequestItemModel]:
        """
        Batch-get GrabRequestItemModel records for a list of reviews.

        Args:
            family_id: The family ID
            reviews: List of review model instances

        Returns:
            Dict mapping "request_id#item_id" to GrabRequestItemModel instance
        """
        item_map: Dict[str, GrabRequestItemModel] = {}
        pk = GrabRequestItemModel.create_pk(family_id)

        for review in reviews:
            key = f"{review.request_id}#{review.item_id}"
            if key in item_map:
                continue
            try:
                sk = GrabRequestItemModel.create_sk(review.request_id, review.item_id)
                item = GrabRequestItemModel.get(hash_key=pk, range_key=sk)
                item_map[key] = item
            except Exception:
                # Graceful degradation: if item lookup fails, skip it
                self.logger.warning(
                    f"Failed to fetch item for review enrichment: "
                    f"family_id={family_id}, request_id={review.request_id}, "
                    f"item_id={review.item_id}"
                )

        return item_map

    def _enrich_review_with_photo(
        self,
        review_dict: Dict[str, Any],
        review_model: GrabItemReviewModel,
        item_map: Dict[str, GrabRequestItemModel],
        photo_helper: GrabPhotoHelper,
    ) -> Dict[str, Any]:
        """
        Enrich a review dict with photo URL and visibility fields.

        Rules:
        - If item has photo_visibility == "public" and non-null proof_photo_key:
          include photo_url (presigned URL) and photo_visibility
        - If item has photo_visibility == "private" or None:
          omit photo_url, include photo_visibility only if proof_photo_key exists
        - Graceful degradation: if presigned URL generation fails, log and omit photo fields

        Args:
            review_dict: The cleaned review dict to enrich
            review_model: The original review model instance
            item_map: Map of "request_id#item_id" to GrabRequestItemModel
            photo_helper: GrabPhotoHelper instance for URL generation

        Returns:
            The enriched review dict
        """
        key = f"{review_model.request_id}#{review_model.item_id}"
        item = item_map.get(key)

        if item is None:
            return review_dict

        proof_photo_key = getattr(item, "proof_photo_key", None)
        photo_visibility = getattr(item, "photo_visibility", None)

        if proof_photo_key is None:
            # No photo on item, omit photo fields
            return review_dict

        # Include photo_visibility field when item has a proof_photo_key
        review_dict["photo_visibility"] = photo_visibility

        if photo_visibility == "public":
            try:
                result = photo_helper.generate_public_view_url(proof_photo_key)
                review_dict["photo_url"] = result["view_url"]
            except Exception as e:
                # Graceful degradation: log error and omit photo_url
                self.logger.error(
                    f"Failed to generate presigned URL for photo: "
                    f"photo_key={proof_photo_key}, error={str(e)}"
                )
                # Remove photo fields on failure to avoid partial data
                review_dict.pop("photo_visibility", None)

        return review_dict

    def _get_request_record(self, family_id: str, request_id: str) -> GrabRequestModel:
        """
        Get a single Grab Request record from DynamoDB.

        Args:
            family_id: The family ID
            request_id: The request ID

        Returns:
            GrabRequestModel instance

        Raises:
            GrabRequestNotFoundException: If request not found
        """
        try:
            request = GrabRequestModel.get(
                hash_key=GrabRequestModel.create_pk(family_id),
                range_key=GrabRequestModel.create_sk(request_id),
            )
            return request
        except Exception:
            raise GrabRequestNotFoundException(
                f"Grab request {request_id} not found in family {family_id}"
            )

    def _get_request_items(
        self, family_id: str, request_id: str
    ) -> List[Dict[str, Any]]:
        """
        Get all items for a Grab Request.

        Args:
            family_id: The family ID
            request_id: The request ID

        Returns:
            List of item dicts with item_id and name fields
        """
        pk = GrabRequestItemModel.create_pk(family_id)
        sk_prefix = f"GRAB_REQUEST#{request_id}#ITEM#"

        results = list(
            GrabRequestItemModel.query(
                hash_key=pk,
                range_key_condition=GrabRequestItemModel.sk.startswith(sk_prefix),
            )
        )

        return [GrabRequestItemModel.clean_returned_item(item) for item in results]

    def _get_existing_review(self, pk: str, sk: str) -> Optional[GrabItemReviewModel]:
        """
        Try to get an existing review record by pk and sk.

        Args:
            pk: Partition key
            sk: Sort key

        Returns:
            GrabItemReviewModel instance or None if not found
        """
        try:
            return GrabItemReviewModel.get(hash_key=pk, range_key=sk)
        except Exception:
            return None
