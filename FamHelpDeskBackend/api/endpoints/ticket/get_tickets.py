from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from typing import Optional, List

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.ticket_helper import TicketHelper
from models.ticket import TicketModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}",
    summary="Get tickets with multiple query modes",
    response_description="List of tickets based on query parameters",
)
@exceptions_decorator
def get_tickets(
    request: Request,
    family_id: str,
    queue_id: Optional[str] = Query(None, description="Filter by queue ID"),
    group_id: Optional[str] = Query(None, description="Filter by group ID"),
    assigned_to: Optional[str] = Query(None, description="Filter by assigned user ID"),
    status: Optional[str] = Query(None, description="Filter by ticket status"),
    severity: Optional[str] = Query(None, description="Filter by ticket severity"),
):
    """
    Get tickets with multiple query modes based on provided parameters.

    Query modes (in order of precedence):
    - queue_id: Returns all tickets in the specified queue
    - group_id: Returns all tickets across all queues in the specified group
    - assigned_to: Returns all tickets assigned to the specified user
    - status: Returns all tickets with the specified status
    - severity: Returns all tickets with the specified severity
    - No filters: Returns all tickets in the family

    Args:
        family_id: The family ID (required)
        queue_id: Optional queue ID to filter by
        group_id: Optional group ID to filter by
        assigned_to: Optional user ID to filter by assigned tickets
        status: Optional status to filter by (OPEN, RESOLVED, CLOSED)
        severity: Optional severity to filter by (SEV_1, SEV_2, SEV_2_5, SEV_3, SEV_4, SEV_5)

    Returns:
        JSONResponse: List of tickets matching the query parameters
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Getting tickets for family {family_id} with filters: queue_id={queue_id}, group_id={group_id}, assigned_to={assigned_to}, status={status}, severity={severity}"
    )

    helper = TicketHelper(request_id=request.state.request_id)
    tickets: List[TicketModel] = []

    # Implement logic to call appropriate TicketHelper method based on provided parameters
    # Priority order: queue_id > group_id > assigned_to > status > severity

    if queue_id is not None:
        # Requirements 3.2: Return all tickets in that queue
        tickets = helper.get_tickets_by_queue(family_id, queue_id)
        logger.info(f"Retrieved {len(tickets)} tickets by queue {queue_id}")

    elif group_id is not None:
        # Requirements 3.3: Return all tickets across all queues in that group
        tickets = helper.get_tickets_by_group(family_id, group_id)
        logger.info(f"Retrieved {len(tickets)} tickets by group {group_id}")

    elif assigned_to is not None:
        # Requirements 3.4: Return all tickets assigned to that user across all queues
        tickets = helper.get_tickets_by_assigned_user(family_id, assigned_to)
        logger.info(f"Retrieved {len(tickets)} tickets assigned to user {assigned_to}")

    elif status is not None:
        # Requirements 3.5: Return all tickets with that status across all queues
        tickets = helper.get_tickets_by_status(family_id, status)
        logger.info(f"Retrieved {len(tickets)} tickets with status {status}")

    elif severity is not None:
        # Requirements 3.6: Return all tickets with that severity across all queues
        tickets = helper.get_tickets_by_severity(family_id, severity)
        logger.info(f"Retrieved {len(tickets)} tickets with severity {severity}")

    else:
        # No specific filters provided - return all tickets in the family
        tickets = helper.get_all_tickets_by_family(family_id)
        logger.info(f"Retrieved {len(tickets)} total tickets for family {family_id}")

    # Clean and return the tickets
    cleaned_tickets = [TicketModel.clean_returned_ticket(ticket) for ticket in tickets]

    return JSONResponse(
        content={"tickets": cleaned_tickets, "count": len(cleaned_tickets)},
        status_code=200,
    )
