from models.base import FamHelpDeskBaseModel
from models.entity_lookup import EntityLookupIndex
from pynamodb.attributes import UnicodeAttribute, NumberAttribute, BooleanAttribute


class FamilyModel(FamHelpDeskBaseModel):
    family_id = UnicodeAttribute()
    family_name = UnicodeAttribute()
    family_description = UnicodeAttribute(null=True)
    creation_date = NumberAttribute()
    created_by = UnicodeAttribute()
    private = BooleanAttribute(default=False)

    # GSI attributes (need to be populated when creating/updating)
    entity_uuid = UnicodeAttribute(null=True)
    entity_name = UnicodeAttribute(null=True)

    # GSI index
    entity_lookup_index = EntityLookupIndex()

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
            "private": family.private,
        }
        if family.family_description is not None:
            data["family_description"] = family.family_description
        return data

    @property
    def entity_display_name(self) -> str:
        """Return the display name for this entity"""
        return self.family_name

    def save(self, **kwargs):
        """Override save to automatically populate GSI attributes"""
        self.entity_uuid = self.family_id
        self.entity_name = self.entity_display_name
        super().save(**kwargs)
