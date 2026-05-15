from enum import Enum
from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute


class TransactionType(str, Enum):
    MONTHLY_REFRESH = "MONTHLY_REFRESH"
    GRAB_PAYMENT = "GRAB_PAYMENT"


class EmbolecTransactionModel(FamHelpDeskBaseModel):
    transaction_id = UnicodeAttribute()
    family_id = UnicodeAttribute()
    from_user_id = UnicodeAttribute()  # "SYSTEM" for monthly refresh
    to_user_id = UnicodeAttribute()
    amount = NumberAttribute()
    transaction_type = UnicodeAttribute()  # TransactionType enum value
    grab_request_id = UnicodeAttribute(null=True)
    item_id = UnicodeAttribute(null=True)
    created_at = NumberAttribute()
    note = UnicodeAttribute(null=True)

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(transaction_id: str) -> str:
        return f"EMBOLEC_TXN#{transaction_id}"

    @staticmethod
    def clean_returned_transaction(transaction: "EmbolecTransactionModel") -> dict:
        data = {
            "transaction_id": transaction.transaction_id,
            "family_id": transaction.family_id,
            "from_user_id": transaction.from_user_id,
            "to_user_id": transaction.to_user_id,
            "amount": float(transaction.amount),
            "transaction_type": transaction.transaction_type,
            "created_at": int(transaction.created_at),
        }
        if getattr(transaction, "grab_request_id", None) is not None:
            data["grab_request_id"] = transaction.grab_request_id
        if getattr(transaction, "item_id", None) is not None:
            data["item_id"] = transaction.item_id
        if getattr(transaction, "note", None) is not None:
            data["note"] = transaction.note
        return data
