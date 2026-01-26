from models.user_profile import UserProfile, ProfileColorOptions
from helpers.audit_helper import AuditHelper
from helpers.notification_helper import NotificationHelper
from helpers.notification_settings_helper import NotificationSettingsHelper
from models.notification import NotificationType
from models.audit import AuditActions, AuditEntityTypes
from exceptions.user_exceptions import UserDeleteException

from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger
from typing import Optional
import random
import os
import json
import boto3


class UserProfileHelper:
    def __init__(self, request_id: str = None):
        self.logger = Logger()
        self.request_id = request_id
        if request_id:
            self.logger.append_keys(request_id=request_id)

        self.audit_helper = AuditHelper(request_id=request_id)
        self.notification_helper = NotificationHelper(request_id=request_id)

    def create_profile(
        self,
        user_id: str,
        display_name: str,
        provider: str,
        email: str,
    ) -> UserProfile:
        # Validate display_name is not empty
        if not display_name or not display_name.strip():
            raise ValueError("Display name cannot be empty")

        display_name = display_name.strip()

        # Check if profile already exists (idempotency check)
        existing_profile = self.get_profile(user_id)
        if existing_profile:
            self.logger.info(
                f"User profile already exists for {user_id}, returning existing profile"
            )
            return existing_profile

        colors = [c.value for c in ProfileColorOptions]
        profile_color = random.choice(colors)

        profile = UserProfile(
            pk=UserProfile.create_pk(user_id),
            sk=UserProfile.create_sk(),
            user_id=user_id,
            display_name=display_name,
            provider=provider,
            email=email,
            profile_color=profile_color,
            dark_mode=False,
        )

        try:
            profile.save()
            self.logger.info(f"Created user profile for {user_id}")
        except Exception as e:
            # Handle potential race condition where profile was created between check and save
            if (
                "ConditionalCheckFailedException" in str(e)
                or "already exists" in str(e).lower()
            ):
                self.logger.info(
                    f"Profile creation race condition for {user_id}, fetching existing profile"
                )
                return self.get_profile(user_id)
            raise

        # Create default notification settings (only instantiate when needed)
        notification_settings_helper = NotificationSettingsHelper(
            request_id=self.request_id
        )

        # Check if settings already exist before creating
        existing_settings = notification_settings_helper.get_settings(user_id)
        if not existing_settings:
            notification_settings_helper.create_default_settings(user_id)

        # Always create audit record
        profile_data = UserProfile.clean_returned_profile(profile)
        self.audit_helper.create_user_audit_record(
            user_id=user_id,
            action=AuditActions.CREATE,
            after=profile_data,
        )

        # Send welcome notification (async for better performance)
        try:
            self.notification_helper.create_notification_async(
                user_id=user_id,
                message="Welcome to Fam Help Desk! We're excited to have you here.",
                notification_type=NotificationType.WELCOME,
            )
        except Exception as e:
            # Log but don't fail if notification fails
            self.logger.warning(
                f"Failed to send welcome notification for {user_id}: {e}"
            )

        return profile

    def get_profile(self, user_id: str) -> UserProfile | None:
        try:
            return UserProfile.get(
                UserProfile.create_pk(user_id), UserProfile.create_sk()
            )
        except DoesNotExist:
            self.logger.info(f"No user profile found for {user_id}.")
            return None

    def update_profile(self, user_id: str, **kwargs) -> UserProfile:
        profile = self.get_profile(user_id)
        if not profile:
            raise ValueError("Profile does not exist")

        # Validate display_name if being updated
        if "display_name" in kwargs:
            display_name = kwargs["display_name"]
            if display_name is not None:
                if not display_name or not display_name.strip():
                    raise ValueError("Display name cannot be empty")
                kwargs["display_name"] = display_name.strip()

        # Capture old state for auditing
        old_profile_data = UserProfile.clean_returned_profile(profile)

        # Update the profile
        for key, value in kwargs.items():
            if hasattr(profile, key):
                setattr(profile, key, value)
        profile.save()
        self.logger.info(f"Updated user profile for {user_id}")

        # Always create audit record
        new_profile_data = UserProfile.clean_returned_profile(profile)
        self.audit_helper.create_user_audit_record(
            user_id=user_id,
            action=AuditActions.UPDATE,
            before=old_profile_data,
            after=new_profile_data,
        )

        return profile

    def invoke_user_delete_lambda(self, user_id: str) -> dict:
        """
        Invoke the user profile delete lambda function.

        Args:
            user_id: The ID of the user to delete

        Returns:
            The response from the lambda invocation

        Raises:
            ValueError: If USER_DELETE_LAMBDA environment variable is not set
            UserDeleteException: If lambda invocation fails
        """
        user_delete_lambda_arn = os.environ.get("USER_DELETE_LAMBDA")

        if not user_delete_lambda_arn:
            raise ValueError("USER_DELETE_LAMBDA environment variable not set")

        lambda_client = boto3.client("lambda")

        payload = {"user_id": user_id, "request_id": self.request_id}

        try:
            response = lambda_client.invoke(
                FunctionName=user_delete_lambda_arn,
                InvocationType="Event",
                Payload=json.dumps(payload),
            )

            self.logger.info(
                f"Successfully invoked user delete lambda for {user_id}",
                extra={"status_code": response["StatusCode"]},
            )

        except Exception as e:
            error_msg = str(e)
            self.logger.error(
                f"Failed to invoke user delete lambda for {user_id}: {error_msg}"
            )
            raise UserDeleteException(
                message=f"Failed to initiate user deletion for {user_id}.",
                error_details=error_msg,
            )
