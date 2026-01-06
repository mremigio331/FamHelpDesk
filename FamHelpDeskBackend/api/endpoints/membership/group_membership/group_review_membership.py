from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.group_membership_helper import GroupMembershipHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


class ReviewMembershipRequest(BaseModel):
    target_user_id: str
    approve: bool


@router.put(
    "/{family_id}/{group_id}/review",
    summary="Review a group membership request (admin only)",
    response_description="The updated membership",
)
@exceptions_decorator
def review_group_membership(
    request: Request, family_id: str, group_id: str, body: ReviewMembershipRequest
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Admin reviewing membership request for user {body.target_user_id} in group {group_id}."
    )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GroupMembershipHelper(request_id=request.state.request_id)

    # This will raise AdminPrivilegesRequired if user is not a group admin
    membership = helper.review_membership_request(
        family_id=family_id,
        group_id=group_id,
        admin_user_id=token_user_id,
        target_user_id=body.target_user_id,
        approve=body.approve,
    )

    return JSONResponse(
        content={"membership": membership},
        status_code=200,
    )
