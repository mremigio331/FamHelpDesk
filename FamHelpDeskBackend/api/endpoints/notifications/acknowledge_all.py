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
    "/acknowledge-all",
    summary="Acknowledge all notifications",
    response_description="Confirmation that all notifications were acknowledged",
)
@exceptions_decorator
def acknowledge_all_notifications(request: Request):
    """
    Acknowledge All Notifications Endpoint

    Marks all unviewed notifications as viewed/acknowledged for the current user.
    Users can only acknowledge their own notifications - this is enforced
    by using the user ID from the JWT token.

    Returns:
        A JSON response confirming how many notifications were acknowledged.
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Acknowledging all notifications for user.")

    token_user_id = getattr(request.state, "user_token", None)
    logger.info(f"Extracted token_user_id: {token_user_id}")

    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    notification_helper = NotificationHelper(request_id=request.state.request_id)

    # Get all unviewed notifications for the user (fetch in batches)
    acknowledged_count = 0
    last_key = None

    while True:
        result = notification_helper.get_notifications(
            user_id=token_user_id, viewed=False, limit=100, last_evaluated_key=last_key
        )

        # Acknowledge each notification in the batch
        for notification in result["notifications"]:
            success = notification_helper.acknowledge_notification(
                user_id=token_user_id, notification_id=notification["notification_id"]
            )
            if success:
                acknowledged_count += 1

        # Check if there are more notifications to process
        if result["next_token"] is None:
            break

        last_key = result["next_token"]

    logger.info(
        f"Acknowledged {acknowledged_count} notifications for user {token_user_id}"
    )

    return JSONResponse(
        content={
            "message": "All notifications acknowledged successfully",
            "acknowledged_count": acknowledged_count,
        },
        status_code=200,
    )
