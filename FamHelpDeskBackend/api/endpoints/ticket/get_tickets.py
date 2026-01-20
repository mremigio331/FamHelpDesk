from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from typing import Optional, List
from pydantic import BaseModel
import json
import base64

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.ticket_helper import TicketHelper
from helpers.entity_ref import EntityRefHelper
from models.ticket import TicketModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


class GetTicketsRequest(BaseModel):
    """Request model for filtering tickets with multiple criteria."""

    queue_ids: Optional[List[str]] = None
    group_ids: Optional[List[str]] = None
    assigned_to_users: Optional[List[str]] = None
    statuses: Optional[List[str]] = None
    severities: Optional[List[float]] = None
    limit: int = 25
    next_token: Optional[str] = None

    class Config:
        json_schema_extra = {
            "example": {
                "group_ids": ["group123", "group456"],
                "statuses": ["OPEN", "RESOLVED"],
                "severities": [1.0, 2.0, 2.5],
                "limit": 25,
                "next_token": None,
            }
        }


@router.post(
    "/tickets/{family_id}/search",
    summary="Search tickets with multiple filters and pagination",
    response_description="Paginated list of tickets based on filter criteria",
)
@exceptions_decorator
def search_tickets(
    request: Request,
    family_id: str,
    body: GetTicketsRequest,
):
    """
    Search tickets with multiple filters applied simultaneously with pagination support.

    Filters can be combined using arrays:
    - queue_ids: Filter by specific queues
    - group_ids: Filter by specific groups (returns tickets across all queues in those groups)
    - assigned_to_users: Filter by assigned user IDs
    - statuses: Filter by ticket statuses (OPEN, RESOLVED, CLOSED)
    - severities: Filter by ticket severities (1.0, 2.0, 2.5, 3.0, 4.0, 5.0)

    All provided filters are applied together (AND logic).
    Within each filter array, items are combined with OR logic.

    Example: group_ids=[A,B] AND severities=[1.0,2.0] means:
    "Tickets in (group A OR group B) AND severity is (1.0 OR 2.0)"

    Args:
        family_id: The family ID (required)
        body: Filter criteria and pagination parameters

    Returns:
        JSONResponse: Paginated list of tickets matching all filter criteria with next_token
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Searching tickets for family {family_id} with filters: "
        f"queue_ids={body.queue_ids}, group_ids={body.group_ids}, "
        f"assigned_to_users={body.assigned_to_users}, statuses={body.statuses}, "
        f"severities={body.severities}, limit={body.limit}"
    )

    # Decode next_token if provided
    last_evaluated_key = None
    if body.next_token:
        try:
            decoded = base64.b64decode(body.next_token).decode("utf-8")
            last_evaluated_key = json.loads(decoded)
        except Exception as e:
            logger.warning(f"Invalid next_token provided: {str(e)}")
            return JSONResponse(
                content={"error": "Invalid pagination token"},
                status_code=400,
            )

    helper = TicketHelper(request_id=request.state.request_id)

    # Use the new multi-filter method
    result = helper.get_tickets_with_multiple_filters(
        family_id=family_id,
        queue_ids=body.queue_ids,
        group_ids=body.group_ids,
        assigned_to_users=body.assigned_to_users,
        statuses=body.statuses,
        severities=body.severities,
        limit=body.limit,
        last_evaluated_key=last_evaluated_key,
    )

    logger.info(f"Retrieved {len(result['tickets'])} tickets with applied filters")

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


# Keep the old GET endpoint for backward compatibility
@router.get(
    "/tickets/{family_id}",
    summary="[Deprecated] Get tickets - use POST /tickets/{family_id}/search instead",
    response_description="Paginated list of tickets based on query parameters",
)
@exceptions_decorator
def get_tickets_legacy(
    request: Request,
    family_id: str,
    queue_id: Optional[str] = Query(None, description="Filter by queue ID"),
    group_id: Optional[str] = Query(None, description="Filter by group ID"),
    assigned_to: Optional[str] = Query(None, description="Filter by assigned user ID"),
    status: Optional[str] = Query(None, description="Filter by ticket status"),
    limit: int = Query(
        default=25, ge=1, le=100, description="Number of tickets to return"
    ),
    next_token: Optional[str] = Query(default=None, description="Pagination token"),
):
    """Legacy GET endpoint for backward compatibility. Use POST /tickets/{family_id}/search for new features."""

    # Convert single values to arrays for the new system
    search_request = GetTicketsRequest(
        queue_ids=[queue_id] if queue_id else None,
        group_ids=[group_id] if group_id else None,
        assigned_to_users=[assigned_to] if assigned_to else None,
        statuses=[status] if status else None,
        severities=None,
        limit=limit,
        next_token=next_token,
    )

    # Delegate to the new search endpoint
    return search_tickets(request, family_id, search_request)
