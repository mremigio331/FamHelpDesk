from helpers.notification_helper import NotificationHelper
from helpers.family_notification_settings_helper import FamilyNotificationSettingsHelper
from helpers.family_membership_helper import FamilyMembershipHelper
from models.family_notification_settings import FamliyNotificationType


class FamilyMembershipNotificationHelper:
    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
        notification_queue_url: str = None,
    ):
        self.notification_helper = NotificationHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )
        self.family_settings_helper = FamilyNotificationSettingsHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )
        self.family_membership_helper = FamilyMembershipHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )

    def process_notification(self, notification_type: FamliyNotificationType, **kwargs):

        try:
            if notification_type == FamliyNotificationType.NEW_FAMILY_CREATION:
                self._process_welcome_to_family(**kwargs)
            elif notification_type == FamliyNotificationType.FAMILY_MEMBERSHIP_REQUEST:
                self._process_new_member_request(**kwargs)
            elif notification_type == FamliyNotificationType.FAMILY_MEMBERSHIP_APPROVED:
                self._process_membership_approved(**kwargs)
            elif notification_type == FamliyNotificationType.FAMILY_MEMBERSHIP_DENIED:
                self._process_member_denied_request(**kwargs)

        except KeyError:
            raise

    def _process_new_family_creation(self, user_id, family_id):
        message = f"You have created the new family {family_id}. Go to the family now to start creating tickets!"
        self.notification_helper.create_notification(
            user_id=user_id,
            message=message,
            notification_type=FamliyNotificationType.NEW_FAMILY_CREATION,
            family_id=family_id,
        )

    def _process_welcome_to_family(self, user_id, family_id):
        message = f"Welcome to family {family_id}!"
        self.notification_helper.create_notification(
            user_id=user_id,
            message=message,
            notification_type=FamliyNotificationType.WELCOME_TO_FAMILY,
            family_id=family_id,
        )

        # Send iOS push notification
        self.notification_helper.send_to_ios_push_queue(
            user_id=user_id,
            title="Welcome!",
            message=message,
            notification_type=FamliyNotificationType.WELCOME_TO_FAMILY.value,
            family_id=family_id,
        )

    def _process_new_member_to_family(self, user_id, family_id):
        all_family_members = self.family_membership_helper.get_all_members(
            family_id=family_id
        )

        self._process_welcome_to_family(user_id, family_id)

        for member in all_family_members:
            is_notification_enabled = (
                self.family_settings_helper.is_notification_enabled(
                    user_id=member["user_id"],
                    family_id=family_id,
                    notification_type=FamliyNotificationType.NEW_FAMILY_MEMEBER,
                )
            )

            if is_notification_enabled:
                message = f"Welcome {user_id} to the family {family_id}!"
                self.notification_helper.create_notification(
                    user_id=member["user_id"],
                    message=message,
                    notification_type=FamliyNotificationType.NEW_FAMILY_MEMEBER,
                    family_id=family_id,
                )

                # Send iOS push notification
                self.notification_helper.send_to_ios_push_queue(
                    user_id=member["user_id"],
                    title="New Family Member",
                    message=message,
                    notification_type=FamliyNotificationType.NEW_FAMILY_MEMEBER.value,
                    family_id=family_id,
                )

    def _process_new_member_request(self, user_id, family_id):
        admins = self.family_membership_helper.get_all_admins(family_id=family_id)

        for admin_id in admins:
            is_notification_enabled = (
                self.family_settings_helper.is_notification_enabled(
                    user_id=admin_id,
                    family_id=family_id,
                    notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_REQUEST,
                )
            )

            if is_notification_enabled:
                message = f"{user_id} is requesting to join the family {family_id}!"
                self.notification_helper.create_notification(
                    user_id=admin_id,
                    message=message,
                    notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_REQUEST,
                    family_id=family_id,
                )

                # Send iOS push notification
                self.notification_helper.send_to_ios_push_queue(
                    user_id=admin_id,
                    title="Membership Request",
                    message=message,
                    notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_REQUEST.value,
                    family_id=family_id,
                )

    def _process_membership_approved(self, user_id, admin_user, family_id):

        all_members = self.family_membership_helper.get_all_members(family_id)
        self._process_welcome_to_family(user_id, family_id)

        for member in all_members:

            if member["user_id"] == user_id:
                continue

            if member["is_admin"]:
                if member["user_id"] == admin_user:
                    pass

                is_notification_enabled = self.family_settings_helper.is_notification_enabled(
                    user_id=member["user_id"],
                    family_id=family_id,
                    notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_REQUEST,
                )
                if is_notification_enabled:
                    message = f"{admin_user} approved the membership request for {user_id} in {family_id}"
                    self.notification_helper.create_notification(
                        user_id=member["user_id"],
                        message=message,
                        notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_APPROVED,
                        family_id=family_id,
                    )

                    # Send iOS push notification
                    self.notification_helper.send_to_ios_push_queue(
                        user_id=member["user_id"],
                        title="Membership Approved",
                        message=message,
                        notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_APPROVED.value,
                        family_id=family_id,
                    )

            else:
                is_notification_enabled = (
                    self.family_settings_helper.is_notification_enabled(
                        user_id=member["user_id"],
                        family_id=family_id,
                        notification_type=FamliyNotificationType.NEW_FAMILY_MEMEBER,
                    )
                )
                if is_notification_enabled:
                    message = f"{user_id} has joined {family_id}!"
                    self.notification_helper.create_notification(
                        user_id=member["user_id"],
                        message=message,
                        notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_APPROVED,
                        family_id=family_id,
                    )

                    # Send iOS push notification
                    self.notification_helper.send_to_ios_push_queue(
                        user_id=member["user_id"],
                        title="New Member Joined",
                        message=message,
                        notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_APPROVED.value,
                        family_id=family_id,
                    )

    def _process_member_denied_request(self, user_id, admin_user, family_id):
        admins = self.family_membership_helper.get_all_admins(family_id=family_id)

        for admin_id in admins:
            if admin_user == admin_id:
                continue

            is_notification_enabled = (
                self.family_settings_helper.is_notification_enabled(
                    user_id=admin_id,
                    family_id=family_id,
                    notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_DENIED,
                )
            )

            if is_notification_enabled:
                message = f"{admin_user} approved the membership request for {user_id} in {family_id}"
                self.notification_helper.create_notification(
                    user_id=admin_id,
                    message=message,
                    notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_DENIED,
                    family_id=family_id,
                )

                # Send iOS push notification
                self.notification_helper.send_to_ios_push_queue(
                    user_id=admin_id,
                    title="Membership Denied",
                    message=message,
                    notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_DENIED.value,
                    family_id=family_id,
                )
