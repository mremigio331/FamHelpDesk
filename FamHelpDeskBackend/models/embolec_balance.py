from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute


class EmbolecBalanceModel(FamHelpDeskBaseModel):
    family_id = UnicodeAttribute()
    user_id = UnicodeAttribute()
    balance = NumberAttribute(default=0)
    last_refresh_date = NumberAttribute()  # epoch timestamp
    total_earned = NumberAttribute(default=0)
    total_spent = NumberAttribute(default=0)

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(user_id: str) -> str:
        return f"EMBOLEC_BALANCE#{user_id}"

    @staticmethod
    def clean_returned_balance(balance: "EmbolecBalanceModel") -> dict:
        return {
            "family_id": balance.family_id,
            "user_id": balance.user_id,
            "balance": float(balance.balance),
            "last_refresh_date": int(balance.last_refresh_date),
            "total_earned": float(balance.total_earned),
            "total_spent": float(balance.total_spent),
        }
