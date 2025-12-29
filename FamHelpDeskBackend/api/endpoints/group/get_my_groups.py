from typing import List
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.group_helper import GroupHelper
from helpers.group_membership_helper import GroupMembershipHelper
from models.group import GroupModel
from models.base import MembershipStatus

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/mine",
    summary="Get groups for the requesting user",
    response_description="Dict keyed by group_id with membership and group info",
)
@exceptions_decorator
def get_my_groups(request: Request):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Getting groups for requesting user.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    membership_helper = GroupMembershipHelper(request_id=request.state.request_id)
    memberships = membership_helper.get_all_memberships_by_user(token_user_id)
    included_statuses = {MembershipStatus.MEMBER.value, MembershipStatus.AWAITING.value}
    included_memberships = [m for m in memberships if m["status"] in included_statuses]
    group_keys = [(m["family_id"], m["group_id"]) for m in included_memberships]

    membership_by_group = {
        (m["family_id"], m["group_id"]): m for m in included_memberships
    }

    group_helper = GroupHelper(request_id=request.state.request_id)
    result = {}
    for family_id, group_id in group_keys:
        group = group_helper.get_group(family_id, group_id)
        if group:
            result[group_id] = {
                "membership": membership_by_group.get((family_id, group_id)),
                "group": GroupModel.clean_returned_group(group),
            }

    return JSONResponse(content={"groups": result}, status_code=200)
