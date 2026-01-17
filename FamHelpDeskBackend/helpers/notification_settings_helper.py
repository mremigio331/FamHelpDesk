from typing import Optional
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger
import time

from models.notification_settings import NotificationSettingsModel
from models.notification import NotificationType


class NotificationSettingsHelper:
    def __init__(self, request_id: str = None):
        """
        Initialize NotificationSettingsHelper with logger and request_id support.

        Args:
            request_id: Optional request ID for logging correlation
        """
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.request_id = request_id

    def create_default_settings(self, user_id: str) -> NotificationSettingsModel:
        """
        Generate default notification settings for new user.

        Args:
            user_id: The user ID to create settings for

        Returns:
            NotificationSettingsModel: The created settings object
        """
        current_time = int(time.time())

        settings = NotificationSettingsModel(
            pk=NotificationSettingsModel.create_pk(user_id),
            sk=NotificationSettingsModel.create_sk(),
            user_id=user_id,
            # Boolean flags use default values from model definition
            welcome_enabled=True,
            membership_enabled=True,
            ticket_creation_enabled=True,
            ticket_assigned_enabled=True,
            ticket_comment_enabled=False,
            ticket_status_changed_enabled=False,
            group_invitation_enabled=False,
            created_date=current_time,
            last_updated=current_time,
        )

        settings.save()

        self.logger.info(f"Created default notification settings for user {user_id}")

        return settings

    def get_settings(self, user_id: str) -> Optional[NotificationSettingsModel]:
        """
        Query notification settings by user_id.

        Args:
            user_id: The user ID to retrieve settings for

        Returns:
            NotificationSettingsModel: The settings object or None if not found
        """
        try:
            settings = NotificationSettingsModel.get(
                hash_key=NotificationSettingsModel.create_pk(user_id),
                range_key=NotificationSettingsModel.create_sk(),
            )
            self.logger.info(f"Retrieved notification settings for user {user_id}")
            return settings
        except DoesNotExist:
            self.logger.info(f"Notification settings not found for user {user_id}")
            return None

    def update_settings(
        self,
        user_id: str,
        welcome_enabled: Optional[bool] = None,
        membership_enabled: Optional[bool] = None,
        ticket_creation_enabled: Optional[bool] = None,
        ticket_assigned_enabled: Optional[bool] = None,
        ticket_comment_enabled: Optional[bool] = None,
        ticket_status_changed_enabled: Optional[bool] = None,
        group_invitation_enabled: Optional[bool] = None,
    ) -> NotificationSettingsModel:
        """
        Update provided boolean flags in notification settings.
        Handle case where settings don't exist (create defaults first).

        Args:
            user_id: The user ID to update settings for
            welcome_enabled: Optional welcome notification preference
            membership_enabled: Optional membership notification preference
            ticket_creation_enabled: Optional ticket creation notification preference
            ticket_assigned_enabled: Optional ticket assignment notification preference
            ticket_comment_enabled: Optional ticket comment notification preference
            ticket_status_changed_enabled: Optional ticket status change notification preference
            group_invitation_enabled: Optional group invitation notification preference

        Returns:
            NotificationSettingsModel: The updated settings object
        """
        # Retrieve existing settings or create defaults if none exist
        settings = self.get_settings(user_id)
        if settings is None:
            settings = self.create_default_settings(user_id)

        # Update provided boolean flags
        if welcome_enabled is not None:
            settings.welcome_enabled = welcome_enabled
        if membership_enabled is not None:
            settings.membership_enabled = membership_enabled
        if ticket_creation_enabled is not None:
            settings.ticket_creation_enabled = ticket_creation_enabled
        if ticket_assigned_enabled is not None:
            settings.ticket_assigned_enabled = ticket_assigned_enabled
        if ticket_comment_enabled is not None:
            settings.ticket_comment_enabled = ticket_comment_enabled
        if ticket_status_changed_enabled is not None:
            settings.ticket_status_changed_enabled = ticket_status_changed_enabled
        if group_invitation_enabled is not None:
            settings.group_invitation_enabled = group_invitation_enabled

        # Update last_updated timestamp
        settings.last_updated = int(time.time())

        # Save updated settings to DynamoDB
        settings.save()

        self.logger.info(f"Updated notification settings for user {user_id}")

        return settings

    def is_notification_enabled(
        self, user_id: str, notification_type: NotificationType
    ) -> bool:
        """
        Accept user_id and notification_type parameters.
        Retrieve user's notification settings.
        Return boolean indicating if notification type is enabled.
        Return True if settings don't exist (fail-safe for new users).
        Map NotificationType enum values to corresponding boolean fields.

        Args:
            user_id: The user ID to check settings for
            notification_type: The NotificationType enum value to check

        Returns:
            bool: True if notification should be sent, False otherwise
        """
        settings = self.get_settings(user_id)

        # Return True if settings don't exist (fail-safe for new users)
        if settings is None:
            self.logger.info(
                f"No notification settings found for user {user_id}, defaulting to enabled for {notification_type.value}"
            )
            return True

        # Map NotificationType enum values to corresponding boolean fields
        notification_mapping = {
            NotificationType.WELCOME: settings.welcome_enabled,
            NotificationType.WELCOME_TO_FAMILY: settings.welcome_enabled,
            NotificationType.MEMBERSHIP_REQUEST: settings.membership_enabled,
            NotificationType.MEMBERSHIP_APPROVED: settings.membership_enabled,
            NotificationType.MEMBERSHIP_DENIED: settings.membership_enabled,
            NotificationType.TICKET_CREATION: settings.ticket_creation_enabled,
            NotificationType.TICKET_ASSIGNED: settings.ticket_assigned_enabled,
            NotificationType.TICKET_COMMENT: settings.ticket_comment_enabled,
            NotificationType.TICKET_STATUS_CHANGED: settings.ticket_status_changed_enabled,
            NotificationType.GROUP_INVITATION: settings.group_invitation_enabled,
        }

        is_enabled = notification_mapping.get(notification_type, True)

        self.logger.info(
            f"Notification {notification_type.value} for user {user_id} is {'enabled' if is_enabled else 'disabled'}"
        )

        return is_enabled
