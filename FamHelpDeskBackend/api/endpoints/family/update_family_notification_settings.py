from fastapi import APIRouter, Request, Path
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel
from typing import Optional
import time

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.family_notification_settings_helper import FamilyNotificationSettingsHelper
from models.family_notification_settings import FamilyNotificationSettings

logger = Logger(service=API_SERVICE)
router = APIRouter()


class UpdateFamilyNotificationSettingsRequest(BaseModel):
    """
    Request model for updating family notification settings.
    All fields are optional - only provided fields will be updated.
    """

    # Family
    new_family_creation_enabled: Optional[bool] = None
    welcome_enabled: Optional[bool] = None

    # Family Membership
    welcome_to_family_enabled: Optional[bool] = None
    new_family_member_enabled: Optional[bool] = None
    family_membership_approved: Optional[bool] = None
    family_membership_denied: Optional[bool] = None
    family_membership_invitation: Optional[bool] = None
    family_membership_joined: Optional[bool] = None
    family_membership_left: Optional[bool] = None
    family_membership_request: Optional[bool] = None

    # Group Membership
    group_membership_approved: Optional[bool] = None
    group_membership_denied: Optional[bool] = None
    group_membership_added: Optional[bool] = None
    group_membership_joined: Optional[bool] = None
    group_membership_left: Optional[bool] = None
    group_membership_request: Optional[bool] = None
    new_group_creation: Optional[bool] = None

    # Tickets
    ticket_creation_family: Optional[bool] = None
    ticket_creation_group: Optional[bool] = None
    ticket_assigned: Optional[bool] = None
    ticket_comment: Optional[bool] = None
    ticket_status_change: Optional[bool] = None


@router.put(
    "/{family_id}/notification-settings",
    summary="Update family notification settings for current user",
    response_description="Updated notification preferences for the specified family",
)
@exceptions_decorator
def update_family_notification_settings(
    request: Request,
    body: UpdateFamilyNotificationSettingsRequest,
    family_id: str = Path(..., description="Family ID"),
):
    """
    Update Family Notification Settings Endpoint

    Updates notification settings for the current authenticated user for a specific family.
    Only provided fields will be updated - omitted fields remain unchanged.
    If no settings exist, creates defaults first then applies updates.

    Args:
        family_id: The family ID to update settings for
        body: UpdateFamilyNotificationSettingsRequest with optional boolean fields

    Returns:
        A JSON response containing:
        - settings: Updated family notification settings object with all preference flags

    Raises:
        401: If user is not authenticated
        422: If request validation fails
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Updating family notification settings for family {family_id} and current user."
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
        f"Updating family notification settings for user {token_user_id} in family {family_id}"
    )

    # Call FamilyNotificationSettingsHelper.update_settings
    helper = FamilyNotificationSettingsHelper(request_id=request.state.request_id)

    # Convert request body to dict, filtering out None values
    update_kwargs = {k: v for k, v in body.model_dump().items() if v is not None}

    # Update settings using helper
    updated_settings = helper.update_settings(
        user_id=token_user_id, family_id=family_id, **update_kwargs
    )

    logger.info(
        f"Successfully updated family notification settings for user {token_user_id} in family {family_id}"
    )

    # Return updated settings with status 200
    return JSONResponse(
        content={
            "settings": FamilyNotificationSettings.clean_returned_settings(
                updated_settings
            )
        },
        status_code=200,
    )
