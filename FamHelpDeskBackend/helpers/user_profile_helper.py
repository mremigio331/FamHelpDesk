from models.user_profile import UserProfile
from helpers.audit_helper import AuditHelper
from helpers.notification_helper import NotificationHelper
from models.notification import NotificationType
from models.audit import AuditActions, AuditEntityTypes

from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger
from typing import Optional


class UserProfileHelper:
    def __init__(self, request_id: str = None):
        self.logger = Logger()
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

        profile = UserProfile(
            pk=UserProfile.create_pk(user_id),
            sk=UserProfile.create_sk(),
            user_id=user_id,
            display_name=display_name,
            provider=provider,
            email=email,
            profile_color=UserProfile.profile_color.default,
            dark_mode=False,
        )

        profile.save()
        self.logger.info(f"Created user profile for {user_id}")

        # Always create audit record
        profile_data = UserProfile.clean_returned_profile(profile)
        self.audit_helper.create_user_audit_record(
            user_id=user_id,
            action=AuditActions.CREATE,
            after=profile_data,
        )

        # Send welcome notification
        self.notification_helper.create_notification(
            user_id=user_id,
            message="Welcome to Fam Help Desk! We're excited to have you here.",
            notification_type=NotificationType.WELCOME,
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
