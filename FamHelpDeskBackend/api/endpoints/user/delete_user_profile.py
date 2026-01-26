from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from exceptions.user_exceptions import (
    InvalidUserIdException,
    UserNotFound,
)
from decorators.exceptions_decorator import exceptions_decorator
from helpers.user_profile_helper import UserProfileHelper
from constants.services import API_SERVICE

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.delete(
    "/profile", summary="Delete a user profile", response_description="Deletion status"
)
@exceptions_decorator
def delete_user_profile(request: Request):
    """
    Delete User Profile Endpoint

    Allows users to delete their own profile. Users can only delete their own profiles.

    Returns:
        A JSON response indicating the deletion status.
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Processing request to delete user profile.")

    token_user_id = getattr(request.state, "user_token", None)

    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    user_helper = UserProfileHelper(request_id=request.state.request_id)
    user_profile = user_helper.get_profile(token_user_id)
    if not user_profile:
        logger.warning(f"User profile not found for user_id: {token_user_id}")
        raise UserNotFound(f"User profile with ID {token_user_id} does not exist.")

    try:
        user_helper.invoke_user_delete_lambda(user_id=token_user_id)
        return JSONResponse(
            status_code=200,
            content={
                "message": f"User profile deletion initiated for {token_user_id}."
            },
        )
    except Exception as e:
        logger.error(f"Error deleting user profile for user_id {token_user_id}: {e}")
        raise
