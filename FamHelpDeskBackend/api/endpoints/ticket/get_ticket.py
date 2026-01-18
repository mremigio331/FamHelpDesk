from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.ticket_helper import TicketHelper
from models.ticket import TicketModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/{queue_id}/{ticket_id}",
    summary="Get a single ticket by ID",
    response_description="The ticket details",
)
@exceptions_decorator
def get_ticket(request: Request, family_id: str, queue_id: str, ticket_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting ticket {ticket_id} from queue {queue_id}.")

    # Call TicketHelper.get_ticket
    helper = TicketHelper(request_id=request.state.request_id)
    ticket = helper.get_ticket(family_id, queue_id, ticket_id)

    # Return ticket with status 200 or 404 if not found
    if ticket is None:
        return JSONResponse(
            content={"error": f"Ticket {ticket_id} not found in queue {queue_id}"},
            status_code=404,
        )

    return JSONResponse(
        content={"ticket": TicketModel.clean_returned_ticket(ticket)},
        status_code=200,
    )
