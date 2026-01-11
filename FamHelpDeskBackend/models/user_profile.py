from pynamodb.attributes import UnicodeAttribute, BooleanAttribute, MapAttribute
from enum import Enum
from models.base import FamHelpDeskBaseModel


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
