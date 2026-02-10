from helpers.notification_helper import NotificationHelper
from helpers.family_notification_settings_helper import FamilyNotificationSettingsHelper
from helpers.family_membership_helper import FamilyMembershipHelper
from helpers.audit_helper import AuditHelper
from models.family_notification_settings import FamliyNotificationType
from helpers.ticket_helper import TicketHelper


class TicketNotificationHelper:
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
        self.ticket_helper = TicketHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )
        self.audit_helper = AuditHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )

    def process_notification(self, notification_type: FamliyNotificationType, **kwargs):
        if notification_type in [
            FamliyNotificationType.TICKET_CREATION_FAMILY,
            FamliyNotificationType.TICKET_CREATION_GROUP,
        ]:
            self._process_new_ticket(**kwargs)
        elif notification_type == FamliyNotificationType.TICKET_ASSIGNED:
            self._process_ticket_assigned(**kwargs)
        elif notification_type == FamliyNotificationType.TICKET_COMMENT:
            self._process_ticket_comment(**kwargs)
        elif notification_type == FamliyNotificationType.TICKET_STATUS_CHANGED:
            self._process_ticket_status_changed(**kwargs)
        elif notification_type == FamliyNotificationType.TICKET_RESOLVED:
            self._process_resolved_ticket(**kwargs)

    def _process_new_ticket(self, ticket_id, family_id):
        """
        Process TICKET_CREATED notification.
        Recipients: All family members with ticket_creation_enabled setting.
        """
        full_ticket = self.ticket_helper.get_ticket_by_id(ticket_id)

        ticket_title = full_ticket.title
        ticket_severity = full_ticket.severity
        ticket_created_by = full_ticket.created_by
        ticket_assigned_to = full_ticket.assigned_to

        all_members = self.family_membership_helper.get_all_members(family_id)

        # Determine notification type based on ticket type
        notification_type = (
            FamliyNotificationType.TICKET_CREATION_FAMILY
            if hasattr(full_ticket, "group_id") and full_ticket.group_id is None
            else FamliyNotificationType.TICKET_CREATION_GROUP
        )

        for member in all_members:
            # Skip the creator
            if member["user_id"] == ticket_created_by:
                continue

            # Check if user has ticket creation notifications enabled
            is_notification_enabled = (
                self.family_settings_helper.is_notification_enabled(
                    user_id=member["user_id"],
                    family_id=family_id,
                    notification_type=notification_type,
                )
            )

            if is_notification_enabled:
                # Special message if assigned to this user
                if member["user_id"] == ticket_assigned_to:
                    message = f"{ticket_created_by} just created a new sev {ticket_severity} ticket in {family_id} and assigned it to you."
                else:
                    message = f"{ticket_created_by} just created a new sev {ticket_severity} ticket in {family_id}."

                self.notification_helper.create_notification(
                    user_id=member["user_id"],
                    message=message,
                    notification_type=notification_type,
                    family_id=family_id,
                    ticket_id=ticket_id,
                )

                # Send iOS push notification
                title = (
                    "New Ticket Assigned to You"
                    if member["user_id"] == ticket_assigned_to
                    else "New Ticket Created"
                )
                self.notification_helper.send_to_ios_push_queue(
                    user_id=member["user_id"],
                    title=title,
                    message=message,
                    notification_type=notification_type.value,
                    family_id=family_id,
                    ticket_id=ticket_id,
                )

    def _process_ticket_assigned(self, ticket_id, family_id, **kwargs):
        """
        Process TICKET_ASSIGNED notification.
        Recipients: Only the assigned user (if ticket_assigned_enabled setting is true).

        Accepts either:
        - assigned_to, assigned_by (new format)
        - user_id (legacy format from old notification system)
        """
        # Support both new and legacy parameter formats
        assigned_to = kwargs.get("assigned_to") or kwargs.get("user_id")
        assigned_by = kwargs.get("assigned_by", "someone")

        if not assigned_to:
            raise ValueError(
                "Missing assigned_to or user_id parameter for TICKET_ASSIGNED notification"
            )

        # Check if assigned user has ticket assignment notifications enabled
        is_notification_enabled = self.family_settings_helper.is_notification_enabled(
            user_id=assigned_to,
            family_id=family_id,
            notification_type=FamliyNotificationType.TICKET_ASSIGNED,
        )

        if is_notification_enabled:
            message = (
                f"{assigned_by} assigned ticket {ticket_id} to you in {family_id}."
            )
            self.notification_helper.create_notification(
                user_id=assigned_to,
                message=message,
                notification_type=FamliyNotificationType.TICKET_ASSIGNED,
                family_id=family_id,
                ticket_id=ticket_id,
            )

            # Send iOS push notification
            self.notification_helper.send_to_ios_push_queue(
                user_id=assigned_to,
                title="Ticket Assigned to You",
                message=message,
                notification_type=FamliyNotificationType.TICKET_ASSIGNED.value,
                family_id=family_id,
                ticket_id=ticket_id,
            )

    def _process_ticket_comment(self, ticket_id, comment_author, family_id):
        """
        Process TICKET_COMMENT notification.
        Recipients: All users with audit records for the ticket (if ticket_comment_enabled setting is true).
        """
        # Get all users who have interacted with the ticket
        involved_users = self.audit_helper.get_users_from_ticket_audit(
            family_id, ticket_id
        )

        for user_id in involved_users:
            # Skip the comment author
            if user_id == comment_author:
                continue

            # Check if user has ticket comment notifications enabled
            is_notification_enabled = (
                self.family_settings_helper.is_notification_enabled(
                    user_id=user_id,
                    family_id=family_id,
                    notification_type=FamliyNotificationType.TICKET_COMMENT,
                )
            )

            if is_notification_enabled:
                message = (
                    f"{comment_author} commented on ticket {ticket_id} in {family_id}."
                )
                self.notification_helper.create_notification(
                    user_id=user_id,
                    message=message,
                    notification_type=FamliyNotificationType.TICKET_COMMENT,
                    family_id=family_id,
                    ticket_id=ticket_id,
                )

                # Send iOS push notification
                self.notification_helper.send_to_ios_push_queue(
                    user_id=user_id,
                    title="New Ticket Comment",
                    message=message,
                    notification_type=FamliyNotificationType.TICKET_COMMENT.value,
                    family_id=family_id,
                    ticket_id=ticket_id,
                )

    def _process_ticket_status_changed(
        self, ticket_id, old_status, new_status, changed_by, family_id
    ):
        """
        Process TICKET_STATUS_CHANGED notification.
        Recipients: All users with audit records for the ticket (if ticket_status_changed_enabled setting is true).
        """
        # Get all users who have interacted with the ticket
        involved_users = self.audit_helper.get_users_from_ticket_audit(
            family_id, ticket_id
        )

        for user_id in involved_users:
            # Skip the user who changed the status
            if user_id == changed_by:
                continue

            # Check if user has ticket status change notifications enabled
            is_notification_enabled = (
                self.family_settings_helper.is_notification_enabled(
                    user_id=user_id,
                    family_id=family_id,
                    notification_type=FamliyNotificationType.TICKET_STATUS_CHANGED,
                )
            )

            if is_notification_enabled:
                message = f"{changed_by} changed ticket {ticket_id} status from {old_status} to {new_status} in {family_id}."
                self.notification_helper.create_notification(
                    user_id=user_id,
                    message=message,
                    notification_type=FamliyNotificationType.TICKET_STATUS_CHANGED,
                    family_id=family_id,
                    ticket_id=ticket_id,
                )

                # Send iOS push notification
                self.notification_helper.send_to_ios_push_queue(
                    user_id=user_id,
                    title="Ticket Status Changed",
                    message=message,
                    notification_type=FamliyNotificationType.TICKET_STATUS_CHANGED.value,
                    family_id=family_id,
                    ticket_id=ticket_id,
                )

    def _process_resolved_ticket(self, ticket_id, resolved_by, family_id):
        """
        Process TICKET_RESOLVED notification.
        Recipients: All users with audit records for the ticket (if ticket_resolved_enabled setting is true).
        """
        # Get all users who have interacted with the ticket
        involved_users = self.audit_helper.get_users_from_ticket_audit(
            family_id, ticket_id
        )

        for user_id in involved_users:
            # Skip the user who resolved the ticket
            if user_id == resolved_by:
                continue

            # Check if user has ticket resolved notifications enabled
            is_notification_enabled = (
                self.family_settings_helper.is_notification_enabled(
                    user_id=user_id,
                    family_id=family_id,
                    notification_type=FamliyNotificationType.TICKET_RESOLVED,
                )
            )

            if is_notification_enabled:
                message = f"{resolved_by} resolved ticket {ticket_id} in {family_id}."
                self.notification_helper.create_notification(
                    user_id=user_id,
                    message=message,
                    notification_type=FamliyNotificationType.TICKET_RESOLVED,
                    family_id=family_id,
                    ticket_id=ticket_id,
                )

                # Send iOS push notification
                self.notification_helper.send_to_ios_push_queue(
                    user_id=user_id,
                    title="Ticket Resolved",
                    message=message,
                    notification_type=FamliyNotificationType.TICKET_RESOLVED.value,
                    family_id=family_id,
                    ticket_id=ticket_id,
                )
