from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute


class GrabItemReviewModel(FamHelpDeskBaseModel):
    # Primary record (request-scoped):
    #   pk: FAMILY#{family_id}
    #   sk: GRAB_REVIEW#{request_id}#ITEM#{item_id}
    #
    # Secondary record (user profile-scoped):
    #   pk: FAMILY#{family_id}
    #   sk: USER_REVIEW#{reviewee_id}#{created_at}#{review_id}

    review_id = UnicodeAttribute()
    family_id = UnicodeAttribute()
    request_id = UnicodeAttribute()
    item_id = UnicodeAttribute()
    item_name = UnicodeAttribute()  # denormalized from GrabRequestItem
    reviewer_id = UnicodeAttribute()  # the Requestor
    reviewee_id = UnicodeAttribute()  # the Claimer
    star_rating = NumberAttribute()  # 1–5 inclusive
    comment = UnicodeAttribute(null=True)  # max 500 chars
    created_at = NumberAttribute()  # epoch seconds
    updated_at = NumberAttribute(null=True)  # epoch seconds, set on update

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_review_sk(request_id: str, item_id: str) -> str:
        return f"GRAB_REVIEW#{request_id}#ITEM#{item_id}"

    @staticmethod
    def create_user_review_sk(reviewee_id: str, created_at: int, review_id: str) -> str:
        return f"USER_REVIEW#{reviewee_id}#{created_at}#{review_id}"

    @staticmethod
    def clean_returned_review(item: "GrabItemReviewModel") -> dict:
        data = {
            "review_id": item.review_id,
            "family_id": item.family_id,
            "request_id": item.request_id,
            "item_id": item.item_id,
            "item_name": item.item_name,
            "reviewer_id": item.reviewer_id,
            "reviewee_id": item.reviewee_id,
            "star_rating": int(item.star_rating),
            "created_at": int(item.created_at),
        }
        if getattr(item, "comment", None) is not None:
            data["comment"] = item.comment
        if getattr(item, "updated_at", None) is not None:
            data["updated_at"] = int(item.updated_at)
        return data
