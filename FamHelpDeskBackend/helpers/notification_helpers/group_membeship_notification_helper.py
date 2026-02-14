from aws_lambda_powertools import Logger

from helpers.notification_helper import NotificationHelper
from helpers.ios_notification_helper import iOSNotificationHelper
from helpers.family_helper import FamilyHelper
from helpers.family_notification_settings_helper import FamilyNotificationSettingsHelper
from helpers.family_membership_helper import FamilyMembershipHelper
from helpers.group_membership_helper import GroupMembershipHelper
from models.family_notification_settings import FamilyNotificationType


class GroupMembershipNotificationHelper:
    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
        notification_queue_url: str = None,
    ):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.notification_helper = NotificationHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )
        self.ios_notification_helper = iOSNotificationHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
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
        self.group_membership_helper = GroupMembershipHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )

    def process_notification(self, notification_type: FamilyNotificationType, **kwargs):
        self.logger.info(
            f"Processing group membership notification: {notification_type}"
        )
        try:
            if notification_type == FamilyNotificationType.NEW_GROUP_CREATION:
                self._process_new_group_creation(**kwargs)
            elif notification_type == FamilyNotificationType.GROUP_MEMBERSHIP_REQUEST:
                self._process_group_membership_request(**kwargs)
            elif notification_type == FamilyNotificationType.GROUP_MEMBERSHIP_ADDED:
                self._process_group_member_added(**kwargs)
            elif notification_type == FamilyNotificationType.GROUP_MEMBERSHIP_DENIED:
                self._process_group_member_denied_request(**kwargs)
            self.logger.info(f"Successfully processed {notification_type}")
        except Exception as e:
            self.logger.error(f"Error processing {notification_type}: {e}")
            raise

    def _process_new_group_creation(self, user_id, family_id, group_id):
        self.logger.info(
            f"Processing new group creation for group {group_id} in family {family_id} by user {user_id}"
        )
        all_members = self.family_membership_helper.get_all_members(family_id)
        self.logger.info(f"Found {len(all_members)} family members to notify")

        for member in all_members:
            if member["user_id"] == user_id:
                message = f"You successfully created the new group {group_id} in {family_id}. Add some unique queues now!"
                self.notification_helper.create_notification(
                    user_id=member["user_id"],
                    message=message,
                    notification_type=FamilyNotificationType.NEW_GROUP_CREATION,
                    family_id=family_id,
                )

                # Send iOS push notification
                self.ios_notification_helper.send_ios_push_notification(
                    user_id=member["user_id"],
                    title="Group Created",
                    message=message,
                    notification_type=FamilyNotificationType.NEW_GROUP_CREATION.value,
                    data={
                        "family_id": family_id,
                        "group_id": group_id,
                    },
                )
                continue
            is_notification_enabled = (
                self.family_settings_helper.is_notification_enabled(
                    user_id=member["user_id"],
                    family_id=family_id,
                    notification_type=FamilyNotificationType.NEW_GROUP_CREATION,
                )
            )
            if is_notification_enabled:
                message = f"{user_id} created a new group {group_id} in {family_id}!"
                self.notification_helper.create_notification(
                    user_id=member["user_id"],
                    message=message,
                    notification_type=FamilyNotificationType.NEW_GROUP_CREATION,
                    family_id=family_id,
                )

                # Send iOS push notification
                self.ios_notification_helper.send_ios_push_notification(
                    user_id=member["user_id"],
                    title="New Group Created",
                    message=message,
                    notification_type=FamilyNotificationType.NEW_GROUP_CREATION.value,
                    data={
                        "family_id": family_id,
                        "group_id": group_id,
                    },
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
                    notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_REQUEST,
                )
            )

            if is_notification_enabled:
                message = f"{user_id} is requesting to join the group {group_id} in {family_id}!"
                self.notification_helper.create_notification(
                    user_id=admin_id,
                    message=message,
                    notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_REQUEST,
                    family_id=family_id,
                )

                # Send iOS push notification
                self.ios_notification_helper.send_ios_push_notification(
                    user_id=admin_id,
                    title="Group Membership Request",
                    message=message,
                    notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_REQUEST.value,
                    data={
                        "family_id": family_id,
                        "group_id": group_id,
                    },
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
                    notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_APPROVED,
                    family_id=family_id,
                )

                # Send iOS push notification
                self.ios_notification_helper.send_ios_push_notification(
                    user_id=member["user_id"],
                    title="Group Membership Approved",
                    message=message,
                    notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_APPROVED.value,
                    data={
                        "family_id": family_id,
                        "group_id": group_id,
                    },
                )

            if member["is_admin"]:
                if member["user_id"] == admin_user:
                    pass

                is_notification_enabled = self.family_settings_helper.is_notification_enabled(
                    user_id=member["user_id"],
                    family_id=family_id,
                    notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_APPROVED,
                )
                if is_notification_enabled:
                    message = f"{admin_user} approved the membership request for {user_id} for the group {group_id} in the family {family_id}"

                    self.notification_helper.create_notification(
                        user_id=member["user_id"],
                        message=message,
                        notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_APPROVED,
                        family_id=family_id,
                    )

                    # Send iOS push notification
                    self.ios_notification_helper.send_ios_push_notification(
                        user_id=member["user_id"],
                        title="Group Membership Approved",
                        message=message,
                        notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_APPROVED.value,
                        data={
                            "family_id": family_id,
                            "group_id": group_id,
                        },
                    )

            else:
                is_notification_enabled = self.family_settings_helper.is_notification_enabled(
                    user_id=member["user_id"],
                    family_id=family_id,
                    notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_APPROVED,
                )
                if is_notification_enabled:
                    message = f"{user_id} has joined {family_id}!"
                    self.notification_helper.create_notification(
                        user_id=member["user_id"],
                        message=message,
                        notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_APPROVED,
                        family_id=family_id,
                    )

                    # Send iOS push notification
                    self.ios_notification_helper.send_ios_push_notification(
                        user_id=member["user_id"],
                        title="New Group Member",
                        message=message,
                        notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_APPROVED.value,
                        data={
                            "family_id": family_id,
                            "group_id": group_id,
                        },
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
                    notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_DENIED,
                )
            )

            if is_notification_enabled:
                message = f"{admin_user} denied {user_id}'s membership request for group {group_id} in {family_id}"
                self.notification_helper.create_notification(
                    user_id=admin_id,
                    message=message,
                    notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_DENIED,
                    family_id=family_id,
                )

                # Send iOS push notification
                self.ios_notification_helper.send_ios_push_notification(
                    user_id=admin_id,
                    title="Group Membership Denied",
                    message=message,
                    notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_DENIED.value,
                    data={
                        "family_id": family_id,
                        "group_id": group_id,
                    },
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
                    notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_ADDED,
                    family_id=family_id,
                )

                # Send iOS push notification
                self.ios_notification_helper.send_ios_push_notification(
                    user_id=member["user_id"],
                    title="Added to Group",
                    message=message,
                    notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_ADDED.value,
                    data={
                        "family_id": family_id,
                        "group_id": group_id,
                    },
                )

            if member["is_admin"]:
                if member["user_id"] == admin_user:
                    pass

                is_notification_enabled = (
                    self.family_settings_helper.is_notification_enabled(
                        user_id=member["user_id"],
                        family_id=family_id,
                        notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_ADDED,
                    )
                )
                if is_notification_enabled:
                    message = f"{admin_user} added {user_id} to the group {group_id} in {family_id}"

                    self.notification_helper.create_notification(
                        user_id=member["user_id"],
                        message=message,
                        notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_ADDED,
                        family_id=family_id,
                    )

                    # Send iOS push notification
                    self.ios_notification_helper.send_ios_push_notification(
                        user_id=member["user_id"],
                        title="Group Member Added",
                        message=message,
                        notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_ADDED.value,
                        data={
                            "family_id": family_id,
                            "group_id": group_id,
                        },
                    )

            else:
                is_notification_enabled = (
                    self.family_settings_helper.is_notification_enabled(
                        user_id=member["user_id"],
                        family_id=family_id,
                        notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_ADDED,
                    )
                )
                if is_notification_enabled:
                    message = f"{user_id} has been added to group {group_id} in family {family_id}!"
                    self.notification_helper.create_notification(
                        user_id=member["user_id"],
                        message=message,
                        notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_ADDED,
                        family_id=family_id,
                    )

                    # Send iOS push notification
                    self.ios_notification_helper.send_ios_push_notification(
                        user_id=member["user_id"],
                        title="Group Member Added",
                        message=message,
                        notification_type=FamilyNotificationType.GROUP_MEMBERSHIP_ADDED.value,
                        data={
                            "family_id": family_id,
                            "group_id": group_id,
                        },
                    )
