from typing import Optional, List
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger
import time

from models.family_notification_settings import (
    FamilyNotificationSettings,
    FamilyNotificationType,
)


class FamilyNotificationSettingsHelper:
    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
        notification_queue_url: str = None,
    ):
        """
        Initialize FamilyNotificationSettingsHelper with logger and request_id support.

        Args:
            request_id: Optional request ID for logging correlation
            stage: Optional stage to override model configuration
            table_name: Optional table name to override model configuration
        """
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.request_id = request_id
        FamilyNotificationSettings.set_stage_and_table(
            stage, table_name, notification_queue_url
        )

    def create_default_settings(
        self, user_id: str, family_id: str
    ) -> FamilyNotificationSettings:
        """
        Create default notification settings for a user-family pair.
        Idempotent - returns existing settings if they already exist.
        All notification types enabled by default.

        Args:
            user_id: The user ID to create settings for
            family_id: The family ID to create settings for

        Returns:
            FamilyNotificationSettings: The created or existing settings object
        """
        # Check if settings already exist
        existing_settings = self.get_settings(user_id, family_id)
        if existing_settings:
            self.logger.info(
                f"Family notification settings already exist for user {user_id} in family {family_id}, returning existing"
            )
            return existing_settings

        current_time = int(time.time())

        settings = FamilyNotificationSettings(
            pk=FamilyNotificationSettings.create_pk(user_id),
            sk=FamilyNotificationSettings.create_sk(family_id),
            user_id=user_id,
            family_id=family_id,
            # All notification types enabled by default
            # Family
            new_family_creation_enabled=True,
            welcome_enabled=True,
            # Family Membership
            welcome_to_family_enabled=True,
            new_family_member_enabled=True,
            family_membership_approved=True,
            family_membership_denied=False,
            family_membership_invitation=False,
            family_membership_joined=True,
            family_membership_left=True,
            family_membership_request=True,
            # Group Membership
            group_membership_approved=False,
            group_membership_denied=False,
            group_membership_added=False,
            group_membership_joined=False,
            group_membership_left=False,
            group_membership_request=False,
            new_group_creation=False,
            # Tickets
            ticket_creation_family=False,
            ticket_creation_group=True,
            ticket_assigned=True,
            ticket_comment=True,
            ticket_status_change=True,
            ticket_resolved=True,
            created_date=current_time,
            last_updated=current_time,
        )

        try:
            settings.save()
            self.logger.info(
                f"Created default family notification settings for user {user_id} in family {family_id}"
            )
        except Exception as e:
            # Handle race condition where settings were created between check and save
            if (
                "ConditionalCheckFailedException" in str(e)
                or "already exists" in str(e).lower()
            ):
                self.logger.info(
                    f"Settings creation race condition for user {user_id} in family {family_id}, fetching existing"
                )
                return self.get_settings(user_id, family_id)
            raise

        return settings

    def get_settings(
        self, user_id: str, family_id: str
    ) -> Optional[FamilyNotificationSettings]:
        """
        Get settings for user-family pair.

        Args:
            user_id: The user ID to retrieve settings for
            family_id: The family ID to retrieve settings for

        Returns:
            FamilyNotificationSettings: The settings object or None if not found
        """
        try:
            settings = FamilyNotificationSettings.get(
                hash_key=FamilyNotificationSettings.create_pk(user_id),
                range_key=FamilyNotificationSettings.create_sk(family_id),
            )
            self.logger.info(
                f"Retrieved family notification settings for user {user_id} in family {family_id}"
            )
            return settings
        except DoesNotExist:
            self.logger.info(
                f"Family notification settings not found for user {user_id} in family {family_id}"
            )
            return None

    def get_all_settings_for_family(
        self, family_id: str
    ) -> List[FamilyNotificationSettings]:
        """
        Query all settings for users in a family using GSI.

        Args:
            family_id: The family ID to query settings for

        Returns:
            List[FamilyNotificationSettings]: List of all settings for users in the family
        """
        try:
            settings_list = list(
                FamilyNotificationSettings.family_settings_index.query(
                    hash_key=family_id
                )
            )
            self.logger.info(
                f"Retrieved {len(settings_list)} family notification settings for family {family_id}"
            )
            return settings_list
        except Exception as e:
            self.logger.error(
                f"Error querying family notification settings for family {family_id}: {str(e)}"
            )
            raise

    def update_settings(
        self, user_id: str, family_id: str, **kwargs
    ) -> FamilyNotificationSettings:
        """
        Update specific notification preferences.

        Args:
            user_id: The user ID to update settings for
            family_id: The family ID to update settings for
            **kwargs: Any notification preference fields to update (e.g., ticket_assigned=True)

        Returns:
            FamilyNotificationSettings: The updated settings object
        """
        # Retrieve existing settings or create defaults if none exist
        settings = self.get_settings(user_id, family_id)
        if settings is None:
            settings = self.create_default_settings(user_id, family_id)

        # Valid notification preference field names
        valid_fields = {
            # Family
            "new_family_creation_enabled",
            "welcome_enabled",
            # Family Membership
            "welcome_to_family_enabled",
            "new_family_member_enabled",
            "family_membership_approved",
            "family_membership_denied",
            "family_membership_invitation",
            "family_membership_joined",
            "family_membership_left",
            "family_membership_request",
            # Group Membership
            "group_membership_approved",
            "group_membership_denied",
            "group_membership_added",
            "group_membership_joined",
            "group_membership_left",
            "group_membership_request",
            "new_group_creation",
            # Tickets
            "ticket_creation_family",
            "ticket_creation_group",
            "ticket_assigned",
            "ticket_comment",
            "ticket_status_change",
            "ticket_resolved",
        }

        # Update provided fields
        for field_name, value in kwargs.items():
            if field_name in valid_fields and value is not None:
                setattr(settings, field_name, value)
            elif field_name not in valid_fields:
                self.logger.warning(
                    f"Ignoring unknown field '{field_name}' in update_settings"
                )

        # Update last_updated timestamp
        settings.last_updated = int(time.time())

        # Save updated settings to DynamoDB
        settings.save()

        self.logger.info(
            f"Updated family notification settings for user {user_id} in family {family_id}"
        )

        return settings

    def is_notification_enabled(
        self, user_id: str, family_id: str, notification_type: FamilyNotificationType
    ) -> bool:
        """
        Check if notification type is enabled for user-family pair.
        If settings don't exist, creates default settings (all enabled) for backward compatibility.
        This ensures existing users automatically get settings when they receive their first notification.

        Args:
            user_id: The user ID to check settings for
            family_id: The family ID to check settings for
            notification_type: The FamilyNotificationType enum value to check

        Returns:
            bool: True if notification should be sent, False otherwise
        """
        settings = self.get_settings(user_id, family_id)

        # If settings don't exist, create default settings (backward compatibility)
        if settings is None:
            self.logger.info(
                f"No FamilyNotificationSettings found for user {user_id} in family {family_id}, "
                f"creating default settings for backward compatibility"
            )
            settings = self.create_default_settings(user_id, family_id)

        # Map NotificationType enum values to corresponding boolean fields
        notification_mapping = {
            # Family
            FamilyNotificationType.NEW_FAMILY_CREATION: settings.new_family_creation_enabled,
            FamilyNotificationType.WELCOME: settings.welcome_enabled,
            # Family Membership
            FamilyNotificationType.WELCOME_TO_FAMILY: settings.welcome_to_family_enabled,
            FamilyNotificationType.NEW_FAMILY_MEMEBER: settings.new_family_member_enabled,
            FamilyNotificationType.FAMILY_MEMBERSHIP_APPROVED: settings.family_membership_approved,
            FamilyNotificationType.FAMILY_MEMBERSHIP_DENIED: settings.family_membership_denied,
            FamilyNotificationType.FAMILY_MEMBERSHIP_INVITATION: settings.family_membership_invitation,
            FamilyNotificationType.FAMILY_MEMBER_JOINED: settings.family_membership_joined,
            FamilyNotificationType.FAMILY_MEMBERSHIP_LEFT: settings.family_membership_left,
            FamilyNotificationType.FAMILY_MEMBERSHIP_REQUEST: settings.family_membership_request,
            # Group Membership
            FamilyNotificationType.GROUP_MEMBERSHIP_APPROVED: settings.group_membership_approved,
            FamilyNotificationType.GROUP_MEMBERSHIP_DENIED: settings.group_membership_denied,
            FamilyNotificationType.GROUP_MEMBERSHIP_ADDED: settings.group_membership_added,
            FamilyNotificationType.GROUP_MEMBER_JOINED: settings.group_membership_joined,
            FamilyNotificationType.GROUP_MEMBERSHIP_LEFT: settings.group_membership_left,
            FamilyNotificationType.GROUP_MEMBERSHIP_REQUEST: settings.group_membership_request,
            FamilyNotificationType.NEW_GROUP_CREATION: settings.new_group_creation,
            # Tickets
            FamilyNotificationType.TICKET_CREATION_FAMILY: settings.ticket_creation_family,
            FamilyNotificationType.TICKET_CREATION_GROUP: settings.ticket_creation_group,
            FamilyNotificationType.TICKET_ASSIGNED: settings.ticket_assigned,
            FamilyNotificationType.TICKET_COMMENT: settings.ticket_comment,
            FamilyNotificationType.TICKET_STATUS_CHANGED: settings.ticket_status_change,
            FamilyNotificationType.TICKET_RESOLVED: settings.ticket_resolved,
            # FamGrab
            FamilyNotificationType.GRAB_REQUEST_CREATED: settings.grab_request_created,
            FamilyNotificationType.GRAB_REQUEST_CLAIMED: settings.grab_request_updates,
            FamilyNotificationType.GRAB_REQUEST_COMPLETED: settings.grab_request_updates,
            FamilyNotificationType.GRAB_REQUEST_CONFIRMED: settings.grab_request_updates,
            FamilyNotificationType.GRAB_REQUEST_CANCELLED: settings.grab_request_updates,
            FamilyNotificationType.GRAB_ITEMS_CLAIMED: settings.grab_request_updates,
            FamilyNotificationType.GRAB_ITEMS_COMPLETED: settings.grab_request_updates,
            FamilyNotificationType.GRAB_ITEMS_CONFIRMED: settings.grab_request_updates,
            FamilyNotificationType.GRAB_ITEMS_CANCELLED: settings.grab_request_updates,
            FamilyNotificationType.GRAB_REVIEW_RECEIVED: settings.grab_request_updates,
            FamilyNotificationType.GRAB_PICKUP_PHOTO: settings.grab_request_updates,
        }

        is_enabled = notification_mapping.get(notification_type, True)

        self.logger.info(
            f"Notification {notification_type.value} for user {user_id} in family {family_id} is {'enabled' if is_enabled else 'disabled'}"
        )

        return is_enabled
