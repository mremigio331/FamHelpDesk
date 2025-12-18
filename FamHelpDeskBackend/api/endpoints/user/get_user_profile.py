from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from exceptions.user_exceptions import (
    UserNotFound,
)
from decorators.exceptions_decorator import exceptions_decorator
from helpers.jwt import decode_jwt
from helpers.user_profile_helper import UserProfileHelper
from models.user_profile import UserProfile
from constants.services import API_SERVICE

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/profile/{user_id}",
    summary="Get a user profile",
    response_description="The user's profile",
)
@exceptions_decorator
def get_user_profile(request: Request, user_id: str):
    """
    Get User Profile Endpoint
    Returns:
        A JSON response containing the user's profile information.
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Getting request for user profile.")

    user_helper = UserProfileHelper(request_id=request.state.request_id)
    user_profile = user_helper.get_profile(user_id=user_id)
    if not user_profile:
        logger.warning(f"User profile not found for user_id: {user_id}")
        raise UserNotFound(f"User with ID {user_id} not found.")

    return JSONResponse(
        content={"user_profile": UserProfile.clean_returned_profile(user_profile)},
        status_code=200,
    )
