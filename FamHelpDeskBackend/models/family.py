from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute


class FamilyModel(FamHelpDeskBaseModel):
    family_id = UnicodeAttribute()
    family_name = UnicodeAttribute()
    family_description = UnicodeAttribute(null=True)
    creation_date = NumberAttribute()
    created_by = UnicodeAttribute()

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk() -> str:
        return "META"

    @staticmethod
    def clean_returned_family(family: "FamilyModel") -> dict:
        data = {
            "family_id": family.family_id,
            "family_name": family.family_name,
            "creation_date": family.creation_date,
            "created_by": family.created_by,
        }
        if family.family_description is not None:
            data["family_description"] = family.family_description
        return data
