from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel
from typing import Optional
from exceptions.user_exceptions import (
    InvalidUserIdException,
    UserNotFound,
    ProfileNotPublicOrDoesNotExist,
)
from decorators.exceptions_decorator import exceptions_decorator
from helpers.user_profile_helper import UserProfileHelper
from models.user_profile import UserProfile
from constants.services import API_SERVICE

logger = Logger(service=API_SERVICE)
router = APIRouter()


class UpdateUserProfileRequest(BaseModel):
    display_name: Optional[str] = None
    nick_name: Optional[str] = None


@router.put(
    "/profile",
    summary="Update a user profile",
    response_description="The updated user's profile",
)
@exceptions_decorator
def update_user_profile(request: Request, update_data: UpdateUserProfileRequest):
    """
    Update User Profile Endpoint

    Allows users to update their own profile information.
    Users can only update their own profiles.

    Args:
        update_data: The profile data to update (display_name, nick_name)

    Returns:
        A JSON response containing the updated user's profile information.
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Updating user profile.")

    token_user_id = getattr(request.state, "user_token", None)
    logger.info(f"Extracted token_user_id: {token_user_id}")

    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Validate that at least one field is being updated
    update_dict = update_data.dict(exclude_unset=True)
    if not update_dict:
        logger.warning("No fields provided for update.")
        return JSONResponse(
            content={"error": "At least one field must be provided for update."},
            status_code=400,
        )

    user_helper = UserProfileHelper(request_id=request.state.request_id)

    # Check if user profile exists
    user_profile_data = user_helper.get_profile(user_id=token_user_id)
    if not user_profile_data:
        logger.warning(f"User profile not found for user_id: {token_user_id}")
        raise UserNotFound(f"User with ID {token_user_id} not found.")

    db_user_id = user_profile_data.user_id

    # Ensure user can only update their own profile
    if db_user_id != token_user_id:
        logger.warning(
            f"Access denied: user {token_user_id} tried to update profile for {db_user_id}"
        )
        raise ProfileNotPublicOrDoesNotExist(
            "Access denied: you can only update your own profile."
        )

    try:
        # Update the profile with provided fields
        updated_profile = user_helper.update_profile(
            user_id=token_user_id, **update_dict
        )

        logger.info(f"Successfully updated profile for user: {token_user_id}")
        return JSONResponse(
            content={
                "message": "Profile updated successfully",
                "user_profile": UserProfile.clean_returned_profile(updated_profile),
            },
            status_code=200,
        )

    except Exception as e:
        logger.error(f"Error updating profile for user {token_user_id}: {str(e)}")
        return JSONResponse(
            content={"error": "Failed to update profile"}, status_code=500
        )
