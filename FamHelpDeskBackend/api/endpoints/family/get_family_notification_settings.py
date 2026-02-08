from fastapi import APIRouter, Request, Path
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.family_notification_settings_helper import FamilyNotificationSettingsHelper
from models.family_notification_settings import FamilyNotificationSettings

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/notification-settings",
    summary="Get family notification settings for current user",
    response_description="Current user's notification preferences for the specified family",
)
@exceptions_decorator
def get_family_notification_settings(
    request: Request, family_id: str = Path(..., description="Family ID")
):
    """
    Get Family Notification Settings Endpoint

    Returns notification settings for the current authenticated user for a specific family.
    If no settings exist, creates default settings with all notification types enabled.

    Args:
        family_id: The family ID to retrieve settings for

    Returns:
        A JSON response containing:
        - settings: Family notification settings object with all preference flags

    Raises:
        401: If user is not authenticated
        404: If family does not exist or user is not a member
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Getting family notification settings for family {family_id} and current user."
    )

    # Extract user_token from request.state
    token_user_id = getattr(request.state, "user_token", None)
    logger.info(f"Extracted token_user_id: {token_user_id}")

    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        return JSONResponse(
            content={"error": "Authentication required"},
            status_code=401,
        )

    logger.info(
        f"Getting family notification settings for user {token_user_id} in family {family_id}"
    )

    # Call FamilyNotificationSettingsHelper.get_settings
    helper = FamilyNotificationSettingsHelper(request_id=request.state.request_id)
    settings = helper.get_settings(token_user_id, family_id)

    # If no settings found, create default settings (backward compatibility)
    if settings is None:
        logger.info(
            f"No family notification settings found for user {token_user_id} in family {family_id}, "
            f"creating default settings"
        )
        settings = helper.create_default_settings(token_user_id, family_id)

    return JSONResponse(
        content={
            "settings": FamilyNotificationSettings.clean_returned_settings(settings)
        },
        status_code=200,
    )
