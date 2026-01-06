from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.family_membership_helper import FamilyMembershipHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


class ReviewMembershipRequest(BaseModel):
    target_user_id: str
    approve: bool


@router.put(
    "/{family_id}/review",
    summary="Review a family membership request (admin only)",
    response_description="The updated membership",
)
@exceptions_decorator
def review_family_membership(
    request: Request, family_id: str, body: ReviewMembershipRequest
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Admin reviewing membership request for user {body.target_user_id} in family {family_id}."
    )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = FamilyMembershipHelper(request_id=request.state.request_id)

    # This will raise AdminPrivilegesRequired if user is not an admin
    membership = helper.review_membership_request(
        family_id=family_id,
        admin_user_id=token_user_id,
        target_user_id=body.target_user_id,
        approve=body.approve,
    )

    return JSONResponse(
        content={"membership": membership},
        status_code=200,
    )
