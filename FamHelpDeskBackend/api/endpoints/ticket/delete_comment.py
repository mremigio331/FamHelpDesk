from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from exceptions.ticket_exceptions import (
    UnauthorizedCommentModificationException,
    CommentEditWindowExpiredException,
    CommentNotFoundException,
)
from helpers.ticket_comment_helper import TicketCommentHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.delete(
    "/comment/delete",
    summary="Delete a comment on a ticket",
    response_description="Success message",
)
@exceptions_decorator
def delete_comment(
    request: Request,
    family_id: str = Query(..., description="The family ID"),
    ticket_id: str = Query(..., description="The ticket ID"),
    comment_id: str = Query(..., description="The comment ID to delete"),
    group_id: str = Query(
        None, description="The group ID (optional for backward compatibility)"
    ),
    queue_id: str = Query(
        None, description="The queue ID (optional for backward compatibility)"
    ),
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Deleting comment on ticket.")

    # Extract user_token from request.state as requesting_user
    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Call TicketCommentHelper.delete_comment
    comment_helper = TicketCommentHelper(request_id=request.state.request_id)

    try:
        success = comment_helper.delete_comment(
            family_id=family_id,
            ticket_id=ticket_id,
            comment_id=comment_id,
            requesting_user=token_user_id,
            group_id=group_id,  # Optional for backward compatibility
            queue_id=queue_id,  # Optional for backward compatibility
        )

        logger.info(f"Successfully deleted comment {comment_id} on ticket {ticket_id}")

        # Return success message with status 200
        return JSONResponse(
            content={
                "message": "Comment deleted successfully",
                "comment_id": comment_id,
                "success": success,
            },
            status_code=200,
        )

    except UnauthorizedCommentModificationException as e:
        logger.warning(f"Unauthorized comment deletion attempt: {str(e)}")
        raise e
    except CommentEditWindowExpiredException as e:
        logger.warning(f"Comment edit window expired: {str(e)}")
        raise e
    except CommentNotFoundException as e:
        logger.warning(f"Comment not found: {str(e)}")
        raise e
