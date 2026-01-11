from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from exceptions.membership_exceptions import (
    MemberPrivilegesRequired,
    AdminPrivilegesRequired,
)
from helpers.group_membership_helper import GroupMembershipHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.delete(
    "/{family_id}/{group_id}/members/{target_user_id}",
    summary="Remove a member from a group",
    response_description="The removed membership",
)
@exceptions_decorator
def remove_group_member(
    request: Request, family_id: str, group_id: str, target_user_id: str
):
    """
    Remove Group Member

    Removes a user from a group. Only group admins can remove other members,
    or members can remove themselves from the group.

    Args:
        family_id: The family ID containing the group
        group_id: The group ID to remove the member from
        target_user_id: The user ID to remove from the group

    Returns:
        A JSON response containing the removed membership details
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Removing user {target_user_id} from group {group_id} in family {family_id}."
    )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GroupMembershipHelper(request_id=request.state.request_id)

    # Check if the requesting user is either:
    # 1. The target user themselves (self-removal)
    # 2. An admin of the group
    if token_user_id == target_user_id:
        # Self-removal - user can remove themselves
        logger.info(f"User {token_user_id} removing themselves from group {group_id}.")
        membership = helper.delete_membership(
            family_id=family_id,
            group_id=group_id,
            user_id=target_user_id,
            actor_user_id=token_user_id,
        )
    else:
        # Admin removal - need to verify admin privileges
        # First check if the requesting user is an admin
        requesting_user_membership = helper.get_membership(
            family_id, group_id, token_user_id
        )

        if not requesting_user_membership:
            raise MemberPrivilegesRequired()

        if requesting_user_membership.get(
            "status"
        ) != "MEMBER" or not requesting_user_membership.get("is_admin", False):
            raise AdminPrivilegesRequired()

        logger.info(
            f"Admin {token_user_id} removing user {target_user_id} from group {group_id}."
        )
        membership = helper.delete_membership(
            family_id=family_id,
            group_id=group_id,
            user_id=target_user_id,
            actor_user_id=token_user_id,
        )

    return JSONResponse(
        content={"membership": membership},
        status_code=200,
    )
