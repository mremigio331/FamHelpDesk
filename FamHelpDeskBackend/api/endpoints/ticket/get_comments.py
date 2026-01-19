from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.ticket_comment_helper import TicketCommentHelper
from models.ticket_comment import TicketCommentModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/comment/get",
    summary="Get all comments for a ticket",
    response_description="List of comments ordered by comment_date",
)
@exceptions_decorator
def get_comments(
    request: Request,
    family_id: str = Query(..., description="The family ID"),
    ticket_id: str = Query(..., description="The ticket ID"),
    group_id: str = Query(
        None, description="The group ID (optional for backward compatibility)"
    ),
    queue_id: str = Query(
        None, description="The queue ID (optional for backward compatibility)"
    ),
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Retrieving comments for ticket.")

    # Call TicketCommentHelper.get_comments_for_ticket
    comment_helper = TicketCommentHelper(request_id=request.state.request_id)
    comments = comment_helper.get_comments_for_ticket(
        family_id=family_id,
        ticket_id=ticket_id,
        group_id=group_id,  # Optional for backward compatibility
        queue_id=queue_id,  # Optional for backward compatibility
    )

    logger.info(
        f"Successfully retrieved {len(comments)} comments for ticket {ticket_id}"
    )

    # Return list of comments with status 200
    return JSONResponse(
        content={
            "comments": [
                TicketCommentModel.clean_returned_comment(comment)
                for comment in comments
            ]
        },
        status_code=200,
    )
