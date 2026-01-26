from typing import Optional, List, Dict, Any
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger
import uuid
import time

from models.ticket import TicketModel, TicketStatus
from helpers.audit_helper import AuditHelper
from helpers.notification_helper import NotificationHelper
from helpers.notification_settings_helper import NotificationSettingsHelper
from helpers.entity_ref import EntityRefHelper
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

    def update_last_update(self, family_id: str, ticket_id: str) -> bool:
        """
        Update the last_update_time timestamp for a specific ticket.

        Args:
            family_id: The family ID
            ticket_id: The ticket ID

        Returns:
            bool: True if update was successful, False if ticket not found
        """
        try:
            ticket = TicketModel.get(
                hash_key=TicketModel.create_pk(family_id),
                range_key=TicketModel.create_sk(ticket_id),
            )
            ticket.last_update_time = TicketModel.now_epoch()
            ticket.save()

            self.logger.debug(f"Updated last_update_time for ticket {ticket_id}")
            return True

        except DoesNotExist:
            self.logger.warning(
                f"Could not update last_update_time - ticket {ticket_id} not found"
            )
            return False

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
        # Generate ticket_id using TicketModel's generate_random_id method
        ticket_id = TicketModel.generate_random_id(prefix="T")

        # Set creation_date to current epoch - use the same timestamp for consistency
        current_time = int(time.time())

        # Create ticket with status OPEN
        ticket = TicketModel(
            pk=TicketModel.create_pk(family_id),
            sk=TicketModel.create_sk(ticket_id),
            family_id=family_id,
            group_id=group_id,
            queue_id=queue_id,
            ticket_id=ticket_id,
            title=title,
            severity=severity,
            status=TicketStatus.OPEN.value,
            creation_date=current_time,
            created_by=created_by,
            last_update_time=current_time,  # Set during initialization
            private=False,  # Default value as per model
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
        audit_data = TicketModel.clean_returned_ticket_for_audit(ticket)
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.TICKET,
            entity_id=ticket_id,
            action=AuditActions.CREATE,
            actor_user_id=created_by,
            after=audit_data,
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

    def update_ticket_by_id(
        self,
        ticket_id: str,
        updated_by: str,
        title: Optional[str] = None,
        description: Optional[str] = None,
        severity: Optional[float] = None,
        status: Optional[str] = None,
        assigned_to: Optional[str] = None,
        group_id: Optional[str] = None,
        queue_id: Optional[str] = None,
    ) -> TicketModel:
        """
        Update an existing ticket by ticket_id only with validation of status transitions and business rules.

        Args:
            ticket_id: The ticket ID to update
            updated_by: The user ID who is updating the ticket
            title: Optional new title
            description: Optional new description
            severity: Optional new severity
            status: Optional new status
            assigned_to: Optional new assigned user
            group_id: Optional new group ID
            queue_id: Optional new queue ID

        Returns:
            TicketModel: The updated ticket

        Raises:
            TicketNotFoundException: If the ticket doesn't exist
            InvalidTicketStatusTransitionException: If status transition is invalid
            TicketReopenWindowExpiredException: If trying to reopen outside window
            InvalidTicketStatusException: If status value is invalid
            InvalidTicketSeverityException: If severity value is invalid
        """
        # Get existing ticket using GSI
        ticket = self.get_ticket_by_id(ticket_id)

        # Use the existing update_ticket method with the ticket's family_id
        return self.update_ticket(
            family_id=ticket.family_id,
            ticket_id=ticket_id,
            updated_by=updated_by,
            title=title,
            description=description,
            severity=severity,
            status=status,
            assigned_to=assigned_to,
            group_id=group_id,
            queue_id=queue_id,
        )

    def update_ticket(
        self,
        family_id: str,
        ticket_id: str,
        updated_by: str,
        title: Optional[str] = None,
        description: Optional[str] = None,
        severity: Optional[float] = None,
        status: Optional[str] = None,
        assigned_to: Optional[str] = None,
        group_id: Optional[str] = None,
        queue_id: Optional[str] = None,
    ) -> TicketModel:
        """
        Update an existing ticket with validation of status transitions and business rules.

        Args:
            family_id: The family ID this ticket belongs to
            ticket_id: The ticket ID to update
            updated_by: The user ID who is updating the ticket
            title: Optional new title
            description: Optional new description
            severity: Optional new severity
            status: Optional new status
            assigned_to: Optional new assigned user
            group_id: Optional new group (for moving tickets)
            queue_id: Optional new queue (for moving tickets)

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
                range_key=TicketModel.create_sk(ticket_id),
            )
        except DoesNotExist:
            raise TicketNotFoundException(f"Ticket {ticket_id} not found")

        # Capture before state for audit
        before_state = TicketModel.clean_returned_ticket_for_audit(ticket)

        # Track changes for notifications and last_update
        assignment_changed = False
        old_assigned_to = ticket.assigned_to
        status_changed = False
        old_status = ticket.status
        should_update_last_update = False

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
                    should_update_last_update = (
                        True  # Assignment change triggers last_update
                    )
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
        if group_id is not None:
            ticket.group_id = group_id
        if queue_id is not None:
            ticket.queue_id = queue_id

        # Update last_update timestamp if assignment changed or always for any update
        ticket.last_update_time = TicketModel.now_epoch()

        # Save updated ticket
        ticket.save()

        # Capture after state for audit
        after_state = TicketModel.clean_returned_ticket_for_audit(ticket)

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
                    "queue_id": ticket.queue_id,
                    "group_id": ticket.group_id,
                }
                self.notification_helper.create_notification_async(
                    user_id=ticket.assigned_to,
                    message=f"Ticket '{ticket.title}' has been assigned to you in queue {ticket.queue_id}",
                    notification_type=NotificationType.TICKET_ASSIGNED,
                    **notification_context,
                )

        # Create notifications for status changes (async)
        if status_changed:
            notification_context = {
                "family_id": family_id,
                "ticket_id": ticket_id,
                "queue_id": ticket.queue_id,
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

        self.logger.info(f"Updated ticket {ticket_id} for family {family_id}")

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

    def get_ticket_by_id(self, ticket_id: str) -> TicketModel:
        """
        Query ticket by ticket_id only using GSI.

        Args:
            ticket_id: The ticket ID to retrieve

        Returns:
            TicketModel: The ticket if found

        Raises:
            TicketNotFoundException: If the ticket doesn't exist
        """

        try:
            # Query the ticket_id GSI
            results = list(TicketModel.ticket_id_index.query(ticket_id, limit=1))

            if results:
                ticket = results[0]
                self.logger.info(f"Retrieved ticket {ticket_id} via GSI")
                return ticket
            else:
                self.logger.info(f"Ticket {ticket_id} not found via GSI")
                raise TicketNotFoundException(f"Ticket {ticket_id} not found")

        except TicketNotFoundException:
            # Re-raise TicketNotFoundException as-is
            raise
        except Exception as e:
            self.logger.error(f"Error querying ticket {ticket_id} via GSI: {str(e)}")
            raise TicketNotFoundException(f"Ticket {ticket_id} not found")

    def get_ticket(self, family_id: str, ticket_id: str) -> Optional[TicketModel]:
        """
        Query ticket by family_id and ticket_id.

        Args:
            family_id: The family ID this ticket belongs to
            ticket_id: The ticket ID to retrieve

        Returns:
            TicketModel: The ticket if found, None if not found
        """
        try:
            ticket = TicketModel.get(
                hash_key=TicketModel.create_pk(family_id),
                range_key=TicketModel.create_sk(ticket_id),
            )
            self.logger.info(f"Retrieved ticket {ticket_id} for family {family_id}")
            return ticket
        except DoesNotExist:
            self.logger.info(f"Ticket {ticket_id} not found for family {family_id}")
            return None

    def _get_tickets_with_filter(
        self,
        family_id: str,
        filter_func,
        filter_description: str,
        limit: int = 25,
        last_evaluated_key: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Common method to query tickets with a custom filter using TicketTimeIndex.
        Uses batch-and-filter approach for time-ordered results.

        Args:
            family_id: The family ID this ticket belongs to
            filter_func: Function that takes a ticket item and returns True if it matches the filter
            filter_description: Description of the filter for logging
            limit: Maximum number of tickets to return (default: 25)
            last_evaluated_key: Pagination token from previous request

        Returns:
            Dict containing:
                - tickets: List[TicketModel] - List of filtered tickets ordered by last_update_time (most recent first)
                - next_token: Optional[Dict] - Pagination token for next page (None if no more results)
        """
        tickets: List[TicketModel] = []
        current_last_evaluated_key = last_evaluated_key

        # Keep fetching until we have enough tickets or no more data
        while len(tickets) < limit:
            query_kwargs = {
                "hash_key": family_id,
                "scan_index_forward": False,  # Descending order (most recent first)
                "limit": 100,  # Fetch in batches of 100
            }

            if current_last_evaluated_key:
                query_kwargs["last_evaluated_key"] = current_last_evaluated_key

            # Use TicketTimeIndex GSI to get tickets ordered by last_update_time
            result_page = TicketModel.time_index.query(**query_kwargs)

            # Convert to list and get pagination info
            batch_items = list(result_page)
            batch_tickets = []

            # Process this batch - apply custom filter
            for item in batch_items:
                # Check if this item is a ticket and passes the custom filter
                if (
                    hasattr(item, "sk")
                    and item.sk.startswith("TICKET#")
                    and hasattr(item, "ticket_id")
                    and item.ticket_id is not None
                    and filter_func(item)
                ):
                    batch_tickets.append(item)

            tickets.extend(batch_tickets)

            # Get the last evaluated key for next batch
            current_last_evaluated_key = None
            if (
                hasattr(result_page, "last_evaluated_key")
                and result_page.last_evaluated_key
            ):
                current_last_evaluated_key = result_page.last_evaluated_key

            # If no more data available, break
            if not current_last_evaluated_key or len(batch_items) == 0:
                break

        # Tickets are already sorted by last_update_time from GSI query (most recent first)

        # Trim to exact limit and determine next_token
        next_key = None
        if len(tickets) > limit:
            tickets = tickets[:limit]
            next_key = current_last_evaluated_key
        elif current_last_evaluated_key:
            next_key = current_last_evaluated_key

        self.logger.info(
            f"Retrieved {len(tickets)} tickets {filter_description} for family {family_id}, "
            f"limit: {limit}, has_next_key: {next_key is not None}"
        )

        return {
            "tickets": tickets,
            "next_token": next_key,
        }

    def get_tickets_by_queue(
        self,
        family_id: str,
        queue_id: str,
        limit: int = 25,
        last_evaluated_key: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Query all tickets in a specific queue with pagination support.
        Uses batch-and-filter approach with TicketTimeIndex for time-ordered results.

        Args:
            family_id: The family ID this ticket belongs to
            queue_id: The queue ID to retrieve tickets from
            limit: Maximum number of tickets to return (default: 25)
            last_evaluated_key: Pagination token from previous request

        Returns:
            Dict containing:
                - tickets: List[TicketModel] - List of tickets in the queue ordered by last_update_time (most recent first)
                - next_token: Optional[Dict] - Pagination token for next page (None if no more results)
        """
        return self._get_tickets_with_filter(
            family_id=family_id,
            filter_func=lambda item: hasattr(item, "queue_id")
            and item.queue_id == queue_id,
            filter_description=f"from queue {queue_id}",
            limit=limit,
            last_evaluated_key=last_evaluated_key,
        )

    def get_tickets_by_group(
        self,
        family_id: str,
        group_id: str,
        limit: int = 25,
        last_evaluated_key: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Query all tickets across all queues in a group with pagination support.
        Uses batch-and-filter approach with TicketTimeIndex for time-ordered results.

        Args:
            family_id: The family ID this ticket belongs to
            group_id: The group ID to retrieve tickets from
            limit: Maximum number of tickets to return (default: 25)
            last_evaluated_key: Pagination token from previous request

        Returns:
            Dict containing:
                - tickets: List[TicketModel] - List of tickets in the group across all queues ordered by last_update_time (most recent first)
                - next_token: Optional[Dict] - Pagination token for next page (None if no more results)
        """
        return self._get_tickets_with_filter(
            family_id=family_id,
            filter_func=lambda item: hasattr(item, "group_id")
            and item.group_id == group_id,
            filter_description=f"from group {group_id}",
            limit=limit,
            last_evaluated_key=last_evaluated_key,
        )

    def get_tickets_by_assigned_user(
        self,
        family_id: str,
        user_id: str,
        limit: int = 25,
        last_evaluated_key: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Query all tickets assigned to a specific user with pagination support.
        Uses batch-and-filter approach with TicketTimeIndex for time-ordered results.

        Args:
            family_id: The family ID this ticket belongs to
            user_id: The user ID to retrieve assigned tickets for
            limit: Maximum number of tickets to return (default: 25)
            last_evaluated_key: Pagination token from previous request

        Returns:
            Dict containing:
                - tickets: List[TicketModel] - List of tickets assigned to the user ordered by last_update_time (most recent first)
                - next_token: Optional[Dict] - Pagination token for next page (None if no more results)
        """
        return self._get_tickets_with_filter(
            family_id=family_id,
            filter_func=lambda item: hasattr(item, "assigned_to")
            and item.assigned_to == user_id,
            filter_description=f"assigned to user {user_id}",
            limit=limit,
            last_evaluated_key=last_evaluated_key,
        )

    def get_tickets_by_status(
        self,
        family_id: str,
        status: str,
        limit: int = 25,
        last_evaluated_key: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Query all tickets with a specific status across all queues in a family with pagination support.
        Uses TicketTimeIndex GSI with batch-and-filter approach for time-ordered results.

        Args:
            family_id: The family ID this ticket belongs to
            status: The status to filter by (OPEN, RESOLVED, CLOSED)
            limit: Maximum number of tickets to return (default: 25)
            last_evaluated_key: Pagination token from previous request

        Returns:
            Dict containing:
                - tickets: List[TicketModel] - List of tickets with the specified status ordered by last_update_time (most recent first)
                - next_token: Optional[Dict] - Pagination token for next page (None if no more results)
        """
        return self._get_tickets_with_filter(
            family_id=family_id,
            filter_func=lambda item: hasattr(item, "status") and item.status == status,
            filter_description=f"with status {status}",
            limit=limit,
            last_evaluated_key=last_evaluated_key,
        )

    def get_tickets_by_severity(
        self,
        family_id: str,
        severity: float,
        limit: int = 25,
        last_evaluated_key: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Query all tickets with a specific severity across all queues in a family with pagination support.
        Uses TicketTimeIndex GSI with batch-and-filter approach for time-ordered results.

        Args:
            family_id: The family ID this ticket belongs to
            severity: The severity to filter by (1.0, 2.0, 2.5, 3.0, 4.0, 5.0)
            limit: Maximum number of tickets to return (default: 25)
            last_evaluated_key: Pagination token from previous request

        Returns:
            Dict containing:
                - tickets: List[TicketModel] - List of tickets with the specified severity ordered by last_update_time (most recent first)
                - next_token: Optional[Dict] - Pagination token for next page (None if no more results)
        """
        return self._get_tickets_with_filter(
            family_id=family_id,
            filter_func=lambda item: hasattr(item, "severity")
            and item.severity == severity,
            filter_description=f"with severity {severity}",
            limit=limit,
            last_evaluated_key=last_evaluated_key,
        )

    def get_tickets_with_multiple_filters(
        self,
        family_id: str,
        queue_ids: Optional[List[str]] = None,
        group_ids: Optional[List[str]] = None,
        assigned_to_users: Optional[List[str]] = None,
        statuses: Optional[List[str]] = None,
        severities: Optional[List[float]] = None,
        limit: int = 25,
        last_evaluated_key: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Query tickets with multiple filters applied simultaneously.
        Uses TicketTimeIndex GSI with batch-and-filter approach for time-ordered results.

        Args:
            family_id: The family ID this ticket belongs to
            queue_ids: Optional list of queue IDs to filter by
            group_ids: Optional list of group IDs to filter by
            assigned_to_users: Optional list of user IDs to filter by assigned tickets
            statuses: Optional list of statuses to filter by (OPEN, RESOLVED, CLOSED)
            severities: Optional list of severities to filter by (1.0, 2.0, 2.5, 3.0, 4.0, 5.0)
            limit: Maximum number of tickets to return (default: 25)
            last_evaluated_key: Pagination token from previous request

        Returns:
            Dict containing:
                - tickets: List[TicketModel] - List of tickets matching all filters ordered by last_update_time (most recent first)
                - next_token: Optional[Dict] - Pagination token for next page (None if no more results)
        """
        # Build filter description for logging
        filter_parts = []
        if queue_ids:
            filter_parts.append(f"queue_ids={queue_ids}")
        if group_ids:
            filter_parts.append(f"group_ids={group_ids}")
        if assigned_to_users:
            filter_parts.append(f"assigned_to_users={assigned_to_users}")
        if statuses:
            filter_parts.append(f"statuses={statuses}")
        if severities:
            filter_parts.append(f"severities={severities}")

        filter_description = (
            f"with filters: {', '.join(filter_parts)}" if filter_parts else "no filters"
        )

        def multi_filter_func(item) -> bool:
            """Apply all filters to a ticket item."""
            # Queue filter (OR logic within the list)
            if queue_ids and (
                not hasattr(item, "queue_id") or item.queue_id not in queue_ids
            ):
                return False

            # Group filter (OR logic within the list)
            if group_ids and (
                not hasattr(item, "group_id") or item.group_id not in group_ids
            ):
                return False

            # Assigned to filter (OR logic within the list)
            if assigned_to_users and (
                not hasattr(item, "assigned_to")
                or item.assigned_to not in assigned_to_users
            ):
                return False

            # Status filter (OR logic within the list)
            if statuses and (
                not hasattr(item, "status") or item.status not in statuses
            ):
                return False

            # Severities filter (OR logic within the list)
            if severities and (
                not hasattr(item, "severity") or item.severity not in severities
            ):
                return False

            return True

        return self._get_tickets_with_filter(
            family_id=family_id,
            filter_func=multi_filter_func,
            filter_description=filter_description,
            limit=limit,
            last_evaluated_key=last_evaluated_key,
        )

    def get_all_tickets_by_family(
        self,
        family_id: str,
        limit: int = 25,
        last_evaluated_key: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Query all tickets across all queues in a family with pagination support.
        Uses TicketTimeIndex GSI to get tickets ordered by last_update_time (most recent first).

        Args:
            family_id: The family ID to retrieve all tickets from
            limit: Maximum number of tickets to return (default: 25)
            last_evaluated_key: Pagination token from previous request

        Returns:
            Dict containing:
                - tickets: List[TicketModel] - List of all tickets in the family ordered by last_update_time
                - next_token: Optional[Dict] - Pagination token for next page (None if no more results)
        """
        self.logger.info(
            f"Starting get_all_tickets_by_family for family_id={family_id}"
        )

        tickets: List[TicketModel] = []

        try:
            # Use TicketTimeIndex GSI to get tickets ordered by last_update_time descending
            query_kwargs = {
                "hash_key": family_id,
                "scan_index_forward": False,  # Descending order (most recent first)
                "limit": limit,
            }

            if last_evaluated_key:
                query_kwargs["last_evaluated_key"] = last_evaluated_key

            # Debug: Log the query parameters
            self.logger.info(
                f"DEBUG: get_all_tickets_by_family GSI query kwargs: {query_kwargs}"
            )

            # Execute the query using the time-based GSI - returns tickets in last_update_time order!
            result_iterator = TicketModel.time_index.query(**query_kwargs)

            # Consume the iterator - tickets are already sorted by DynamoDB!
            for ticket in result_iterator:
                tickets.append(ticket)

            # Get the last evaluated key for pagination
            next_key = None
            if hasattr(result_iterator, "last_evaluated_key"):
                next_key = result_iterator.last_evaluated_key
                self.logger.info(f"DEBUG: Next last_evaluated_key: {next_key}")

            # No need to sort - DynamoDB already returned them in last_update_time order!
            self.logger.info(
                f"Query completed. Retrieved {len(tickets)} total tickets for family {family_id} ordered by last_update_time"
            )

            return {
                "tickets": tickets,
                "next_token": next_key,
            }

        except Exception as e:
            self.logger.error(
                f"Error in get_all_tickets_by_family: {str(e)}", exc_info=True
            )
            raise
