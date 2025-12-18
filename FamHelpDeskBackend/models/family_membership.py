from models.base import FamHelpDeskBaseModel, MembershipStatus
from pynamodb.attributes import UnicodeAttribute, BooleanAttribute, NumberAttribute


class FamilyMembershipModel(FamHelpDeskBaseModel):
    family_id = UnicodeAttribute()
    user_id = UnicodeAttribute()
    status = UnicodeAttribute()
    is_admin = BooleanAttribute()
    request_date = NumberAttribute()

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(user_id: str) -> str:
        return f"MEMBER#{user_id}"

    @staticmethod
    def clean_returned_membership(membership: "FamilyMembershipModel") -> dict:
        return {
            "family_id": membership.family_id,
            "user_id": membership.user_id,
            "status": membership.status,
            "is_admin": membership.is_admin,
            "request_date": membership.request_date,
        }
