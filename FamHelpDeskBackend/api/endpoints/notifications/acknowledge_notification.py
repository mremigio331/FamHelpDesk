from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from exceptions.user_exceptions import InvalidUserIdException
from decorators.exceptions_decorator import exceptions_decorator
from helpers.notification_helper import NotificationHelper
from constants.services import API_SERVICE

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.put(
    "/{notification_id}/acknowledge",
    summary="Acknowledge a notification",
    response_description="Confirmation that the notification was acknowledged",
)
@exceptions_decorator
def acknowledge_notification(request: Request, notification_id: str):
    """
    Acknowledge Notification Endpoint

    Marks a specific notification as viewed/acknowledged.
    Users can only acknowledge their own notifications - this is enforced
    by using the user ID from the JWT token.

    Args:
        notification_id: The ID of the notification to acknowledge

    Returns:
        A JSON response confirming the notification was acknowledged.
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Acknowledging notification: {notification_id}")

    token_user_id = getattr(request.state, "user_token", None)
    logger.info(f"Extracted token_user_id: {token_user_id}")

    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    notification_helper = NotificationHelper(request_id=request.state.request_id)

    # The helper method uses the user_id from the token, ensuring users can only
    # acknowledge their own notifications
    success = notification_helper.acknowledge_notification(
        user_id=token_user_id, notification_id=notification_id
    )

    if not success:
        logger.warning(
            f"Notification {notification_id} not found for user {token_user_id}"
        )
        return JSONResponse(
            content={
                "error": "Notification not found or does not belong to this user."
            },
            status_code=404,
        )

    return JSONResponse(
        content={
            "message": "Notification acknowledged successfully",
            "notification_id": notification_id,
        },
        status_code=200,
    )
