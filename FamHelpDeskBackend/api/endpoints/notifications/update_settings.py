from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.notification_settings_helper import NotificationSettingsHelper
from models.notification_settings import NotificationSettingsModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


class UpdateNotificationSettingsRequest(BaseModel):
    """
    Request model for updating notification settings.
    All fields are optional - only provided fields will be updated.
    """

    welcome_enabled: Optional[bool] = None
    membership_enabled: Optional[bool] = None
    ticket_creation_enabled: Optional[bool] = None
    ticket_assigned_enabled: Optional[bool] = None
    ticket_comment_enabled: Optional[bool] = None
    ticket_status_changed_enabled: Optional[bool] = None
    group_invitation_enabled: Optional[bool] = None


@router.put(
    "/settings",
    summary="Update notification settings for current user",
    response_description="Updated notification preferences",
)
@exceptions_decorator
def update_settings(request: Request, body: UpdateNotificationSettingsRequest):
    """
    Update Notification Settings Endpoint

    Updates notification settings for the current authenticated user.
    Only provided fields will be updated - omitted fields remain unchanged.
    If no settings exist, creates defaults first then applies updates.

    Args:
        body: UpdateNotificationSettingsRequest with optional boolean fields

    Returns:
        A JSON response containing:
        - settings: Updated notification settings object with all preference flags

    Raises:
        401: If user is not authenticated
        422: If request validation fails
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Updating notification settings for current user.")

    # Extract user_token from request.state
    token_user_id = getattr(request.state, "user_token", None)
    logger.info(f"Extracted token_user_id: {token_user_id}")

    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        return JSONResponse(
            content={"error": "Authentication required"},
            status_code=401,
        )

    logger.info(f"Updating notification settings for user: {token_user_id}")

    # Call NotificationSettingsHelper.update_settings
    helper = NotificationSettingsHelper(request_id=request.state.request_id)
    updated_settings = helper.update_settings(
        user_id=token_user_id,
        welcome_enabled=body.welcome_enabled,
        membership_enabled=body.membership_enabled,
        ticket_creation_enabled=body.ticket_creation_enabled,
        ticket_assigned_enabled=body.ticket_assigned_enabled,
        ticket_comment_enabled=body.ticket_comment_enabled,
        ticket_status_changed_enabled=body.ticket_status_changed_enabled,
        group_invitation_enabled=body.group_invitation_enabled,
    )

    logger.info(f"Successfully updated notification settings for user: {token_user_id}")

    # Return updated settings with status 200
    return JSONResponse(
        content={
            "settings": NotificationSettingsModel.clean_returned_settings(
                updated_settings
            )
        },
        status_code=200,
    )
