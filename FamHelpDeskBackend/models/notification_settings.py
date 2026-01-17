from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, BooleanAttribute, NumberAttribute


class NotificationSettingsModel(FamHelpDeskBaseModel):
    """
    Model for storing user notification preferences.

    PK: USER_PROFILE#{user_id}
    SK: NOTIFICATION_SETTINGS
    """

    user_id = UnicodeAttribute()

    # Notification type preferences with defaults
    welcome_enabled = BooleanAttribute(default=True)
    membership_enabled = BooleanAttribute(default=True)
    ticket_creation_enabled = BooleanAttribute(default=True)
    ticket_assigned_enabled = BooleanAttribute(default=True)
    ticket_comment_enabled = BooleanAttribute(default=False)
    ticket_status_changed_enabled = BooleanAttribute(default=False)
    group_invitation_enabled = BooleanAttribute(default=False)

    # Standard timestamp fields
    created_date = NumberAttribute()
    last_updated = NumberAttribute()

    @staticmethod
    def create_pk(user_id: str) -> str:
        """Create partition key for notification settings"""
        return f"USER_PROFILE#{user_id}"

    @staticmethod
    def create_sk() -> str:
        """Create sort key for notification settings"""
        return "NOTIFICATION_SETTINGS"

    @staticmethod
    def clean_returned_settings(settings: "NotificationSettingsModel") -> dict:
        """Clean and return notification settings data"""
        return {
            "user_id": settings.user_id,
            "welcome_enabled": settings.welcome_enabled,
            "membership_enabled": settings.membership_enabled,
            "ticket_creation_enabled": settings.ticket_creation_enabled,
            "ticket_assigned_enabled": settings.ticket_assigned_enabled,
            "ticket_comment_enabled": settings.ticket_comment_enabled,
            "ticket_status_changed_enabled": settings.ticket_status_changed_enabled,
            "group_invitation_enabled": settings.group_invitation_enabled,
            "created_date": settings.created_date,
            "last_updated": settings.last_updated,
        }
