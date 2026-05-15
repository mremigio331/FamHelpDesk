from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute
from helpers.entity_ref import EntityRef


class GrabRequestItemModel(FamHelpDeskBaseModel):
    item_id = UnicodeAttribute()
    request_id = UnicodeAttribute()
    family_id = UnicodeAttribute()
    name = UnicodeAttribute()
    quantity = NumberAttribute(default=1)
    embolec_cost = NumberAttribute(default=0)
    note = UnicodeAttribute(null=True)
    status = UnicodeAttribute(default="OPEN")
    claimer_id = UnicodeAttribute(null=True)
    claimed_at = NumberAttribute(null=True)
    completed_at = NumberAttribute(null=True)
    confirmed_at = NumberAttribute(null=True)
    cancelled_at = NumberAttribute(null=True)
    cancelled_by = UnicodeAttribute(null=True)
    proof_photo_key = UnicodeAttribute(null=True)
    photo_visibility = UnicodeAttribute(null=True)

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(request_id: str, item_id: str) -> str:
        return f"GRAB_REQUEST#{request_id}#ITEM#{item_id}"

    @staticmethod
    def clean_returned_item(item: "GrabRequestItemModel") -> dict:
        data = {
            "item_id": item.item_id,
            "request_id": item.request_id,
            "family_id": item.family_id,
            "name": item.name,
            "quantity": int(item.quantity),
            "embolec_cost": float(item.embolec_cost),
            "status": item.status,
        }
        if getattr(item, "note", None) is not None:
            data["note"] = item.note
        if getattr(item, "claimer_id", None) is not None:
            data["claimer_id"] = EntityRef(id=item.claimer_id)
        if getattr(item, "claimed_at", None) is not None:
            data["claimed_at"] = int(item.claimed_at)
        if getattr(item, "completed_at", None) is not None:
            data["completed_at"] = int(item.completed_at)
        if getattr(item, "confirmed_at", None) is not None:
            data["confirmed_at"] = int(item.confirmed_at)
        if getattr(item, "cancelled_at", None) is not None:
            data["cancelled_at"] = int(item.cancelled_at)
        if getattr(item, "cancelled_by", None) is not None:
            data["cancelled_by"] = EntityRef(id=item.cancelled_by)
        if getattr(item, "proof_photo_key", None) is not None:
            data["proof_photo_key"] = item.proof_photo_key
        if getattr(item, "photo_visibility", None) is not None:
            data["photo_visibility"] = item.photo_visibility
        return data
