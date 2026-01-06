from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.family_membership_helper import FamilyMembershipHelper
from helpers.user_profile_helper import UserProfileHelper
from models.user_profile import UserProfile

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/requests",
    summary="Get pending membership requests for a family",
    response_description="List of pending membership requests with user details",
)
@exceptions_decorator
def get_family_membership_requests(request: Request, family_id: str):
    """
    Get Pending Membership Requests for Family

    Returns all pending membership requests for the specified family.
    Each request includes the user's display name and email.

    Args:
        family_id: The family ID to get requests for

    Returns:
        A JSON response containing a list of membership requests with user details
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting pending membership requests for family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Get pending membership requests
    membership_helper = FamilyMembershipHelper(request_id=request.state.request_id)
    pending_requests = membership_helper.get_pending_membership_requests(family_id)

    # Enrich with user profile information
    user_profile_helper = UserProfileHelper(request_id=request.state.request_id)
    enriched_requests = []

    for membership in pending_requests:
        user_id = membership.get("user_id")
        user_profile_model = user_profile_helper.get_profile(user_id)
        user_profile = (
            UserProfile.clean_returned_profile(user_profile_model)
            if user_profile_model
            else None
        )

        enriched_request = {
            **membership,
            "user_display_name": (
                user_profile.get("display_name") if user_profile else None
            ),
            "user_email": user_profile.get("email") if user_profile else None,
        }
        enriched_requests.append(enriched_request)

    logger.info(
        f"Found {len(enriched_requests)} pending requests for family {family_id}."
    )

    return JSONResponse(
        content={
            "requests": enriched_requests,
            "count": len(enriched_requests),
        },
        status_code=200,
    )
