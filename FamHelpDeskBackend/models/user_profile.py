from pynamodb.attributes import UnicodeAttribute
from enum import Enum


class ProviderOptions(str, Enum):
    GOOGLE = "Google"
    COGNITO = "Cognito"


from models.base import FamHelpDeskBaseModel


class UserProfile(FamHelpDeskBaseModel):
    user_id = UnicodeAttribute()
    display_name = UnicodeAttribute()
    nick_name = UnicodeAttribute()
    provider = UnicodeAttribute()

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
            "nick_name": profile.nick_name,
        }
