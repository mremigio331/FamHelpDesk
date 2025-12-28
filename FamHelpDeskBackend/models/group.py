from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute


class GroupModel(FamHelpDeskBaseModel):
    family_id = UnicodeAttribute()
    group_id = UnicodeAttribute()
    group_name = UnicodeAttribute()
    group_description = UnicodeAttribute(null=True)
    created_by = UnicodeAttribute()
    creation_date = NumberAttribute()

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(group_id: str) -> str:
        return f"GROUP#{group_id}#META"

    @staticmethod
    def clean_returned_group(group: "GroupModel") -> dict:
        data = {
            "family_id": group.family_id,
            "group_id": group.group_id,
            "group_name": group.group_name,
            "created_by": group.created_by,
            "creation_date": group.creation_date,
        }
        if getattr(group, "group_description", None) is not None:
            data["group_description"] = group.group_description
        return data
