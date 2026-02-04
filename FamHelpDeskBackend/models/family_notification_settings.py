from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, BooleanAttribute, NumberAttribute
from pynamodb.indexes import GlobalSecondaryIndex, AllProjection
from enum import Enum


class FamliyNotificationType(Enum):
    # Family
    NEW_FAMILY_CREATION = "New Family Created"

    # Family Membership
    FAMILY_MEMBERSHIP_APPROVED = "Family Membership Approved"
    FAMILY_MEMBERSHIP_DENIED = "Family Membership Denied"
    FAMILY_MEMBERSHIP_INVITATION = "Family Membership Invitation"
    FAMILY_MEMBER_JOINED = "Family Membership Accepted"
    FAMILY_MEMBERSHIP_LEFT = "Family Member left"
    FAMILY_MEMBERSHIP_REQUEST = "Family Membership Request"
    NEW_FAMILY_MEMEBER = "New Family Member"
    WELCOME_TO_FAMILY = "Welcome to Family"

    # Group Membership
    GROUP_MEMBERSHIP_APPROVED = "Group Membership Approved"
    GROUP_MEMBERSHIP_DENIED = "Group Membership Denied"
    GROUP_MEMBERSHIP_INVITATION = "Group Membership Invitation"
    GROUP_MEMBER_JOINED = "Group Membership Accepted"
    GROUP_MEMBERSHIP_LEFT = "Group Member left"
    GROUP_MEMBERSHIP_REQUEST = "Group Membership Request"

    # Ticket
    TICKET_CREATION_FAMILY = "Family Ticket Creation"
    TICKET_CREATION_GROUP = "Group Ticket Creation"
    TICKET_ASSIGNED = "Ticket Assigned"
    TICKET_COMMENT = "Ticket Comment"
    TICKET_STATUS_CHANGED = "Ticket Status Changed"


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

    # Family Membership
    family_membership_approved = BooleanAttribute(default=True)
    family_membership_denied = BooleanAttribute(default=False)
    family_membership_invitation = BooleanAttribute(default=False)
    family_membership_joined = BooleanAttribute(default=True)
    family_membership_left = BooleanAttribute(defaults=True)
    family_membership_request = BooleanAttribute(defaults=True)

    # Group Membership
    group_membership_approved = BooleanAttribute(defaults=False)
    group_membership_denied = BooleanAttribute(default=False)
    group_membership_invitation = BooleanAttribute(default=False)
    group_membership_joined = BooleanAttribute(default=False)
    group_membership_left = BooleanAttribute(default=False)
    group_membership_request = BooleanAttribute(default=False)

    # Tickets
    ticket_creation_family = BooleanAttribute(default=False)
    ticket_creation_group = BooleanAttribute(default=True)
    ticket_assigned = BooleanAttribute(default=True)
    ticket_comment = BooleanAttribute(default=True)
    ticket_satatus_change = BooleanAttribute(default=True)

    # Standard timestamp fields
    created_date = NumberAttribute()
    last_updated = NumberAttribute(null=True)

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
            "created_date": settings.created_date,
            "last_updated": settings.last_updated,
            # Faimly
            "family_membership_approved": settings.family_membership_approved,
            "family_membership_denied": settings.family_membership_denied,
            "family_membership_invitation": settings.family_membership_invitation,
            "family_membership_joined": settings.family_membership_joined,
            "family_membership_left": settings.family_membership_left,
            "family_membership_request": settings.family_membership_request,
            # Group Membership
            "group_membership_approved": settings.group_membership_approved,
            "group_membership_denied": settings.group_membership_denied,
            "group_membership_invitation": settings.group_membership_invitation,
            "group_membership_joined": settings.group_membership_joined,
            "group_membership_left": settings.group_membership_left,
            "group_membership_request": settings.group_membership_request,
            # Tickets
            "ticket_creation_family": settings.ticket_creation_family,
            "ticket_creation_group": settings.ticket_creation_group,
            "ticket_assigned": settings.ticket_assigned,
            "ticket_comment": settings.ticket_comment,
            "ticket_satatus_change": settings.ticket_satatus_change,
        }

    def save(self, **kwargs):
        """Override save to populate GSI attributes"""
        # GSI attributes are already set as model attributes
        # PynamoDB automatically handles GSI projection
        super().save(**kwargs)
