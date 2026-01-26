from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel, validator
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from exceptions.ticket_exceptions import (
    TicketNotFoundException,
    InvalidTicketStatusTransitionException,
    TicketReopenWindowExpiredException,
    InvalidTicketStatusException,
    InvalidTicketSeverityException,
)
from helpers.ticket_helper import TicketHelper
from helpers.entity_ref import EntityRefHelper
from models.ticket import TicketModel, TicketStatus

logger = Logger(service=API_SERVICE)
router = APIRouter()


class UpdateTicketRequest(BaseModel):
    ticket_id: str
    title: Optional[str] = None
    description: Optional[str] = None
    severity: Optional[float] = None
    status: Optional[str] = None
    assigned_to: Optional[str] = None
    group_id: Optional[str] = None
    queue_id: Optional[str] = None

    @validator("ticket_id")
    def validate_ticket_id_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("Ticket ID cannot be empty")
        return v.strip()

    @validator("title", "description", "status", "assigned_to", "group_id", "queue_id")
    def validate_optional_fields_not_empty_string(cls, v):
        if v is not None:
            v = v.strip()
            if not v:  # If empty string after strip, set to None
                return None
        return v


@router.put(
    "/update",
    summary="Update a ticket with simplified access",
    response_description="The updated ticket",
)
@exceptions_decorator
def update_ticket(request: Request, body: UpdateTicketRequest):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Updating ticket.")

    # Extract user_token from request.state
    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    try:
        # Update ticket using simplified TicketHelper method
        helper = TicketHelper(request_id=request.state.request_id)

        if any(
            [
                body.title,
                body.description,
                body.severity,
                body.status,
                body.assigned_to,
                body.group_id,
                body.queue_id,
            ]
        ):
            updated_ticket = helper.update_ticket_by_id(
                ticket_id=body.ticket_id,
                updated_by=token_user_id,
                title=body.title,
                description=body.description,
                severity=body.severity,
                status=body.status,
                assigned_to=body.assigned_to,
                group_id=body.group_id,
                queue_id=body.queue_id,
            )
        else:
            # No fields to update, just return the existing ticket
            updated_ticket = helper.get_ticket_by_id(body.ticket_id)

        logger.info(f"Successfully updated ticket {body.ticket_id}")

        clean_ticket = TicketModel.clean_returned_ticket(updated_ticket)
        enriched_ticket = EntityRefHelper.enrich_entity_refs(clean_ticket)

        return JSONResponse(
            content={"ticket": enriched_ticket},
            status_code=200,
        )

    except TicketNotFoundException as e:
        logger.warning(f"Ticket not found for update: {str(e)}")
        raise e
    except (
        InvalidTicketStatusTransitionException,
        TicketReopenWindowExpiredException,
        InvalidTicketStatusException,
        InvalidTicketSeverityException,
    ) as e:
        logger.warning(f"Ticket update validation error: {str(e)}")
        raise e
