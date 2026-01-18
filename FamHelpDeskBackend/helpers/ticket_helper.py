from typing import Optional, List
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger
import uuid
import time

from models.ticket import TicketModel, TicketStatus, TicketSeverity
from helpers.audit_helper import AuditHelper
from helpers.notification_helper import NotificationHelper
from helpers.notification_settings_helper import NotificationSettingsHelper
from models.audit import AuditActions, AuditEntityTypes
from models.notification import NotificationType
from exceptions.ticket_exceptions import (
    TicketNotFoundException,
    InvalidTicketStatusTransitionException,
    TicketReopenWindowExpiredException,
    InvalidTicketStatusException,
    InvalidTicketSeverityException,
)


class TicketHelper:
    def __init__(self, request_id: str = None):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.request_id = request_id
        self.audit_helper = AuditHelper(request_id=request_id)
        self.notification_helper = NotificationHelper(request_id=request_id)
        self.notification_settings_helper = NotificationSettingsHelper(
            request_id=request_id
        )

    def create_ticket(
        self,
        family_id: str,
        group_id: str,
        queue_id: str,
        title: str,
        severity: str,
        created_by: str,
        description: Optional[str] = None,
        assigned_to: Optional[str] = None,
    ) -> TicketModel:
        """
        Create a new ticket with status OPEN.

        Args:
            family_id: The family ID this ticket belongs to
            group_id: The group ID this ticket belongs to
            queue_id: The queue ID this ticket belongs to
            title: The ticket title
            severity: The ticket severity (SEV_1, SEV_2, SEV_2_5, SEV_3, SEV_4, SEV_5)
            created_by: The user ID who created the ticket
            description: Optional ticket description
            assigned_to: Optional user ID the ticket is assigned to

        Returns:
            TicketModel: The created ticket
        """
        # Generate ticket_id using UUID
        ticket_id = str(uuid.uuid4())

        # Set creation_date to current epoch
        creation_date = int(time.time())

        # Create ticket with status OPEN
        ticket = TicketModel(
            pk=TicketModel.create_pk(family_id),
            sk=TicketModel.create_sk(queue_id, ticket_id),
            family_id=family_id,
            group_id=group_id,
            queue_id=queue_id,
            ticket_id=ticket_id,
            title=title,
            severity=severity,
            status=TicketStatus.OPEN.value,
            creation_date=creation_date,
            created_by=created_by,
            private=False,  # Default value as per model
            # GSI attributes are automatically populated by the model
        )

        # Handle optional description field
        if description is not None:
            ticket.description = description

        # Handle optional assigned_to field
        if assigned_to is not None:
            ticket.assigned_to = assigned_to

        # Save ticket to DynamoDB
        ticket.save()

        # Create audit record with action CREATE
        ticket_data = TicketModel.clean_returned_ticket(ticket)
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.TICKET,
            entity_id=ticket_id,
            action=AuditActions.CREATE,
            actor_user_id=created_by,
            after=ticket_data,
        )

        # Create ticket creation notification for the creator (async)
        if self.notification_settings_helper.is_notification_enabled(
            created_by, NotificationType.TICKET_CREATION
        ):
            notification_context = {
                "family_id": family_id,
                "ticket_id": ticket_id,
                "queue_id": queue_id,
                "group_id": group_id,
            }
            self.notification_helper.create_notification_async(
                user_id=created_by,
                message=f"Ticket '{title}' has been created in queue {queue_id}",
                notification_type=NotificationType.TICKET_CREATION,
                **notification_context,
            )

        # Create ticket assignment notification if ticket is assigned during creation (async)
        if assigned_to is not None and assigned_to != created_by:
            if self.notification_settings_helper.is_notification_enabled(
                assigned_to, NotificationType.TICKET_ASSIGNED
            ):
                notification_context = {
                    "family_id": family_id,
                    "ticket_id": ticket_id,
                    "queue_id": queue_id,
                    "group_id": group_id,
                }
                self.notification_helper.create_notification_async(
                    user_id=assigned_to,
                    message=f"Ticket '{title}' has been assigned to you in queue {queue_id}",
                    notification_type=NotificationType.TICKET_ASSIGNED,
                    **notification_context,
                )

        self.logger.info(
            f"Created ticket {ticket_id} in queue {queue_id} for family {family_id}"
        )

        return ticket

    def update_ticket(
        self,
        family_id: str,
        queue_id: str,
        ticket_id: str,
        updated_by: str,
        title: Optional[str] = None,
        description: Optional[str] = None,
        severity: Optional[str] = None,
        status: Optional[str] = None,
        assigned_to: Optional[str] = None,
    ) -> TicketModel:
        """
        Update an existing ticket with validation of status transitions and business rules.

        Args:
            family_id: The family ID this ticket belongs to
            queue_id: The queue ID this ticket belongs to
            ticket_id: The ticket ID to update
            updated_by: The user ID who is updating the ticket
            title: Optional new title
            description: Optional new description
            severity: Optional new severity
            status: Optional new status
            assigned_to: Optional new assigned user

        Returns:
            TicketModel: The updated ticket

        Raises:
            TicketNotFoundException: If the ticket doesn't exist
            InvalidTicketStatusTransitionException: If status transition is invalid
            TicketReopenWindowExpiredException: If trying to reopen outside window
            InvalidTicketStatusException: If status value is invalid
            InvalidTicketSeverityException: If severity value is invalid
        """
        # Retrieve existing ticket
        try:
            ticket = TicketModel.get(
                hash_key=TicketModel.create_pk(family_id),
                range_key=TicketModel.create_sk(queue_id, ticket_id),
            )
        except DoesNotExist:
            raise TicketNotFoundException(
                f"Ticket {ticket_id} not found in queue {queue_id}"
            )

        # Capture before state for audit
        before_state = TicketModel.clean_returned_ticket(ticket)

        # Track changes for notifications
        assignment_changed = False
        old_assigned_to = ticket.assigned_to
        status_changed = False
        old_status = ticket.status

        # Validate severity if provided
        if severity is not None:
            valid_severities = [s.value for s in TicketSeverity]
            if severity not in valid_severities:
                raise InvalidTicketSeverityException(f"Invalid severity: {severity}")

        # Validate status if provided and handle status transitions
        current_time = int(time.time())
        if status is not None:
            valid_statuses = [s.value for s in TicketStatus]
            if status not in valid_statuses:
                raise InvalidTicketStatusException(f"Invalid status: {status}")

            current_status = ticket.status
            new_status = status

            # Validate status transitions
            if current_status != new_status:
                self._validate_status_transition(
                    ticket, current_status, new_status, current_time
                )

                # Handle timestamp fields based on status transitions
                if (
                    current_status == TicketStatus.OPEN.value
                    and new_status == TicketStatus.RESOLVED.value
                ):
                    # OPEN → RESOLVED: Set resolved_date and reopen_until
                    ticket.resolved_date = current_time
                    ticket.reopen_until = current_time + (
                        30 * 24 * 60 * 60
                    )  # 30 days in seconds

                elif (
                    current_status == TicketStatus.RESOLVED.value
                    and new_status == TicketStatus.OPEN.value
                ):
                    # RESOLVED → OPEN: Clear resolved_date and reopen_until
                    ticket.resolved_date = None
                    ticket.reopen_until = None

                elif (
                    current_status == TicketStatus.RESOLVED.value
                    and new_status == TicketStatus.CLOSED.value
                ):
                    # RESOLVED → CLOSED: Set closed_date
                    ticket.closed_date = current_time

        # Enforce reassignment rules based on status
        if assigned_to is not None:
            current_status = status if status is not None else ticket.status
            if current_status == TicketStatus.CLOSED.value:
                # Cannot reassign closed tickets
                pass  # Keep existing assigned_to, don't update
            else:
                # Can reassign OPEN or RESOLVED tickets
                if ticket.assigned_to != assigned_to:
                    assignment_changed = True
                ticket.assigned_to = assigned_to

        # Update other fields if provided
        if title is not None:
            ticket.title = title
        if description is not None:
            ticket.description = description
        if severity is not None:
            ticket.severity = severity
        if status is not None:
            if ticket.status != status:
                status_changed = True
            ticket.status = status

        # Save updated ticket
        ticket.save()

        # Capture after state for audit
        after_state = TicketModel.clean_returned_ticket(ticket)

        # Create audit record with before and after states
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.TICKET,
            entity_id=ticket_id,
            action=AuditActions.UPDATE,
            actor_user_id=updated_by,
            before=before_state,
            after=after_state,
        )

        # Create notifications for assignment changes (async)
        if (
            assignment_changed
            and ticket.assigned_to is not None
            and ticket.assigned_to != updated_by
        ):
            if self.notification_settings_helper.is_notification_enabled(
                ticket.assigned_to, NotificationType.TICKET_ASSIGNED
            ):
                notification_context = {
                    "family_id": family_id,
                    "ticket_id": ticket_id,
                    "queue_id": queue_id,
                    "group_id": ticket.group_id,
                }
                self.notification_helper.create_notification_async(
                    user_id=ticket.assigned_to,
                    message=f"Ticket '{ticket.title}' has been assigned to you in queue {queue_id}",
                    notification_type=NotificationType.TICKET_ASSIGNED,
                    **notification_context,
                )

        # Create notifications for status changes (async)
        if status_changed:
            notification_context = {
                "family_id": family_id,
                "ticket_id": ticket_id,
                "queue_id": queue_id,
                "group_id": ticket.group_id,
            }

            # Notify the ticket creator if they're not the one making the change
            if ticket.created_by != updated_by:
                if self.notification_settings_helper.is_notification_enabled(
                    ticket.created_by, NotificationType.TICKET_STATUS_CHANGED
                ):
                    self.notification_helper.create_notification_async(
                        user_id=ticket.created_by,
                        message=f"Ticket '{ticket.title}' status changed from {old_status} to {ticket.status}",
                        notification_type=NotificationType.TICKET_STATUS_CHANGED,
                        **notification_context,
                    )

            # Notify the assigned user if they exist and are not the one making the change
            if ticket.assigned_to is not None and ticket.assigned_to != updated_by:
                if self.notification_settings_helper.is_notification_enabled(
                    ticket.assigned_to, NotificationType.TICKET_STATUS_CHANGED
                ):
                    self.notification_helper.create_notification_async(
                        user_id=ticket.assigned_to,
                        message=f"Ticket '{ticket.title}' status changed from {old_status} to {ticket.status}",
                        notification_type=NotificationType.TICKET_STATUS_CHANGED,
                        **notification_context,
                    )

        self.logger.info(
            f"Updated ticket {ticket_id} in queue {queue_id} for family {family_id}"
        )

        return ticket

    def _validate_status_transition(
        self,
        ticket: TicketModel,
        current_status: str,
        new_status: str,
        current_time: int,
    ):
        """
        Validate that a status transition is allowed based on business rules.

        Args:
            ticket: The ticket being updated
            current_status: Current ticket status
            new_status: Requested new status
            current_time: Current epoch timestamp

        Raises:
            InvalidTicketStatusTransitionException: If transition is not allowed
            TicketReopenWindowExpiredException: If trying to reopen outside window
        """
        # Terminal status: CLOSED tickets cannot change status
        if current_status == TicketStatus.CLOSED.value:
            raise InvalidTicketStatusTransitionException(
                f"Cannot change status from CLOSED to {new_status}"
            )

        # Initial status restriction: OPEN cannot go directly to CLOSED
        if (
            current_status == TicketStatus.OPEN.value
            and new_status == TicketStatus.CLOSED.value
        ):
            raise InvalidTicketStatusTransitionException(
                "Cannot change status directly from OPEN to CLOSED"
            )

        # Reopen window enforcement: RESOLVED can only go to OPEN within reopen window
        if (
            current_status == TicketStatus.RESOLVED.value
            and new_status == TicketStatus.OPEN.value
        ):
            if ticket.reopen_until is None or current_time >= ticket.reopen_until:
                raise TicketReopenWindowExpiredException(
                    "Cannot reopen ticket: reopen window has expired"
                )

        # Valid transitions:
        # OPEN → RESOLVED (always allowed)
        # RESOLVED → OPEN (within reopen window, checked above)
        # RESOLVED → CLOSED (always allowed)
        valid_transitions = {
            TicketStatus.OPEN.value: [TicketStatus.RESOLVED.value],
            TicketStatus.RESOLVED.value: [
                TicketStatus.OPEN.value,
                TicketStatus.CLOSED.value,
            ],
        }

        if new_status not in valid_transitions.get(current_status, []):
            raise InvalidTicketStatusTransitionException(
                f"Invalid status transition from {current_status} to {new_status}"
            )

    def get_ticket(
        self, family_id: str, queue_id: str, ticket_id: str
    ) -> Optional[TicketModel]:
        """
        Query ticket by family_id, queue_id, and ticket_id.

        Args:
            family_id: The family ID this ticket belongs to
            queue_id: The queue ID this ticket belongs to
            ticket_id: The ticket ID to retrieve

        Returns:
            TicketModel: The ticket if found, None if not found
        """
        try:
            ticket = TicketModel.get(
                hash_key=TicketModel.create_pk(family_id),
                range_key=TicketModel.create_sk(queue_id, ticket_id),
            )
            self.logger.info(
                f"Retrieved ticket {ticket_id} from queue {queue_id} for family {family_id}"
            )
            return ticket
        except DoesNotExist:
            self.logger.info(
                f"Ticket {ticket_id} not found in queue {queue_id} for family {family_id}"
            )
            return None

    def get_tickets_by_queue(self, family_id: str, queue_id: str) -> List[TicketModel]:
        """
        Query all tickets with SK prefix QUEUE#{queue_id}#TICKET#.

        Args:
            family_id: The family ID this ticket belongs to
            queue_id: The queue ID to retrieve tickets from

        Returns:
            List[TicketModel]: List of tickets in the queue
        """
        tickets: List[TicketModel] = []
        sk_prefix = f"QUEUE#{queue_id}#TICKET#"

        for ticket in TicketModel.query(
            hash_key=TicketModel.create_pk(family_id),
            range_key_condition=TicketModel.sk.startswith(sk_prefix),
        ):
            tickets.append(ticket)

        self.logger.info(
            f"Retrieved {len(tickets)} tickets from queue {queue_id} for family {family_id}"
        )
        return tickets

    def get_tickets_by_group(self, family_id: str, group_id: str) -> List[TicketModel]:
        """
        Query all tickets across all queues in a group using GSI for optimal performance.

        Args:
            family_id: The family ID this ticket belongs to
            group_id: The group ID to retrieve tickets from

        Returns:
            List[TicketModel]: List of tickets in the group across all queues
        """
        tickets: List[TicketModel] = []

        # Use GSI to efficiently query tickets by group
        group_gsi_pk = TicketModel.create_group_gsi_pk(family_id, group_id)

        for ticket in TicketModel.group_index.query(
            hash_key=group_gsi_pk,
            range_key_condition=TicketModel.TicketGroupSK.startswith("TICKET#"),
        ):
            tickets.append(ticket)

        self.logger.info(
            f"Retrieved {len(tickets)} tickets from group {group_id} for family {family_id} using GSI"
        )
        return tickets

    def get_tickets_by_assigned_user(
        self, family_id: str, user_id: str
    ) -> List[TicketModel]:
        """
        Query all tickets assigned to a specific user using GSI for optimal performance.

        Args:
            family_id: The family ID this ticket belongs to
            user_id: The user ID to retrieve assigned tickets for

        Returns:
            List[TicketModel]: List of tickets assigned to the user
        """
        tickets: List[TicketModel] = []

        # Use Assignment GSI to efficiently query tickets by assigned user
        assignment_gsi_pk = TicketModel.create_assignment_gsi_pk(family_id, user_id)

        for ticket in TicketModel.assignment_index.query(
            hash_key=assignment_gsi_pk,
            range_key_condition=TicketModel.TicketAssignmentSK.startswith("TICKET#"),
        ):
            tickets.append(ticket)

        self.logger.info(
            f"Retrieved {len(tickets)} tickets assigned to user {user_id} for family {family_id} using GSI"
        )
        return tickets

    def get_tickets_by_status(self, family_id: str, status: str) -> List[TicketModel]:
        """
        Query all tickets with a specific status across all queues in a family.
        Uses DynamoDB filter condition for efficient server-side filtering.

        Args:
            family_id: The family ID this ticket belongs to
            status: The status to filter by (OPEN, RESOLVED, CLOSED)

        Returns:
            List[TicketModel]: List of tickets with the specified status
        """
        tickets: List[TicketModel] = []

        # Query all tickets in the family with server-side filtering by status
        for ticket in TicketModel.query(
            hash_key=TicketModel.create_pk(family_id),
            filter_condition=(
                TicketModel.sk.contains("#TICKET#") & (TicketModel.status == status)
            ),
        ):
            tickets.append(ticket)

        self.logger.info(
            f"Retrieved {len(tickets)} tickets with status {status} for family {family_id}"
        )
        return tickets

    def get_tickets_by_severity(
        self, family_id: str, severity: str
    ) -> List[TicketModel]:
        """
        Query all tickets with a specific severity across all queues in a family.
        Uses DynamoDB filter condition for efficient server-side filtering.

        Args:
            family_id: The family ID this ticket belongs to
            severity: The severity to filter by (SEV_1, SEV_2, SEV_2_5, SEV_3, SEV_4, SEV_5)

        Returns:
            List[TicketModel]: List of tickets with the specified severity
        """
        tickets: List[TicketModel] = []

        # Query all tickets in the family with server-side filtering by severity
        for ticket in TicketModel.query(
            hash_key=TicketModel.create_pk(family_id),
            filter_condition=(
                TicketModel.sk.contains("#TICKET#") & (TicketModel.severity == severity)
            ),
        ):
            tickets.append(ticket)

        self.logger.info(
            f"Retrieved {len(tickets)} tickets with severity {severity} for family {family_id}"
        )
        return tickets
