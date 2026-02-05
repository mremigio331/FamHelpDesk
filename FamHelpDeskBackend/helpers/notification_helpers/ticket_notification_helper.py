from helpers.notification_helper import NotificationHelper
from helpers.family_notification_settings_helper import FamilyNotificationSettingsHelper
from helpers.family_membership_helper import FamilyMembershipHelper
from models.family_notification_settings import FamliyNotificationType
from helpers.ticket_helper import TicketHelper


class TicketNotificationHelper:
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
        self.ticket_helper = TicketHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_topic_arn=notification_topic_arn,
        )

    def process_notification(self, notification_type: FamliyNotificationType, **kwargs):
        if (
            notification_type == FamliyNotificationType.TICKET_CREATION_FAMILY
            or FamliyNotificationType.TICKET_CREATION_GROUP
        ):
            self._process_new_ticket(**kwargs)

    def _process_new_ticket(self, ticket_id):
        full_ticket = self.ticket_helper.get_ticket_by_id(ticket_id)

        ticket_title = full_ticket.title
        ticket_severity = full_ticket.severity
        ticket_created_by = full_ticket.created_by
        ticket_assigned_to = full_ticket.assigned_to
        family_id = full_ticket.family_id

        all_members = self.family_membership_helper.get_all_members(family_id)

        for member in all_members:
            if member["user_id"] == ticket_created_by:
                continue

            if member["user_id"] == ticket_assigned_to:
                message = f"{ticket_created_by} just created a new {ticket_severity} ticket in {family_id} and assigned it to you. "
                self.notification_helper.create_notification(
                    user_id=member["user_id"],
                    message=message,
                    notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_APPROVED,
                    family_id=family_id,
                )
