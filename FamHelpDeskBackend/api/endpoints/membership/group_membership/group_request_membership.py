from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.group_membership_helper import GroupMembershipHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.post(
    "/{family_id}/{group_id}/request",
    summary="Request membership to a group",
    response_description="The created membership request",
)
@exceptions_decorator
def request_group_membership(request: Request, family_id: str, group_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"User requesting membership to group {group_id} in family {family_id}."
    )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GroupMembershipHelper(request_id=request.state.request_id)
    membership = helper.create_membership_request(
        family_id=family_id,
        group_id=group_id,
        user_id=token_user_id,
    )

    return JSONResponse(
        content={"membership": membership},
        status_code=201,
    )
