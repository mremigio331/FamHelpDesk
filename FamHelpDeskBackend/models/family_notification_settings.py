from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, BooleanAttribute, NumberAttribute
from pynamodb.indexes import GlobalSecondaryIndex, AllProjection


class FamilySettingsIndex(GlobalSecondaryIndex):
    """GSI for querying all settings for users in a family"""

    class Meta:
        index_name = "FamilySettingsIndex"
        projection = AllProjection()

    family_id = UnicodeAttribute(hash_key=True)
    user_id = UnicodeAttribute(range_key=True)


class FamilyNotificationSettings(FamHelpDeskBaseModel):
    """
    Per-family notification settings for users.

    PK: USER_PROFILE#{user_id}
    SK: NOTIFICATION_SETTINGS#{family_id}
    """

    user_id = UnicodeAttribute()
    family_id = UnicodeAttribute()

    # Notification type preferences with defaults
    welcome_to_family_enabled = BooleanAttribute(default=True)
    membership_request_enabled = BooleanAttribute(default=True)
    ticket_creation_enabled = BooleanAttribute(default=True)
    ticket_assigned_enabled = BooleanAttribute(default=True)
    ticket_comment_enabled = BooleanAttribute(default=True)
    ticket_status_changed_enabled = BooleanAttribute(default=True)

    # Standard timestamp fields
    created_date = NumberAttribute()
    last_updated = NumberAttribute()

    # GSI
    family_settings_index = FamilySettingsIndex()

    @staticmethod
    def create_pk(user_id: str) -> str:
        """Create partition key for family notification settings"""
        return f"USER_PROFILE#{user_id}"

    @staticmethod
    def create_sk(family_id: str) -> str:
        """Create sort key for family notification settings"""
        return f"NOTIFICATION_SETTINGS#{family_id}"

    @staticmethod
    def clean_returned_settings(settings: "FamilyNotificationSettings") -> dict:
        """Clean and return family notification settings data"""
        return {
            "user_id": settings.user_id,
            "family_id": settings.family_id,
            "welcome_to_family_enabled": settings.welcome_to_family_enabled,
            "membership_request_enabled": settings.membership_request_enabled,
            "ticket_creation_enabled": settings.ticket_creation_enabled,
            "ticket_assigned_enabled": settings.ticket_assigned_enabled,
            "ticket_comment_enabled": settings.ticket_comment_enabled,
            "ticket_status_changed_enabled": settings.ticket_status_changed_enabled,
            "created_date": settings.created_date,
            "last_updated": settings.last_updated,
        }

    def save(self, **kwargs):
        """Override save to populate GSI attributes"""
        # GSI attributes are already set as model attributes
        # PynamoDB automatically handles GSI projection
        super().save(**kwargs)
