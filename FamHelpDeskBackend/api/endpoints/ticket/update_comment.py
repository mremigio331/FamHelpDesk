from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel, validator
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from exceptions.ticket_exceptions import (
    UnauthorizedCommentModificationException,
    CommentEditWindowExpiredException,
    CommentNotFoundException,
)
from helpers.ticket_comment_helper import TicketCommentHelper
from models.ticket_comment import TicketCommentModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


class UpdateCommentRequest(BaseModel):
    family_id: str
    ticket_id: str
    comment_id: str
    comment_body: str
    group_id: Optional[str] = None  # Optional for backward compatibility
    queue_id: Optional[str] = None  # Optional for backward compatibility

    @validator("family_id", "ticket_id", "comment_id")
    def validate_required_fields_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("Field cannot be empty")
        return v.strip()

    @validator("comment_body")
    def validate_comment_body_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("Comment body cannot be empty")
        return v.strip()


@router.put(
    "/comment/update",
    summary="Update a comment on a ticket",
    response_description="The updated comment",
)
@exceptions_decorator
def update_comment(request: Request, body: UpdateCommentRequest):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Updating comment on ticket.")

    # Extract user_token from request.state as requesting_user
    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Update comment using TicketCommentHelper
    comment_helper = TicketCommentHelper(request_id=request.state.request_id)

    try:
        updated_comment = comment_helper.update_comment(
            family_id=body.family_id,
            ticket_id=body.ticket_id,
            comment_id=body.comment_id,
            requesting_user=token_user_id,
            comment_body=body.comment_body,
            group_id=body.group_id,  # Optional for backward compatibility
            queue_id=body.queue_id,  # Optional for backward compatibility
        )

        logger.info(
            f"Successfully updated comment {body.comment_id} on ticket {body.ticket_id}"
        )

        return JSONResponse(
            content={
                "comment": TicketCommentModel.clean_returned_comment(updated_comment)
            },
            status_code=200,
        )

    except UnauthorizedCommentModificationException as e:
        logger.warning(f"Unauthorized comment modification attempt: {str(e)}")
        raise e
    except CommentEditWindowExpiredException as e:
        logger.warning(f"Comment edit window expired: {str(e)}")
        raise e
    except CommentNotFoundException as e:
        logger.warning(f"Comment not found: {str(e)}")
        raise e
