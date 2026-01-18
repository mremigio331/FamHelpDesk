from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.notification_settings_helper import NotificationSettingsHelper
from models.notification_settings import NotificationSettingsModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/settings",
    summary="Get notification settings for current user",
    response_description="Current user's notification preferences",
)
@exceptions_decorator
def get_settings(request: Request):
    """
    Get Notification Settings Endpoint

    Returns notification settings for the current authenticated user.
    If no settings exist, returns a 500 error as settings should always exist for valid users.

    Returns:
        A JSON response containing:
        - settings: Notification settings object with all preference flags

    Raises:
        401: If user is not authenticated
        500: If notification settings are not found (system error)
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Getting notification settings for current user.")

    # Extract user_token from request.state
    token_user_id = getattr(request.state, "user_token", None)
    logger.info(f"Extracted token_user_id: {token_user_id}")

    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        return JSONResponse(
            content={"error": "Authentication required"},
            status_code=401,
        )

    logger.info(f"Getting notification settings for user: {token_user_id}")

    # Call NotificationSettingsHelper.get_settings
    helper = NotificationSettingsHelper(request_id=request.state.request_id)
    settings = helper.get_settings(token_user_id)

    # If no settings found, this indicates a system error as settings should exist
    if settings is None:
        logger.error(
            f"No notification settings found for user {token_user_id} - this should not happen"
        )
        return JSONResponse(
            content={"error": "Notification settings not found - system error"},
            status_code=500,
        )

    return JSONResponse(
        content={
            "settings": NotificationSettingsModel.clean_returned_settings(settings)
        },
        status_code=200,
    )
