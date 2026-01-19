from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel, validator
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from exceptions.ticket_exceptions import TicketNotFoundException
from helpers.ticket_comment_helper import TicketCommentHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


class CreateCommentRequest(BaseModel):
    ticket_id: str
    body: str

    @validator("ticket_id")
    def validate_ticket_id_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("Ticket ID cannot be empty")
        return v.strip()

    @validator("body")
    def validate_body_not_empty(cls, v):
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

    try:
        # Create comment using TicketCommentHelper
        comment_helper = TicketCommentHelper(request_id=request.state.request_id)
        comment = comment_helper.create_comment(
            ticket_id=body.ticket_id,
            comment_user=token_user_id,
            comment_body=body.body,
        )

        logger.info(
            f"Successfully created comment {comment['comment_id']} on ticket {body.ticket_id}"
        )

        return JSONResponse(
            content={"comment": comment},
            status_code=201,
        )

    except TicketNotFoundException as e:
        logger.warning(f"Ticket not found for comment creation: {str(e)}")
        raise e
