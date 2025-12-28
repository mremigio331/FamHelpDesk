from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute, BooleanAttribute
from enum import Enum


class NotificationType(Enum):
    WELCOME = "Welcome"
    WELCOME_TO_FAMILY = "Welcome to Family"
    MEMBERSHIP_REQUEST = "Membership Request"
    MEMBERSHIP_APPROVED = "Membership Approved"
    MEMBERSHIP_DENIED = "Membership Denied"
    TICKET_ASSIGNED = "Ticket Assigned"
    TICKET_COMMENT = "Ticket Comment"
    TICKET_STATUS_CHANGED = "Ticket Status Changed"
    GROUP_INVITATION = "Group Invitation"


class NotificationModel(FamHelpDeskBaseModel):
    """
    PK: USER_PROFILE#{user_id}
    SK: NOTIFICATION#{notification_id}
    """

    notification_id = UnicodeAttribute()
    user_id = UnicodeAttribute()
    message = UnicodeAttribute()
    notification_type = UnicodeAttribute()  # Store enum value
    timestamp = NumberAttribute()  # Epoch timestamp
    viewed = BooleanAttribute(default=False)
    family_id = UnicodeAttribute(
        null=True
    )  # Optional, if notification is family-related
    ticket_id = UnicodeAttribute(
        null=True
    )  # Optional, if notification is ticket-related

    @staticmethod
    def create_pk(user_id: str) -> str:
        return f"USER_PROFILE#{user_id}"

    @staticmethod
    def create_sk(notification_id: str) -> str:
        return f"NOTIFICATION#{notification_id}"

    @staticmethod
    def clean_returned_notification(notification: "NotificationModel") -> dict:
        data = {
            "notification_id": notification.notification_id,
            "user_id": notification.user_id,
            "message": notification.message,
            "notification_type": notification.notification_type,
            "timestamp": notification.timestamp,
            "viewed": notification.viewed,
        }
        if notification.family_id is not None:
            data["family_id"] = notification.family_id
        if notification.ticket_id is not None:
            data["ticket_id"] = notification.ticket_id
        return data
