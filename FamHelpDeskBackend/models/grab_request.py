from enum import Enum
from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute
from helpers.entity_ref import EntityRef


class GrabRequestStatus(str, Enum):
    OPEN = "OPEN"
    CLAIMED = "CLAIMED"
    COMPLETED = "COMPLETED"
    CONFIRMED = "CONFIRMED"
    CANCELLED = "CANCELLED"


class GrabRequestModel(FamHelpDeskBaseModel):
    request_id = UnicodeAttribute()
    family_id = UnicodeAttribute()
    requestor_id = UnicodeAttribute()
    status = UnicodeAttribute()  # GrabRequestStatus enum value
    embolec_cost = NumberAttribute()
    title = UnicodeAttribute()
    note = UnicodeAttribute(null=True)
    tip_amount = NumberAttribute(null=True)
    proof_photo_key = UnicodeAttribute(null=True)
    created_at = NumberAttribute()
    cancelled_at = NumberAttribute(null=True)
    cancelled_by = UnicodeAttribute(null=True)

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(request_id: str) -> str:
        return f"GRAB_REQUEST#{request_id}"

    @staticmethod
    def clean_returned_request(request: "GrabRequestModel") -> dict:
        data = {
            "request_id": request.request_id,
            "family_id": request.family_id,
            "requestor_id": EntityRef(id=request.requestor_id),
            "status": request.status,
            "embolec_cost": float(request.embolec_cost),
            "title": request.title,
            "created_at": int(request.created_at),
        }
        if getattr(request, "note", None) is not None:
            data["note"] = request.note
        if getattr(request, "tip_amount", None) is not None:
            data["tip_amount"] = float(request.tip_amount)
        if getattr(request, "proof_photo_key", None) is not None:
            data["proof_photo_key"] = request.proof_photo_key
        if getattr(request, "cancelled_at", None) is not None:
            data["cancelled_at"] = int(request.cancelled_at)
        if getattr(request, "cancelled_by", None) is not None:
            data["cancelled_by"] = EntityRef(id=request.cancelled_by)
        return data
