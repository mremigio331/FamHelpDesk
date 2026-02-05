from helpers.notification_helper import NotificationHelper
from helpers.family_helper import FamilyHelper
from helpers.family_notification_settings_helper import FamilyNotificationSettingsHelper
from helpers.family_membership_helper import FamilyMembershipHelper
from helpers.group_membership_helper import GroupMembershipHelper
from models.family_notification_settings import FamliyNotificationType


class GroupMembershipNotificationHelper:
    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
        notification_topic_arn: str = None,
    ):
        self.notification_helper = NotificationHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_topic_arn=notification_topic_arn,
        )
        self.family_settings_helper = FamilyNotificationSettingsHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_topic_arn=notification_topic_arn,
        )
        self.family_membership_helper = FamilyMembershipHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_topic_arn=notification_topic_arn,
        )
        self.group_membership_helper = GroupMembershipHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_topic_arn=notification_topic_arn,
        )

    def process_notification(self, notification_type: FamliyNotificationType, **kwargs):
        if notification_type == FamliyNotificationType.NEW_GROUP_CREATION:
            self._process_new_group_creation(**kwargs)
        elif notification_type == FamliyNotificationType.GROUP_MEMBERSHIP_REQUEST:
            self._process_group_membership_request(**kwargs)
        elif notification_type == FamliyNotificationType.GROUP_MEMBERSHIP_ADDED:
            self._process_group_member_added(**kwargs)
        elif notification_type == FamliyNotificationType.GROUP_MEMBERSHIP_DENIED:
            self._process_group_member_denied_request(**kwargs)
        elif notification_type == FamliyNotificationType.GROUP_MEMBERSHIP_ADDED:
            self._process_group_member_added(**kwargs)

    def _process_new_group_creation(self, user_id, family_id, group_id):
        all_members = self.family_membership_helper.get_all_members(family_id)

        for member in all_members:
            if member["user_id"] == user_id:
                message = f"You successfully created the new group {group_id} in {family_id}. Add some unique queues now!"
                self.notification_helper.create_notification(
                    user_id=member["user_id"],
                    message=message,
                    notification_type=FamliyNotificationType.NEW_GROUP_CREATION,
                    family_id=family_id,
                )
                continue
            is_notification_enabled = (
                self.family_settings_helper.is_notification_enabled(
                    user_id=member["user_id"],
                    family_id=family_id,
                    notification_type=FamliyNotificationType.NEW_GROUP_CREATION,
                )
            )
            if is_notification_enabled:
                message = f"{user_id} created a new group {group_id} in {family_id}!"
                self.notification_helper.create_notification(
                    user_id=member["user_id"],
                    message=message,
                    notification_type=FamliyNotificationType.NEW_GROUP_CREATION,
                    family_id=family_id,
                )

    def _process_group_membership_request(self, user_id, family_id, group_id):
        admins = self.group_membership_helper.get_all_admins(
            family_id=family_id, group_id=group_id
        )

        for admin_id in admins:
            is_notification_enabled = (
                self.family_settings_helper.is_notification_enabled(
                    user_id=admin_id,
                    family_id=family_id,
                    notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_REQUEST,
                )
            )

            if is_notification_enabled:
                message = f"{user_id} is requesting to join the group {group_id} in {family_id}!"
                self.notification_helper.create_notification(
                    user_id=admin_id,
                    message=message,
                    notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_REQUEST,
                    family_id=family_id,
                )

    def _process_group_membeship_approved(
        self, user_id, admin_user, family_id, group_id
    ):

        all_members = self.group_membership_helper.get_all_memberships_by_user(
            family_id=family_id, group_id=group_id
        )

        for member in all_members:

            if member["user_id"] == user_id:
                message = f"Your request to join the group {group_id} in {family_id} has been approved."
                self.notification_helper.create_notification(
                    user_id=member["user_id"],
                    message=message,
                    notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_APPROVED,
                    family_id=family_id,
                )

            if member["is_admin"]:
                if member == admin_user:
                    pass

                is_notification_enabled = self.family_settings_helper.is_notification_enabled(
                    user_id=member["user_id"],
                    family_id=family_id,
                    notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_APPROVED,
                )
                if is_notification_enabled:
                    message = f"{admin_user} approved the membership request for {user_id} for the group {group_id} in the family {family_id}"

                    self.notification_helper.create_notification(
                        user_id=member["user_id"],
                        message=message,
                        notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_APPROVED,
                        family_id=family_id,
                    )

            else:
                is_notification_enabled = self.family_settings_helper.is_notification_enabled(
                    user_id=member["user_id"],
                    family_id=family_id,
                    notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_APPROVED,
                )
                if is_notification_enabled:
                    message = f"{user_id} has joined {family_id}!"
                    self.notification_helper.create_notification(
                        user_id=member["user_id"],
                        message=message,
                        notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_APPROVED,
                        family_id=family_id,
                    )

    def _process_group_member_denied_request(
        self, user_id, admin_user, family_id, group_id
    ):
        admins = self.group_membership_helper.get_all_admins(
            family_id=family_id, group_id=group_id
        )

        for admin_id in admins:
            if admin_user == admin_id:
                continue

            is_notification_enabled = (
                self.family_settings_helper.is_notification_enabled(
                    user_id=admin_id,
                    family_id=family_id,
                    notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_DENIED,
                )
            )

            if is_notification_enabled:
                message = f"{admin_user} denied {user_id}'s membership request for group {group_id} in {family_id}"
                self.notification_helper.create_notification(
                    user_id=admin_id,
                    message=message,
                    notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_DENIED,
                    family_id=family_id,
                )

    def _process_group_member_added(self, user_id, admin_user, family_id, group_id):
        all_members = self.group_membership_helper.get_all_memberships_by_user(
            family_id=family_id, group_id=group_id
        )

        for member in all_members:

            if member["user_id"] == user_id:
                message = (
                    f"{admin_user} added you to the group {group_id} in {family_id}"
                )
                self.notification_helper.create_notification(
                    user_id=member["user_id"],
                    message=message,
                    notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_ADDED,
                    family_id=family_id,
                )

            if member["is_admin"]:
                if member == admin_user:
                    pass

                is_notification_enabled = (
                    self.family_settings_helper.is_notification_enabled(
                        user_id=member["user_id"],
                        family_id=family_id,
                        notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_ADDED,
                    )
                )
                if is_notification_enabled:
                    message = f"{admin_user} added {user_id} to the group {group_id} in {family_id}"

                    self.notification_helper.create_notification(
                        user_id=member["user_id"],
                        message=message,
                        notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_ADDED,
                        family_id=family_id,
                    )

            else:
                is_notification_enabled = (
                    self.family_settings_helper.is_notification_enabled(
                        user_id=member["user_id"],
                        family_id=family_id,
                        notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_ADDED,
                    )
                )
                if is_notification_enabled:
                    message = f"{user_id} has been added to group {group_id} in family {family_id}!"
                    self.notification_helper.create_notification(
                        user_id=member["user_id"],
                        message=message,
                        notification_type=FamliyNotificationType.GROUP_MEMBERSHIP_ADDED,
                        family_id=family_id,
                    )
