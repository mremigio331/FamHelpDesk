from pynamodb.attributes import UnicodeAttribute, BooleanAttribute, MapAttribute
from enum import Enum
from models.base import FamHelpDeskBaseModel
from models.entity_lookup import EntityLookupIndex


class ProviderOptions(str, Enum):
    GOOGLE = "Google"
    COGNITO = "Cognito"


class ProfileColorOptions(str, Enum):
    BLACK = "Black"
    WHITE = "White"
    RED = "Red"
    BLUE = "Blue"
    GREEN = "Green"
    YELLOW = "Yellow"
    ORANGE = "Orange"
    PURPLE = "Purple"
    PINK = "Pink"
    BROWN = "Brown"
    GRAY = "Gray"
    CYAN = "Cyan"


class UserProfile(FamHelpDeskBaseModel):
    user_id = UnicodeAttribute()
    display_name = UnicodeAttribute()
    provider = UnicodeAttribute()
    email = UnicodeAttribute()
    profile_color = UnicodeAttribute(default=ProfileColorOptions.BLACK.value)
    dark_mode = BooleanAttribute(default=False)

    # GSI attributes (need to be populated when creating/updating)
    entity_uuid = UnicodeAttribute(null=True)
    entity_name = UnicodeAttribute(null=True)

    # GSI index
    entity_lookup_index = EntityLookupIndex()

    @staticmethod
    def create_pk(user_id: str) -> str:
        return f"USER_PROFILE#{user_id}"

    @staticmethod
    def create_sk() -> str:
        return "META"

    @staticmethod
    def clean_returned_profile(profile: "UserProfile") -> dict:
        return {
            "user_id": profile.user_id,
            "display_name": profile.display_name,
            "email": profile.email,
            "profile_color": profile.profile_color,
            "dark_mode": profile.dark_mode,
        }

    @property
    def entity_display_name(self) -> str:
        """Return the display name for this entity, ensuring it's never empty"""
        return (
            self.display_name.strip()
            if self.display_name and self.display_name.strip()
            else "Unknown User"
        )

    def save(self, **kwargs):
        """Override save to automatically populate GSI attributes"""
        self.entity_uuid = self.user_id
        self.entity_name = self.entity_display_name
        super().save(**kwargs)
