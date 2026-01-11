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


class AddGroupMemberRequest(BaseModel):
    target_user_id: str
    make_admin: bool = False


@router.post(
    "/{family_id}/{group_id}/members",
    summary="Add a member directly to a group (admin only)",
    response_description="The created or updated membership",
)
@exceptions_decorator
def add_group_member(
    request: Request, family_id: str, group_id: str, body: AddGroupMemberRequest
):
    """
    Add Group Member

    Directly adds a user to a group without requiring a membership request.
    Only group admins can add members. The admin can optionally grant admin privileges
    to the new member.

    Args:
        family_id: The family ID containing the group
        group_id: The group ID to add the member to
        body: Request body containing target_user_id and optional make_admin flag

    Returns:
        A JSON response containing the created or updated membership
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Admin adding user {body.target_user_id} to group {group_id} in family {family_id} (admin={body.make_admin})."
    )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GroupMembershipHelper(request_id=request.state.request_id)

    # This will raise AdminPrivilegesRequired if user is not a group admin
    # and MemberPrivilegesRequired if user is not a group member
    membership = helper.grant_access(
        family_id=family_id,
        group_id=group_id,
        granter_user_id=token_user_id,
        target_user_id=body.target_user_id,
        make_admin=body.make_admin,
    )

    return JSONResponse(
        content={"membership": membership},
        status_code=201,
    )
