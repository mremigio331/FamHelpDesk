from typing import Optional, List, Dict, Any
from aws_lambda_powertools import Logger
from aws_lambda_powertools.metrics import Metrics, MetricUnit

from constants.metrics import (
    API_METRICS_NAMESPACE,
    ORDER_CREATED_METRIC,
    ORDER_CONFIRMED_METRIC,
    ITEM_CONFIRMED_METRIC,
    FAMILY_ID_DIMENSION,
)
from models.base import FamHelpDeskBaseModel
from models.grab_request import GrabRequestModel, GrabRequestStatus
from models.grab_request_item import GrabRequestItemModel
from models.family_notification_settings import FamilyNotificationType
from helpers.notification_helper import NotificationHelper
from helpers.embolec_helper import EmbolecHelper
from exceptions.grab_exceptions import (
    GrabRequestNotFoundException,
    InvalidGrabStatusTransitionException,
    GrabUnauthorizedException,
    CannotClaimOwnRequestException,
    InvalidTipAmountException,
    InvalidItemIdException,
    ItemAlreadyClaimedException,
    InsufficientBalanceException,
    AllItemsConfirmedException,
)


class GrabRequestHelper:
    @staticmethod
    def compute_request_status(items: List[Dict[str, Any]]) -> str:
        """
        Derive the overall request status from the statuses of its items.

        Args:
            items: List of item dicts, each containing a "status" key.

        Returns:
            The computed request status string.
        """
        statuses = [item["status"] for item in items]
        non_cancelled = [s for s in statuses if s != "CANCELLED"]

        if not non_cancelled:  # all cancelled
            return "CANCELLED"
        if all(s == "CONFIRMED" for s in non_cancelled):
            return "CONFIRMED"
        if all(s in ("COMPLETED", "CONFIRMED") for s in non_cancelled) and any(
            s == "COMPLETED" for s in non_cancelled
        ):
            return "COMPLETED"
        if any(s == "COMPLETED" for s in non_cancelled) and any(
            s in ("OPEN", "CLAIMED") for s in non_cancelled
        ):
            return "PARTIALLY_COMPLETED"
        if all(
            s in ("CLAIMED", "COMPLETED", "CONFIRMED") for s in non_cancelled
        ) and any(s == "CLAIMED" for s in non_cancelled):
            return "CLAIMED"
        if any(s == "CLAIMED" for s in non_cancelled) and any(
            s == "OPEN" for s in non_cancelled
        ):
            return "PARTIALLY_CLAIMED"
        return "OPEN"

    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
        notification_queue_url: str = None,
    ):
        self.logger = Logger()
        self.request_id = request_id
        if request_id:
            self.logger.append_keys(request_id=request_id)
        GrabRequestModel.set_stage_and_table(stage, table_name, notification_queue_url)
        GrabRequestItemModel.set_stage_and_table(
            stage, table_name, notification_queue_url
        )
        self.notification_helper = NotificationHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )
        self.embolec_helper = EmbolecHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )

    def create_request(
        self,
        family_id: str,
        requestor_id: str,
        title: str,
        items: List[Dict[str, Any]],
        note: Optional[str] = None,
    ) -> dict:
        """
        Create a new Grab Request with status OPEN and associated items.
        The total embolec_cost is computed as the sum of all item costs.

        Args:
            family_id: The family ID
            requestor_id: The user creating the request
            title: Request title
            items: List of item dicts with name, embolec_cost, quantity (optional), note (optional)
            note: Optional note for the request

        Returns:
            dict with request and items data
        """
        request_id = FamHelpDeskBaseModel.generate_random_id()
        now = FamHelpDeskBaseModel.now_epoch()

        # Create item records and compute total cost
        created_items = []
        total_embolec_cost = 0
        for item_data in items:
            item_id = FamHelpDeskBaseModel.generate_random_id()
            item_cost = item_data.get("embolec_cost", 0)
            total_embolec_cost += item_cost
            item = GrabRequestItemModel(
                pk=GrabRequestItemModel.create_pk(family_id),
                sk=GrabRequestItemModel.create_sk(request_id, item_id),
                item_id=item_id,
                request_id=request_id,
                family_id=family_id,
                name=item_data["name"],
                quantity=item_data.get("quantity", 1),
                embolec_cost=item_cost,
            )
            if item_data.get("note"):
                item.note = item_data["note"]
            item.save()
            created_items.append(GrabRequestItemModel.clean_returned_item(item))

        # Create the request record with computed total
        request = GrabRequestModel(
            pk=GrabRequestModel.create_pk(family_id),
            sk=GrabRequestModel.create_sk(request_id),
            request_id=request_id,
            family_id=family_id,
            requestor_id=requestor_id,
            status=GrabRequestStatus.OPEN.value,
            embolec_cost=total_embolec_cost,
            title=title,
            created_at=now,
        )
        if note:
            request.note = note

        request.save()

        self.logger.info(
            f"Created grab request {request_id} with {len(created_items)} items "
            f"(total cost: {total_embolec_cost}) for family {family_id} by user {requestor_id}"
        )

        # Send notification
        self.notification_helper.create_notification_async(
            notification_type=FamilyNotificationType.GRAB_REQUEST_CREATED,
            family_id=family_id,
            request_id=request_id,
            requestor_id=requestor_id,
        )

        # Emit OrderCreated metric
        metrics = Metrics(namespace=API_METRICS_NAMESPACE)
        metrics.add_dimension(name=FAMILY_ID_DIMENSION, value=family_id)
        metrics.add_metric(name=ORDER_CREATED_METRIC, unit=MetricUnit.Count, value=1)
        metrics.flush_metrics()

        return {
            "request": GrabRequestModel.clean_returned_request(request),
            "items": created_items,
        }

    def claim_items(
        self,
        family_id: str,
        request_id: str,
        claimer_id: str,
        item_ids: List[str],
    ) -> dict:
        """
        Claim one or more items within a Grab Request.

        Args:
            family_id: The family ID
            request_id: The request ID
            claimer_id: The user claiming the items
            item_ids: List of item IDs to claim

        Returns:
            dict with updated items data

        Raises:
            GrabRequestNotFoundException: If request not found
            CannotClaimOwnRequestException: If claimer is the requestor
            InvalidItemIdException: If any item_id does not belong to the request
            InvalidGrabStatusTransitionException: If any item is not OPEN
            ItemAlreadyClaimedException: If any item already has a claimer
        """
        request = self._get_request_record(family_id, request_id)

        # Validate claimer is not the requestor
        if claimer_id == request.requestor_id:
            raise CannotClaimOwnRequestException("Cannot claim your own request items")

        # Get all items for the request (raw models for modification)
        item_models = self._get_request_item_models(family_id, request_id)
        item_map = {item.item_id: item for item in item_models}

        # Validate all item_ids belong to the request
        for item_id in item_ids:
            if item_id not in item_map:
                raise InvalidItemIdException(
                    f"Item ID {item_id} does not belong to this request"
                )

        # Validate all items are OPEN and not already claimed (all-or-nothing)
        for item_id in item_ids:
            item = item_map[item_id]
            if item.status != "OPEN":
                raise InvalidGrabStatusTransitionException(
                    f"Cannot claim item {item_id} with status {item.status}. "
                    f"Item must be OPEN."
                )
            if getattr(item, "claimer_id", None) is not None:
                raise ItemAlreadyClaimedException(
                    f"Item {item_id} is already claimed by another user"
                )

        # All validations passed - now modify items
        now = FamHelpDeskBaseModel.now_epoch()
        claimed_items = []
        for item_id in item_ids:
            item = item_map[item_id]
            item.status = "CLAIMED"
            item.claimer_id = claimer_id
            item.claimed_at = now
            item.save()
            claimed_items.append(GrabRequestItemModel.clean_returned_item(item))

        self.logger.info(
            f"Claimed {len(claimed_items)} items in request {request_id} "
            f"by {claimer_id} in family {family_id}"
        )

        # Send notification
        self.notification_helper.create_notification_async(
            notification_type=FamilyNotificationType.GRAB_ITEMS_CLAIMED,
            family_id=family_id,
            request_id=request_id,
            requestor_id=request.requestor_id,
            claimer_id=claimer_id,
            item_names=[item["name"] for item in claimed_items],
        )

        return {"items": claimed_items}

    def complete_items(
        self,
        family_id: str,
        request_id: str,
        user_id: str,
        item_ids: List[str],
        proof_photo_key: Optional[str] = None,
        photo_visibility: Optional[str] = None,
    ) -> dict:
        """
        Mark one or more claimed items as completed.

        Args:
            family_id: The family ID
            request_id: The request ID
            user_id: The user completing the items (must be claimer of each)
            item_ids: List of item IDs to complete
            proof_photo_key: Optional S3 key for proof photo
            photo_visibility: Optional visibility for proof photo ("public" or "private")

        Returns:
            dict with updated items data

        Raises:
            GrabRequestNotFoundException: If request not found
            InvalidItemIdException: If any item_id does not belong to the request
            GrabUnauthorizedException: If user is not the claimer of any item
            InvalidGrabStatusTransitionException: If any item is not CLAIMED
        """
        request = self._get_request_record(family_id, request_id)

        # Get all items for the request (raw models for modification)
        item_models = self._get_request_item_models(family_id, request_id)
        item_map = {item.item_id: item for item in item_models}

        # Validate all item_ids belong to the request
        for item_id in item_ids:
            if item_id not in item_map:
                raise InvalidItemIdException(
                    f"Item ID {item_id} does not belong to this request"
                )

        # Validate all items are CLAIMED and user is the claimer (all-or-nothing)
        for item_id in item_ids:
            item = item_map[item_id]
            if item.status != "CLAIMED":
                raise InvalidGrabStatusTransitionException(
                    f"Cannot complete item {item_id} with status {item.status}. "
                    f"Item must be CLAIMED."
                )
            if getattr(item, "claimer_id", None) != user_id:
                raise GrabUnauthorizedException(
                    f"Only the claimer can complete item {item_id}"
                )

        # All validations passed - moderate photo if provided
        if proof_photo_key:
            from helpers.content_moderation_helper import ContentModerationHelper

            moderation_helper = ContentModerationHelper(request_id=self.request_id)
            moderation_result = moderation_helper.moderate_image(
                s3_key=proof_photo_key,
                user_id=user_id,
                family_id=family_id,
                request_id=request_id,
                item_id=item_ids[0],
            )
            if not moderation_result["is_safe"]:
                # Image was quarantined - complete without photo
                self.logger.warning(
                    f"Photo {proof_photo_key} flagged by moderation, completing without photo"
                )
                proof_photo_key = None

        # Now modify items
        now = FamHelpDeskBaseModel.now_epoch()
        one_week_seconds = 7 * 24 * 60 * 60
        completed_items = []
        for idx, item_id in enumerate(item_ids):
            item = item_map[item_id]
            item.status = "COMPLETED"
            item.completed_at = now
            # Only apply the photo to the first item in the batch
            if proof_photo_key and idx == 0:
                item.proof_photo_key = proof_photo_key
                item.photo_visibility = (
                    photo_visibility if photo_visibility else "private"
                )
                item.photo_expires_at = now + one_week_seconds
            else:
                item.photo_visibility = None
            item.save()
            completed_items.append(GrabRequestItemModel.clean_returned_item(item))

        self.logger.info(
            f"Completed {len(completed_items)} items in request {request_id} "
            f"by {user_id} in family {family_id}"
        )

        # Send notification
        self.notification_helper.create_notification_async(
            notification_type=FamilyNotificationType.GRAB_ITEMS_COMPLETED,
            family_id=family_id,
            request_id=request_id,
            requestor_id=request.requestor_id,
            claimer_id=user_id,
            item_names=[item["name"] for item in completed_items],
        )

        # Check if all items are now completed/confirmed — if so, mark request as COMPLETED
        all_statuses = [item_map[m.item_id].status for m in item_models]
        non_cancelled = [s for s in all_statuses if s != "CANCELLED"]
        if non_cancelled and all(
            s in ("COMPLETED", "CONFIRMED") for s in non_cancelled
        ):
            request.status = GrabRequestStatus.COMPLETED.value
            request.completed_at = now
            request.save()
            self.logger.info(
                f"All items completed — request {request_id} marked as COMPLETED"
            )

        return {"items": completed_items}

    def confirm_items(
        self,
        family_id: str,
        request_id: str,
        user_id: str,
        item_ids: List[str],
        tip_amount: Optional[float] = None,
        item_ratings: Optional[List[Dict[str, Any]]] = None,
    ) -> dict:
        """
        Confirm delivery of one or more completed items and transfer Embolecs.

        Args:
            family_id: The family ID
            request_id: The request ID
            user_id: The user confirming (must be requestor)
            item_ids: List of item IDs to confirm
            tip_amount: Optional tip amount (must be >= 1 if provided)
            item_ratings: Optional list of dicts with item_id, star_rating, and optional comment

        Returns:
            dict with updated items, transactions, and optional reviews

        Raises:
            GrabRequestNotFoundException: If request not found
            GrabUnauthorizedException: If user is not the requestor
            InvalidItemIdException: If any item_id does not belong to the request
            InvalidGrabStatusTransitionException: If any item is not COMPLETED
            InsufficientBalanceException: If balance too low
            InvalidTipAmountException: If tip_amount < 1
        """
        request = self._get_request_record(family_id, request_id)

        # Validate user is the requestor
        if user_id != request.requestor_id:
            raise GrabUnauthorizedException("Only the requestor can confirm items")

        # Validate tip amount
        if tip_amount is not None and tip_amount <= 0:
            raise InvalidTipAmountException("Tip amount must be greater than 0")

        # Get all items for the request (raw models for modification)
        item_models = self._get_request_item_models(family_id, request_id)
        item_map = {item.item_id: item for item in item_models}

        # Validate all item_ids belong to the request
        for item_id in item_ids:
            if item_id not in item_map:
                raise InvalidItemIdException(
                    f"Item ID {item_id} does not belong to this request"
                )

        # Validate all items are COMPLETED (all-or-nothing)
        for item_id in item_ids:
            item = item_map[item_id]
            if item.status != "COMPLETED":
                raise InvalidGrabStatusTransitionException(
                    f"Cannot confirm item {item_id} with status {item.status}. "
                    f"Item must be COMPLETED."
                )

        # Calculate total cost of items being confirmed
        total_cost = sum(float(item_map[item_id].embolec_cost) for item_id in item_ids)
        total_transfer = total_cost + (tip_amount or 0)

        # Balance check
        balance_data = self.embolec_helper.get_or_create_balance(
            family_id, request.requestor_id
        )
        if balance_data["balance"] < total_transfer:
            raise InsufficientBalanceException(
                f"Insufficient balance. Need {total_transfer} Embolecs but only have {balance_data['balance']}"
            )

        # Group items by claimer_id for batched transfers
        claimer_items: Dict[str, List[str]] = {}
        for item_id in item_ids:
            item = item_map[item_id]
            cid = item.claimer_id
            if cid not in claimer_items:
                claimer_items[cid] = []
            claimer_items[cid].append(item_id)

        # Determine distinct claimers (ordered for tip distribution)
        distinct_claimers = list(claimer_items.keys())

        # Tip distribution: split evenly, remainder to first claimer
        tip_per_claimer = {}
        if tip_amount and tip_amount > 0:
            n_claimers = len(distinct_claimers)
            base_tip = round(tip_amount / n_claimers, 2)
            distributed = base_tip * (n_claimers - 1)
            first_claimer_tip = round(tip_amount - distributed, 2)
            for i, cid in enumerate(distinct_claimers):
                tip_per_claimer[cid] = first_claimer_tip if i == 0 else base_tip

        # Confirm items and perform transfers
        now = FamHelpDeskBaseModel.now_epoch()
        confirmed_items = []
        transactions = []

        for item_id in item_ids:
            item = item_map[item_id]
            item.status = "CONFIRMED"
            item.confirmed_at = now
            item.save()
            confirmed_items.append(GrabRequestItemModel.clean_returned_item(item))

        # Per-claimer Embolec transfers
        for cid in distinct_claimers:
            claimer_item_ids = claimer_items[cid]
            claimer_cost = sum(
                float(item_map[iid].embolec_cost) for iid in claimer_item_ids
            )
            claimer_tip = tip_per_claimer.get(cid, 0)
            transfer_amount = claimer_cost + claimer_tip

            if transfer_amount > 0:
                # Use the first item_id for the transaction record
                txn = self.embolec_helper.transfer_embolecs(
                    family_id=family_id,
                    from_user_id=request.requestor_id,
                    to_user_id=cid,
                    amount=transfer_amount,
                    grab_request_id=request_id,
                    item_id=claimer_item_ids[0] if len(claimer_item_ids) == 1 else None,
                )
                transactions.append(txn)

        self.logger.info(
            f"Confirmed {len(confirmed_items)} items in request {request_id} "
            f"by {user_id} in family {family_id}. "
            f"Transferred to {len(distinct_claimers)} distinct claimers."
        )

        result = {"items": confirmed_items, "transactions": transactions}

        # Handle item ratings if provided
        if item_ratings:
            from helpers.grab_review_helper import GrabReviewHelper

            review_helper = GrabReviewHelper()

            # Get items as dicts for validation
            all_items_dicts = [
                GrabRequestItemModel.clean_returned_item(m) for m in item_models
            ]
            request_items = [{"item_id": item["item_id"]} for item in all_items_dicts]

            # Validate item ratings
            review_helper.validate_item_ratings(item_ratings, request_items)

            # Create reviews per item, using item's claimer_id as reviewee_id
            all_reviews = []
            # Group ratings by claimer
            for rating in item_ratings:
                rated_item_id = rating["item_id"]
                rated_item = item_map.get(rated_item_id)
                if rated_item:
                    reviewee_id = rated_item.claimer_id
                    reviews = review_helper.create_reviews(
                        family_id=family_id,
                        request_id=request_id,
                        reviewer_id=user_id,
                        reviewee_id=reviewee_id,
                        item_ratings=[rating],
                        items=all_items_dicts,
                    )
                    all_reviews.extend(reviews)

            result["reviews"] = all_reviews

        # Send GRAB_ITEMS_CONFIRMED notification per distinct claimer
        for cid in distinct_claimers:
            claimer_item_ids = claimer_items[cid]
            claimer_cost = sum(
                float(item_map[iid].embolec_cost) for iid in claimer_item_ids
            )
            claimer_tip = tip_per_claimer.get(cid, 0)
            total_earned = claimer_cost + claimer_tip

            self.notification_helper.create_notification_async(
                notification_type=FamilyNotificationType.GRAB_ITEMS_CONFIRMED,
                family_id=family_id,
                request_id=request_id,
                requestor_id=request.requestor_id,
                claimer_id=cid,
                item_names=[item_map[iid].name for iid in claimer_item_ids],
                total_earned=total_earned,
            )

        # Emit ItemConfirmed metric
        metrics = Metrics(namespace=API_METRICS_NAMESPACE)
        metrics.add_dimension(name=FAMILY_ID_DIMENSION, value=family_id)
        metrics.add_metric(
            name=ITEM_CONFIRMED_METRIC, unit=MetricUnit.Count, value=len(item_ids)
        )
        metrics.flush_metrics()

        # Check if all items are now confirmed — if so, mark the request as CONFIRMED
        all_items_after = [item_map[m.item_id] for m in item_models]
        all_statuses = [item.status for item in all_items_after]
        non_cancelled = [s for s in all_statuses if s != "CANCELLED"]
        if non_cancelled and all(s == "CONFIRMED" for s in non_cancelled):
            request.status = GrabRequestStatus.CONFIRMED.value
            request.confirmed_at = now
            request.save()
            self.logger.info(
                f"All items confirmed — request {request_id} marked as CONFIRMED"
            )

        return result

    def cancel_items(
        self,
        family_id: str,
        request_id: str,
        user_id: str,
        item_ids: List[str],
    ) -> dict:
        """
        Cancel one or more items within a Grab Request.

        Authorization:
        - Requestor can cancel any non-confirmed item
        - Claimer can cancel only their own CLAIMED/COMPLETED items

        Behavior:
        - CLAIMED/COMPLETED items: reset to OPEN (clear claiming fields)
        - OPEN items: set to CANCELLED with cancelled_at and cancelled_by

        Args:
            family_id: The family ID
            request_id: The request ID
            user_id: The user cancelling
            item_ids: List of item IDs to cancel

        Returns:
            dict with updated items data

        Raises:
            GrabRequestNotFoundException: If request not found
            InvalidItemIdException: If any item_id does not belong to the request
            InvalidGrabStatusTransitionException: If any item is CONFIRMED
            GrabUnauthorizedException: If user not authorized to cancel an item
        """
        request = self._get_request_record(family_id, request_id)
        is_requestor = user_id == request.requestor_id

        # Get all items for the request (raw models for modification)
        item_models = self._get_request_item_models(family_id, request_id)
        item_map = {item.item_id: item for item in item_models}

        # Validate all item_ids belong to the request
        for item_id in item_ids:
            if item_id not in item_map:
                raise InvalidItemIdException(
                    f"Item ID {item_id} does not belong to this request"
                )

        # Validate all items can be cancelled (all-or-nothing)
        for item_id in item_ids:
            item = item_map[item_id]
            # Cannot cancel CONFIRMED items
            if item.status == "CONFIRMED":
                raise InvalidGrabStatusTransitionException(
                    f"Cannot cancel item {item_id} with status CONFIRMED"
                )
            # Authorization check
            if not is_requestor:
                # Non-requestor can only cancel their own claimed/completed items
                if getattr(item, "claimer_id", None) != user_id:
                    raise GrabUnauthorizedException(
                        f"Not authorized to cancel item {item_id}"
                    )

        # All validations passed - now modify items
        now = FamHelpDeskBaseModel.now_epoch()
        updated_items = []
        for item_id in item_ids:
            item = item_map[item_id]
            if item.status in ("CLAIMED", "COMPLETED"):
                # Reset to OPEN for re-claiming
                item.status = "OPEN"
                item.claimer_id = None
                item.claimed_at = None
                item.completed_at = None
                item.cancelled_at = None
                item.cancelled_by = None
                if hasattr(item, "proof_photo_key"):
                    item.proof_photo_key = None
            elif item.status == "OPEN":
                # Cancel the OPEN item
                item.status = "CANCELLED"
                item.cancelled_at = now
                item.cancelled_by = user_id
            item.save()
            updated_items.append(GrabRequestItemModel.clean_returned_item(item))

        self.logger.info(
            f"Cancelled {len(updated_items)} items in request {request_id} "
            f"by {user_id} in family {family_id}"
        )

        # Send notification
        self.notification_helper.create_notification_async(
            notification_type=FamilyNotificationType.GRAB_ITEMS_CANCELLED,
            family_id=family_id,
            request_id=request_id,
            requestor_id=request.requestor_id,
            cancelled_by=user_id,
            item_names=[item["name"] for item in updated_items],
        )

        return {"items": updated_items}

    def get_request(self, family_id: str, request_id: str) -> dict:
        """
        Get a Grab Request with its items. Includes computed request status
        derived from item statuses. If the computed status is CONFIRMED,
        also includes associated Item_Review records (if any exist).

        Args:
            family_id: The family ID
            request_id: The request ID

        Returns:
            dict with request, items, and optionally reviews data

        Raises:
            GrabRequestNotFoundException: If request not found
        """
        # Get the request record
        request = self._get_request_record(family_id, request_id)

        # Get items separately using the correct model
        items = self._get_request_items(family_id, request_id)

        # Compute derived status from items
        computed_status = self.compute_request_status(items) if items else "OPEN"

        request_data = GrabRequestModel.clean_returned_request(request)
        request_data["status"] = computed_status

        response = {
            "request": request_data,
            "items": items,
        }

        # Include reviews for CONFIRMED requests if any exist
        if computed_status == "CONFIRMED":
            try:
                from helpers.grab_review_helper import GrabReviewHelper

                review_helper = GrabReviewHelper()
                reviews = review_helper.get_reviews_for_request(family_id, request_id)
                if reviews:
                    response["reviews"] = reviews
            except Exception as e:
                self.logger.warning(
                    f"Failed to fetch reviews for request {request_id}: {e}"
                )

        return response

    def claim_request(self, family_id: str, request_id: str, claimer_id: str) -> dict:
        """
        Claim an open Grab Request.

        Args:
            family_id: The family ID
            request_id: The request ID
            claimer_id: The user claiming the request

        Returns:
            dict with updated request data

        Raises:
            GrabRequestNotFoundException: If request not found
            InvalidGrabStatusTransitionException: If request is not OPEN
            CannotClaimOwnRequestException: If claimer is the requestor
        """
        request = self._get_request_record(family_id, request_id)

        # Validate status
        if request.status != GrabRequestStatus.OPEN.value:
            raise InvalidGrabStatusTransitionException(
                f"Cannot claim request with status {request.status}. "
                f"Request must be OPEN."
            )

        # Validate claimer is not the requestor
        if claimer_id == request.requestor_id:
            raise CannotClaimOwnRequestException("Cannot claim your own request")

        # Transition to CLAIMED
        now = FamHelpDeskBaseModel.now_epoch()
        request.status = GrabRequestStatus.CLAIMED.value
        request.claimer_id = claimer_id
        request.claimed_at = now
        request.save()

        self.logger.info(
            f"Grab request {request_id} claimed by {claimer_id} in family {family_id}"
        )

        # Send notification
        self.notification_helper.create_notification_async(
            notification_type=FamilyNotificationType.GRAB_REQUEST_CLAIMED,
            family_id=family_id,
            request_id=request_id,
            requestor_id=request.requestor_id,
            claimer_id=claimer_id,
        )

        return {"request": GrabRequestModel.clean_returned_request(request)}

    def complete_request(
        self,
        family_id: str,
        request_id: str,
        user_id: str,
        proof_photo_key: Optional[str] = None,
    ) -> dict:
        """
        Mark a claimed Grab Request as completed.

        Args:
            family_id: The family ID
            request_id: The request ID
            user_id: The user completing the request (must be claimer)
            proof_photo_key: Optional S3 key for proof photo

        Returns:
            dict with updated request data

        Raises:
            GrabRequestNotFoundException: If request not found
            InvalidGrabStatusTransitionException: If request is not CLAIMED
            GrabUnauthorizedException: If user is not the claimer
        """
        request = self._get_request_record(family_id, request_id)

        # Validate status
        if request.status != GrabRequestStatus.CLAIMED.value:
            raise InvalidGrabStatusTransitionException(
                f"Cannot complete request with status {request.status}. "
                f"Request must be CLAIMED."
            )

        # Validate user is the claimer
        if user_id != request.claimer_id:
            raise GrabUnauthorizedException("Only the claimer can complete a request")

        # Transition to COMPLETED
        now = FamHelpDeskBaseModel.now_epoch()
        request.status = GrabRequestStatus.COMPLETED.value
        request.completed_at = now
        if proof_photo_key:
            request.proof_photo_key = proof_photo_key
        request.save()

        self.logger.info(
            f"Grab request {request_id} completed by {user_id} in family {family_id}"
        )

        # Send notification
        self.notification_helper.create_notification_async(
            notification_type=FamilyNotificationType.GRAB_REQUEST_COMPLETED,
            family_id=family_id,
            request_id=request_id,
            requestor_id=request.requestor_id,
            claimer_id=user_id,
        )

        return {"request": GrabRequestModel.clean_returned_request(request)}

    def confirm_request(
        self,
        family_id: str,
        request_id: str,
        user_id: str,
        tip_amount: Optional[float] = None,
        item_ratings: Optional[List[Dict[str, Any]]] = None,
    ) -> dict:
        """
        Confirm delivery of a completed Grab Request and transfer Embolecs.
        Optionally create item reviews if item_ratings are provided.

        Args:
            family_id: The family ID
            request_id: The request ID
            user_id: The user confirming (must be requestor)
            tip_amount: Optional tip amount (must be >= 1 if provided)
            item_ratings: Optional list of dicts with item_id, star_rating, and optional comment

        Returns:
            dict with updated request data and optional reviews

        Raises:
            GrabRequestNotFoundException: If request not found
            InvalidGrabStatusTransitionException: If request is not COMPLETED
            GrabUnauthorizedException: If user is not the requestor
            InvalidTipAmountException: If tip_amount < 1
            InvalidStarRatingException: If star_rating is not 1-5
            CommentTooLongException: If comment exceeds 500 characters
            InvalidItemIdException: If item_id doesn't belong to the request
        """
        request = self._get_request_record(family_id, request_id)

        # Validate status
        if request.status != GrabRequestStatus.COMPLETED.value:
            raise InvalidGrabStatusTransitionException(
                f"Cannot confirm request with status {request.status}. "
                f"Request must be COMPLETED."
            )

        # Validate user is the requestor
        if user_id != request.requestor_id:
            raise GrabUnauthorizedException("Only the requestor can confirm a request")

        # Validate tip amount
        if tip_amount is not None and tip_amount <= 0:
            raise InvalidTipAmountException("Tip amount must be greater than 0")

        # Transition to CONFIRMED
        now = FamHelpDeskBaseModel.now_epoch()
        request.status = GrabRequestStatus.CONFIRMED.value
        request.confirmed_at = now
        if tip_amount is not None:
            request.tip_amount = tip_amount
        request.save()

        # Transfer Embolecs: embolec_cost + tip_amount
        transfer_amount = float(request.embolec_cost) + (tip_amount or 0)
        self.embolec_helper.transfer_embolecs(
            family_id=family_id,
            from_user_id=request.requestor_id,
            to_user_id=request.claimer_id,
            amount=transfer_amount,
            grab_request_id=request_id,
        )

        self.logger.info(
            f"Grab request {request_id} confirmed by {user_id} in family {family_id}. "
            f"Transferred {transfer_amount} Embolecs to {request.claimer_id}"
        )

        # Send confirmation notification
        self.notification_helper.create_notification_async(
            notification_type=FamilyNotificationType.GRAB_REQUEST_CONFIRMED,
            family_id=family_id,
            request_id=request_id,
            requestor_id=request.requestor_id,
            claimer_id=request.claimer_id,
        )

        # Emit OrderConfirmed metric
        metrics = Metrics(namespace=API_METRICS_NAMESPACE)
        metrics.add_dimension(name=FAMILY_ID_DIMENSION, value=family_id)
        metrics.add_metric(name=ORDER_CONFIRMED_METRIC, unit=MetricUnit.Count, value=1)
        metrics.flush_metrics()

        result = {"request": GrabRequestModel.clean_returned_request(request)}

        # Handle item ratings if provided
        if item_ratings:
            from helpers.grab_review_helper import GrabReviewHelper

            review_helper = GrabReviewHelper()

            # Get request items for validation
            items = self._get_request_items(family_id, request_id)
            request_items = [{"item_id": item["item_id"]} for item in items]

            # Validate item ratings
            review_helper.validate_item_ratings(item_ratings, request_items)

            # Create review records
            reviews = review_helper.create_reviews(
                family_id=family_id,
                request_id=request_id,
                reviewer_id=user_id,
                reviewee_id=request.claimer_id,
                item_ratings=item_ratings,
                items=items,
            )

            result["reviews"] = reviews

            # Compute average rating for notification
            total_stars = sum(r["star_rating"] for r in item_ratings)
            average_rating = round(total_stars / len(item_ratings), 1)

            # Send GRAB_REVIEW_RECEIVED notification
            self.notification_helper.create_notification_async(
                notification_type=FamilyNotificationType.GRAB_REVIEW_RECEIVED,
                family_id=family_id,
                request_id=request_id,
                requestor_id=request.requestor_id,
                claimer_id=request.claimer_id,
                request_title=request.title,
                average_rating=average_rating,
            )

        return result

    def _get_request_items(
        self, family_id: str, request_id: str
    ) -> List[Dict[str, Any]]:
        """
        Get all items for a Grab Request as cleaned dicts.

        Args:
            family_id: The family ID
            request_id: The request ID

        Returns:
            List of item dicts
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

    def _get_request_item_models(
        self, family_id: str, request_id: str
    ) -> List[GrabRequestItemModel]:
        """
        Get all items for a Grab Request as raw model instances.

        Args:
            family_id: The family ID
            request_id: The request ID

        Returns:
            List of GrabRequestItemModel instances
        """
        pk = GrabRequestItemModel.create_pk(family_id)
        sk_prefix = f"GRAB_REQUEST#{request_id}#ITEM#"

        return list(
            GrabRequestItemModel.query(
                hash_key=pk,
                range_key_condition=GrabRequestItemModel.sk.startswith(sk_prefix),
            )
        )

    def cancel_request(self, family_id: str, request_id: str, user_id: str) -> dict:
        """
        Cancel an entire Grab Request. Cancels all non-confirmed items:
        - CLAIMED/COMPLETED items are reset to OPEN (clear claiming fields)
        - OPEN items are set to CANCELLED
        - CONFIRMED items are left unchanged
        Sets cancelled_at on the request record.

        Args:
            family_id: The family ID
            request_id: The request ID
            user_id: The user cancelling (must be requestor)

        Returns:
            dict with updated request and items data

        Raises:
            GrabRequestNotFoundException: If request not found
            GrabUnauthorizedException: If user is not the requestor
            AllItemsConfirmedException: If all items are already CONFIRMED
        """
        request = self._get_request_record(family_id, request_id)

        # Validate user is requestor
        if user_id != request.requestor_id:
            raise GrabUnauthorizedException("Only the requestor can cancel a request")

        # Get all items
        item_models = self._get_request_item_models(family_id, request_id)

        # Check if all items are CONFIRMED
        non_confirmed = [item for item in item_models if item.status != "CONFIRMED"]
        if not non_confirmed:
            raise AllItemsConfirmedException(
                "All items are already confirmed. Cannot cancel this request."
            )

        # Cancel all non-confirmed items
        now = FamHelpDeskBaseModel.now_epoch()
        updated_items = []
        for item in item_models:
            if item.status == "CONFIRMED":
                # Leave confirmed items unchanged
                updated_items.append(GrabRequestItemModel.clean_returned_item(item))
                continue
            if item.status in ("CLAIMED", "COMPLETED"):
                # Reset to OPEN
                item.status = "OPEN"
                item.claimer_id = None
                item.claimed_at = None
                item.completed_at = None
                item.cancelled_at = None
                item.cancelled_by = None
                if hasattr(item, "proof_photo_key"):
                    item.proof_photo_key = None
            elif item.status == "OPEN":
                # Cancel OPEN items
                item.status = "CANCELLED"
                item.cancelled_at = now
                item.cancelled_by = user_id
            item.save()
            updated_items.append(GrabRequestItemModel.clean_returned_item(item))

        # Set cancelled_at on request record
        request.cancelled_at = now
        request.cancelled_by = user_id
        request.save()

        self.logger.info(
            f"Grab request {request_id} cancelled by {user_id} in family {family_id}"
        )

        # Send notification
        self.notification_helper.create_notification_async(
            notification_type=FamilyNotificationType.GRAB_REQUEST_CANCELLED,
            family_id=family_id,
            request_id=request_id,
            requestor_id=request.requestor_id,
            cancelled_by=user_id,
        )

        # Compute derived status for response
        computed_status = self.compute_request_status(updated_items)
        request_data = GrabRequestModel.clean_returned_request(request)
        request_data["status"] = computed_status

        return {"request": request_data, "items": updated_items}

    def list_requests(
        self,
        family_id: str,
        status: Optional[str] = None,
        user_role: Optional[str] = None,
        user_id: Optional[str] = None,
        start_date: Optional[int] = None,
        end_date: Optional[int] = None,
        limit: int = 20,
        last_key: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        List Grab Requests for a family with optional filters and pagination.

        Args:
            family_id: The family ID
            status: Optional status filter (OPEN, CLAIMED, COMPLETED, CONFIRMED, CANCELLED)
            user_role: Optional role filter ("requestor" or "claimer")
            user_id: The current user's ID (required if user_role is provided)
            start_date: Optional start date filter (epoch timestamp)
            end_date: Optional end date filter (epoch timestamp)
            limit: Page size (default 20, max 50)
            last_key: DynamoDB LastEvaluatedKey for pagination

        Returns:
            dict with requests list and last_key for pagination
        """
        # Enforce max limit
        if limit > 50:
            limit = 50

        pk = GrabRequestModel.create_pk(family_id)

        # Query all GRAB_REQUEST# items for this family
        query_kwargs = {
            "hash_key": pk,
            "range_key_condition": GrabRequestModel.sk.startswith("GRAB_REQUEST#"),
        }

        if last_key:
            query_kwargs["last_evaluated_key"] = last_key

        results = GrabRequestModel.query(**query_kwargs)

        # Filter and collect requests
        requests = []
        for item in results:
            # Filter out items (items have #ITEM# in their sk)
            if "#ITEM#" in item.sk:
                continue

            # Skip records that don't have required request attributes
            if not getattr(item, "status", None) or not getattr(
                item, "requestor_id", None
            ):
                continue

            # Apply status filter
            if status and item.status != status:
                continue

            # Apply user_role filter
            if user_role and user_id:
                if user_role == "requestor" and item.requestor_id != user_id:
                    continue
                if user_role == "claimer":
                    if (
                        getattr(item, "claimer_id", None) is None
                        or item.claimer_id != user_id
                    ):
                        continue

            # Apply date range filters
            if (
                start_date
                and getattr(item, "created_at", None)
                and item.created_at < start_date
            ):
                continue
            if (
                end_date
                and getattr(item, "created_at", None)
                and item.created_at > end_date
            ):
                continue

            try:
                request_data = GrabRequestModel.clean_returned_request(item)
            except (AttributeError, TypeError) as e:
                self.logger.warning(f"Skipping malformed record {item.sk}: {e}")
                continue

            # Compute derived status from items
            request_items = self._get_request_items(family_id, item.request_id)
            if request_items:
                computed_status = self.compute_request_status(request_items)
                request_data["status"] = computed_status

            requests.append(request_data)

        # Sort by created_at descending
        requests.sort(key=lambda x: x["created_at"], reverse=True)

        # Apply pagination limit
        paginated_requests = requests[:limit]
        next_key = None
        if len(requests) > limit:
            # For client-side pagination, we use the last item's key
            last_request = paginated_requests[-1]
            next_key = {
                "pk": {"S": pk},
                "sk": {"S": GrabRequestModel.create_sk(last_request["request_id"])},
            }

        self.logger.info(
            f"Listed {len(paginated_requests)} grab requests for family {family_id}, "
            f"total matching: {len(requests)}, limit: {limit}"
        )

        return {
            "requests": paginated_requests,
            "last_key": next_key,
        }

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
