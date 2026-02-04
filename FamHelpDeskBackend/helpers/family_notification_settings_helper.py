from typing import Optional, List
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger
import time

from models.family_notification_settings import (
    FamilyNotificationSettings,
    FamliyNotificationType,
)


class FamilyNotificationSettingsHelper:
    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
        notification_topic_arn: str = None,
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
            stage, table_name, notification_topic_arn
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
            welcome_to_family_enabled=True,
            membership_request_enabled=True,
            ticket_creation_enabled=True,
            ticket_assigned_enabled=True,
            ticket_comment_enabled=True,
            ticket_status_changed_enabled=True,
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
        self,
        user_id: str,
        family_id: str,
        welcome_to_family_enabled: Optional[bool] = None,
        membership_request_enabled: Optional[bool] = None,
        ticket_creation_enabled: Optional[bool] = None,
        ticket_assigned_enabled: Optional[bool] = None,
        ticket_comment_enabled: Optional[bool] = None,
        ticket_status_changed_enabled: Optional[bool] = None,
    ) -> FamilyNotificationSettings:
        """
        Update specific notification preferences.

        Args:
            user_id: The user ID to update settings for
            family_id: The family ID to update settings for
            welcome_to_family_enabled: Optional welcome to family notification preference
            membership_request_enabled: Optional membership request notification preference
            ticket_creation_enabled: Optional ticket creation notification preference
            ticket_assigned_enabled: Optional ticket assignment notification preference
            ticket_comment_enabled: Optional ticket comment notification preference
            ticket_status_changed_enabled: Optional ticket status change notification preference

        Returns:
            FamilyNotificationSettings: The updated settings object
        """
        # Retrieve existing settings or create defaults if none exist
        settings = self.get_settings(user_id, family_id)
        if settings is None:
            settings = self.create_default_settings(user_id, family_id)

        # Update provided boolean flags
        if welcome_to_family_enabled is not None:
            settings.welcome_to_family_enabled = welcome_to_family_enabled
        if membership_request_enabled is not None:
            settings.membership_request_enabled = membership_request_enabled
        if ticket_creation_enabled is not None:
            settings.ticket_creation_enabled = ticket_creation_enabled
        if ticket_assigned_enabled is not None:
            settings.ticket_assigned_enabled = ticket_assigned_enabled
        if ticket_comment_enabled is not None:
            settings.ticket_comment_enabled = ticket_comment_enabled
        if ticket_status_changed_enabled is not None:
            settings.ticket_status_changed_enabled = ticket_status_changed_enabled

        # Update last_updated timestamp
        settings.last_updated = int(time.time())

        # Save updated settings to DynamoDB
        settings.save()

        self.logger.info(
            f"Updated family notification settings for user {user_id} in family {family_id}"
        )

        return settings

    def is_notification_enabled(
        self, user_id: str, family_id: str, notification_type: NotificationType
    ) -> bool:
        """
        Check if notification type is enabled for user-family pair.
        If settings don't exist, creates default settings (all enabled) for backward compatibility.
        This ensures existing users automatically get settings when they receive their first notification.

        Args:
            user_id: The user ID to check settings for
            family_id: The family ID to check settings for
            notification_type: The NotificationType enum value to check

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
            # Faimly
            FamliyNotificationType.FAMILY_MEMBERSHIP_APPROVED: settings.family_membership_approved,
            FamliyNotificationType.FAMILY_MEMBERSHIP_DENIED: settings.family_membership_denied,
            FamliyNotificationType.FAMILY_MEMBERSHIP_INVITATION: settings.family_membership_invitation,
            FamliyNotificationType.FAMILY_MEMBER_JOINED: settings.family_membership_joined,
            FamliyNotificationType.FAMILY_MEMBERSHIP_LEFT: settings.family_membership_left,
            FamliyNotificationType.FAMILY_MEMBERSHIP_REQUEST: settings.family_membership_request,
            # Group Membership
            FamliyNotificationType.GROUP_MEMBERSHIP_APPROVED: settings.group_membership_approved,
            FamliyNotificationType.GROUP_MEMBERSHIP_DENIED: settings.group_membership_denied,
            FamliyNotificationType.GROUP_MEMBERSHIP_INVITATION: settings.group_membership_invitation,
            FamliyNotificationType.GROUP_MEMBER_JOINED: settings.group_membership_joined,
            FamliyNotificationType.GROUP_MEMBERSHIP_LEFT: settings.group_membership_left,
            FamliyNotificationType.GROUP_MEMBERSHIP_REQUEST: settings.group_membership_request,
            # Tickets
            FamliyNotificationType.TICKET_CREATION_FAMILY: settings.ticket_creation_family,
            FamliyNotificationType.TICKET_CREATION_GROUP: settings.ticket_creation_group,
            FamliyNotificationType.TICKET_ASSIGNED: settings.ticket_assigned,
            FamliyNotificationType.TICKET_COMMENT: settings.ticket_comment,
            FamliyNotificationType.TICKET_STATUS_CHANGED: settings.ticket_satatus_change,
        }

        is_enabled = notification_mapping.get(notification_type, True)

        self.logger.info(
            f"Notification {notification_type.value} for user {user_id} in family {family_id} is {'enabled' if is_enabled else 'disabled'}"
        )

        return is_enabled
