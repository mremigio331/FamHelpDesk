import json
from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.grab_review_helper import GrabReviewHelper
from helpers.family_membership_helper import FamilyMembershipHelper
from models.base import MembershipStatus

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/grab/reviews/{user_id}",
    summary="Get review profile for a user in a family",
    response_description="The user's review profile with paginated reviews",
)
@exceptions_decorator
def get_review_profile(
    request: Request,
    family_id: str,
    user_id: str,
    limit: int = Query(default=20, ge=1, le=100),
    last_key: Optional[str] = Query(default=None),
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting review profile for user {user_id} in family {family_id}.")

    # Extract token_user_id from request state
    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Verify the requesting user belongs to the family
    membership_helper = FamilyMembershipHelper(request_id=request.state.request_id)
    membership = membership_helper.get_membership(family_id, token_user_id)
    if not membership or membership.get("status") != MembershipStatus.MEMBER.value:
        logger.warning(f"User {token_user_id} is not a member of family {family_id}.")
        return JSONResponse(
            content={"detail": "Not authorized to view reviews in this family"},
            status_code=403,
        )

    # Parse last_key from JSON string if provided
    parsed_last_key = None
    if last_key:
        try:
            parsed_last_key = json.loads(last_key)
        except (json.JSONDecodeError, TypeError):
            parsed_last_key = None

    helper = GrabReviewHelper()
    profile = helper.get_review_profile(
        family_id, user_id, limit=limit, last_key=parsed_last_key
    )

    return JSONResponse(
        content=profile,
        status_code=200,
    )
