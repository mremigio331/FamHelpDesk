from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel, validator
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.ticket_helper import TicketHelper
from helpers.queue_validation_helper import QueueValidationHelper
from models.ticket import TicketModel, TicketSeverity

logger = Logger(service=API_SERVICE)
router = APIRouter()


class CreateTicketRequest(BaseModel):
    family_id: str
    group_id: str
    queue_id: str
    title: str
    severity: str
    description: Optional[str] = None
    assigned_to: Optional[str] = None

    @validator("family_id", "group_id", "queue_id", "title")
    def validate_required_fields_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("Field cannot be empty")
        return v.strip()

    @validator("severity")
    def validate_severity(cls, v):
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
            raise ValueError(f"Invalid severity. Must be one of: {valid_severities}")

        return severity_mapping[severity_value]

    @validator("description", "assigned_to")
    def validate_optional_fields(cls, v):
        if v is not None:
            v = v.strip()
            if not v:  # If empty string after strip, set to None
                return None
        return v


@router.post(
    "/create",
    summary="Create a ticket",
    response_description="The created ticket",
)
@exceptions_decorator
def create_ticket(request: Request, body: CreateTicketRequest):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Creating ticket.")

    # Extract user_token from request.state
    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Validate that family, group, and queue exist
    validation_helper = QueueValidationHelper(request_id=request.state.request_id)
    validation_helper.validate_queue_exists(
        family_id=body.family_id,
        group_id=body.group_id,
        queue_id=body.queue_id,
    )

    # Create ticket using TicketHelper
    helper = TicketHelper(request_id=request.state.request_id)
    ticket = helper.create_ticket(
        family_id=body.family_id,
        group_id=body.group_id,
        queue_id=body.queue_id,
        title=body.title,
        severity=body.severity,
        created_by=token_user_id,
        description=body.description,
        assigned_to=body.assigned_to,
    )

    logger.info(
        f"Successfully created ticket {ticket.ticket_id} in queue {body.queue_id}"
    )

    return JSONResponse(
        content={"ticket": TicketModel.clean_returned_ticket(ticket)},
        status_code=201,
    )
