from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from exceptions.user_exceptions import InvalidUserIdException
from decorators.exceptions_decorator import exceptions_decorator
from helpers.notification_helper import NotificationHelper
from constants.services import API_SERVICE

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/unread",
    summary="Get unread notification count",
    response_description="Count of unread notifications for the requester",
)
@exceptions_decorator
def get_unread_notifications_count(request: Request):
    """
    Get Unread Notifications Count Endpoint

    Returns the count of unread notifications for the current authenticated user.
    Useful for displaying notification badges in the UI.

    Returns:
        A JSON response containing the count of unread notifications.
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Getting unread notification count for user.")

    token_user_id = getattr(request.state, "user_token", None)
    logger.info(f"Extracted token_user_id: {token_user_id}")

    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    notification_helper = NotificationHelper(request_id=request.state.request_id)
    unread_count = notification_helper.get_unviewed_count(user_id=token_user_id)

    return JSONResponse(
        content={
            "unread_count": unread_count,
        },
        status_code=200,
    )
