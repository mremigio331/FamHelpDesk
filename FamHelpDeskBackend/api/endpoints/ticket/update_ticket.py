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
from helpers.queue_validation_helper import QueueValidationHelper
from models.ticket import TicketModel, TicketSeverity, TicketStatus

logger = Logger(service=API_SERVICE)
router = APIRouter()


class UpdateTicketRequest(BaseModel):
    family_id: str
    queue_id: str
    ticket_id: str
    title: Optional[str] = None
    description: Optional[str] = None
    severity: Optional[str] = None
    status: Optional[str] = None
    assigned_to: Optional[str] = None

    @validator("family_id", "queue_id", "ticket_id")
    def validate_required_fields_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("Field cannot be empty")
        return v.strip()

    @validator("title")
    def validate_title(cls, v):
        if v is not None:
            v = v.strip()
            if not v:  # If empty string after strip, raise error
                raise ValueError("Title cannot be empty")
        return v

    @validator("severity")
    def validate_severity(cls, v):
        if v is not None:
            if not v or not v.strip():
                raise ValueError("Severity cannot be empty")

            # Map string values to enum values for validation
            severity_mapping = {
                "SEV_1": TicketSeverity.SEV_1.value,
                "SEV_2": TicketSeverity.SEV_2.value,
                "SEV_2_5": TicketSeverity.SEV_2_5.value,
                "SEV_3": TicketSeverity.SEV_3.value,
                "SEV_4": TicketSeverity.SEV_4.value,
                "SEV_5": TicketSeverity.SEV_5.value,
                "1.0": TicketSeverity.SEV_1.value,
                "2.0": TicketSeverity.SEV_2.value,
                "2.5": TicketSeverity.SEV_2_5.value,
                "3.0": TicketSeverity.SEV_3.value,
                "4.0": TicketSeverity.SEV_4.value,
                "5.0": TicketSeverity.SEV_5.value,
            }

            severity_value = v.strip()
            if severity_value not in severity_mapping:
                valid_severities = list(severity_mapping.keys())
                raise ValueError(
                    f"Invalid severity. Must be one of: {valid_severities}"
                )

            return severity_mapping[severity_value]
        return v

    @validator("status")
    def validate_status(cls, v):
        if v is not None:
            if not v or not v.strip():
                raise ValueError("Status cannot be empty")

            status_value = v.strip().upper()
            valid_statuses = [s.value for s in TicketStatus]

            if status_value not in valid_statuses:
                raise ValueError(f"Invalid status. Must be one of: {valid_statuses}")

            return status_value
        return v

    @validator("description", "assigned_to")
    def validate_optional_fields(cls, v):
        if v is not None:
            v = v.strip()
            if not v:  # If empty string after strip, set to None
                return None
        return v


@router.put(
    "/update",
    summary="Update a ticket",
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

    # Validate that family, group, and queue exist (only if we have at least one field to update)
    if any(
        [body.title, body.description, body.severity, body.status, body.assigned_to]
    ):
        validation_helper = QueueValidationHelper(request_id=request.state.request_id)

        # We need to get the ticket first to get the group_id for validation
        helper = TicketHelper(request_id=request.state.request_id)
        existing_ticket = helper.get_ticket(
            family_id=body.family_id,
            queue_id=body.queue_id,
            ticket_id=body.ticket_id,
        )

        if not existing_ticket:
            raise TicketNotFoundException(
                f"Ticket {body.ticket_id} not found in queue {body.queue_id}"
            )

        validation_helper.validate_queue_exists(
            family_id=body.family_id,
            group_id=existing_ticket.group_id,
            queue_id=body.queue_id,
        )

        # Update ticket using TicketHelper
        updated_ticket = helper.update_ticket(
            family_id=body.family_id,
            queue_id=body.queue_id,
            ticket_id=body.ticket_id,
            updated_by=token_user_id,
            title=body.title,
            description=body.description,
            severity=body.severity,
            status=body.status,
            assigned_to=body.assigned_to,
        )
    else:
        # No fields to update, just return the existing ticket
        helper = TicketHelper(request_id=request.state.request_id)
        updated_ticket = helper.get_ticket(
            family_id=body.family_id,
            queue_id=body.queue_id,
            ticket_id=body.ticket_id,
        )

        if not updated_ticket:
            raise TicketNotFoundException(
                f"Ticket {body.ticket_id} not found in queue {body.queue_id}"
            )

    logger.info(
        f"Successfully updated ticket {body.ticket_id} in queue {body.queue_id}"
    )

    return JSONResponse(
        content={"ticket": TicketModel.clean_returned_ticket(updated_ticket)},
        status_code=200,
    )
