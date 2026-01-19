from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from typing import Optional, List
import json
import base64

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.ticket_helper import TicketHelper
from helpers.entity_ref import EntityRefHelper
from models.ticket import TicketModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/tickets/{family_id}",
    summary="Get tickets with multiple query modes and pagination",
    response_description="Paginated list of tickets based on query parameters",
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
    limit: int = Query(
        default=25,
        ge=1,
        le=100,
        description="Number of tickets to return (default: 25, max: 100)",
    ),
    next_token: Optional[str] = Query(
        default=None, description="Pagination token from previous response"
    ),
):
    """
    Get tickets with multiple query modes based on provided parameters with pagination support.

    Query modes (in order of precedence):
    - queue_id: Returns all tickets in the specified queue
    - group_id: Returns all tickets across all queues in the specified group
    - assigned_to: Returns all tickets assigned to the specified user
    - status: Returns all tickets with the specified status
    - severity: Returns all tickets with the specified severity
    - No filters: Returns all tickets in the family

    Args:
        family_id: The family ID (required)
        queue_id: Optional queue ID to filter by (no longer requires group_id)
        group_id: Optional group ID to filter by
        assigned_to: Optional user ID to filter by assigned tickets
        status: Optional status to filter by (OPEN, RESOLVED, CLOSED)
        severity: Optional severity to filter by (SEV_1, SEV_2, SEV_2_5, SEV_3, SEV_4, SEV_5)
        limit: Number of tickets to return (default: 25, max: 100)
        next_token: Pagination token from previous response

    Returns:
        JSONResponse: Paginated list of tickets matching the query parameters with next_token
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Getting tickets for family {family_id} with filters: queue_id={queue_id}, group_id={group_id}, assigned_to={assigned_to}, status={status}, severity={severity}, limit={limit}"
    )

    # Decode next_token if provided
    last_evaluated_key = None
    if next_token:
        try:
            decoded = base64.b64decode(next_token).decode("utf-8")
            last_evaluated_key = json.loads(decoded)
        except Exception as e:
            logger.warning(f"Invalid next_token provided: {str(e)}")
            return JSONResponse(
                content={"error": "Invalid pagination token"},
                status_code=400,
            )

    helper = TicketHelper(request_id=request.state.request_id)
    result: dict = {}

    # Implement logic to call appropriate TicketHelper method based on provided parameters
    # Priority order: queue_id > group_id > assigned_to > status > severity

    if queue_id is not None:
        # Requirements 3.2: Return all tickets in that queue
        # Note: queue_id filtering no longer requires group_id due to simplified sort key structure
        result = helper.get_tickets_by_queue(
            family_id,
            queue_id,
            limit=limit,
            last_evaluated_key=last_evaluated_key,
        )
        logger.info(f"Retrieved {len(result['tickets'])} tickets by queue {queue_id}")

    elif group_id is not None:
        # Requirements 3.3: Return all tickets across all queues in that group
        result = helper.get_tickets_by_group(
            family_id, group_id, limit=limit, last_evaluated_key=last_evaluated_key
        )
        logger.info(f"Retrieved {len(result['tickets'])} tickets by group {group_id}")

    elif assigned_to is not None:
        # Requirements 3.4: Return all tickets assigned to that user across all queues
        result = helper.get_tickets_by_assigned_user(
            family_id, assigned_to, limit=limit, last_evaluated_key=last_evaluated_key
        )
        logger.info(
            f"Retrieved {len(result['tickets'])} tickets assigned to user {assigned_to}"
        )

    elif status is not None:
        # Requirements 3.5: Return all tickets with that status across all queues
        result = helper.get_tickets_by_status(
            family_id, status, limit=limit, last_evaluated_key=last_evaluated_key
        )
        logger.info(f"Retrieved {len(result['tickets'])} tickets with status {status}")

    elif severity is not None:
        # Requirements 3.6: Return all tickets with that severity across all queues
        result = helper.get_tickets_by_severity(
            family_id, severity, limit=limit, last_evaluated_key=last_evaluated_key
        )
        logger.info(
            f"Retrieved {len(result['tickets'])} tickets with severity {severity}"
        )

    else:
        # No specific filters provided - return all tickets in the family
        result = helper.get_all_tickets_by_family(
            family_id, limit=limit, last_evaluated_key=last_evaluated_key
        )
        logger.info(
            f"Retrieved {len(result['tickets'])} total tickets for family {family_id}"
        )

    # Clean and return the tickets
    cleaned_tickets = [
        TicketModel.clean_returned_ticket(ticket) for ticket in result["tickets"]
    ]

    # Enrich all tickets with entity names in one batch operation
    enriched_tickets = EntityRefHelper.enrich_entity_refs(cleaned_tickets)

    # Encode next_token if present
    response_next_token = None
    if result.get("next_token"):
        encoded = base64.b64encode(
            json.dumps(result["next_token"]).encode("utf-8")
        ).decode("utf-8")
        response_next_token = encoded

    return JSONResponse(
        content={
            "tickets": enriched_tickets,
            "count": len(enriched_tickets),
            "next_token": response_next_token,
        },
        status_code=200,
    )
