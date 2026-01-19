from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.ticket_helper import TicketHelper
from helpers.entity_ref import EntityRefHelper
from models.ticket import TicketModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/{ticket_id}",
    summary="Get a single ticket by ID with family path",
    response_description="The ticket details",
)
@exceptions_decorator
def get_ticket(request: Request, family_id: str, ticket_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting ticket {ticket_id} from family {family_id}.")

    # Call TicketHelper.get_ticket with simplified signature
    helper = TicketHelper(request_id=request.state.request_id)
    ticket = helper.get_ticket(family_id, ticket_id)

    # Return ticket with status 200 or 404 if not found
    if ticket is None:
        return JSONResponse(
            content={"error": f"Ticket {ticket_id} not found in family {family_id}"},
            status_code=404,
        )

    clean_ticket = TicketModel.clean_returned_ticket(ticket)
    enriched_ticket = EntityRefHelper.enrich_entity_refs(clean_ticket)

    return JSONResponse(
        content={"ticket": enriched_ticket},
        status_code=200,
    )


@router.get(
    "/by-id/{ticket_id}",
    summary="Get a single ticket by ID only (simplified access)",
    response_description="The ticket details",
)
@exceptions_decorator
def get_ticket_by_id(request: Request, ticket_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting ticket {ticket_id} via GSI.")

    # Extract user_token for security validation
    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        return JSONResponse(
            content={"error": "Authentication required"},
            status_code=401,
        )

    # Call TicketHelper.get_ticket_by_id
    helper = TicketHelper(request_id=request.state.request_id)
    ticket = helper.get_ticket_by_id(ticket_id)

    # Return ticket with status 200 or 404 if not found
    if ticket is None:
        return JSONResponse(
            content={"error": f"Ticket {ticket_id} not found"},
            status_code=404,
        )

    # TODO: Add family membership validation here
    # For now, we trust that the JWT contains valid user info
    # In production, you might want to validate that token_user_id
    # has access to ticket.family_id

    clean_ticket = TicketModel.clean_returned_ticket(ticket)
    enriched_ticket = EntityRefHelper.enrich_entity_refs(clean_ticket)

    return JSONResponse(
        content={"ticket": enriched_ticket},
        status_code=200,
    )
