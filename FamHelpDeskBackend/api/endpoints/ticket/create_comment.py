from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel, validator

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.ticket_comment_helper import TicketCommentHelper
from models.ticket_comment import TicketCommentModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


class CreateCommentRequest(BaseModel):
    family_id: str
    queue_id: str
    ticket_id: str
    comment_body: str

    @validator("family_id", "queue_id", "ticket_id")
    def validate_required_fields_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("Field cannot be empty")
        return v.strip()

    @validator("comment_body")
    def validate_comment_body_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("Comment body cannot be empty")
        return v.strip()


@router.post(
    "/comment/create",
    summary="Create a comment on a ticket",
    response_description="The created comment",
)
@exceptions_decorator
def create_comment(request: Request, body: CreateCommentRequest):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Creating comment on ticket.")

    # Extract user_token from request.state as comment_user
    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Create comment using TicketCommentHelper
    comment_helper = TicketCommentHelper(request_id=request.state.request_id)
    comment = comment_helper.create_comment(
        family_id=body.family_id,
        queue_id=body.queue_id,
        ticket_id=body.ticket_id,
        comment_user=token_user_id,
        comment_body=body.comment_body,
    )

    logger.info(
        f"Successfully created comment {comment.comment_id} on ticket {body.ticket_id}"
    )

    return JSONResponse(
        content={"comment": TicketCommentModel.clean_returned_comment(comment)},
        status_code=201,
    )
