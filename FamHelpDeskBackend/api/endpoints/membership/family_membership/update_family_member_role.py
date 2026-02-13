from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from exceptions.membership_exceptions import (
    MembershipNotFound,
    AdminPrivilegesRequired,
    MemberPrivilegesRequired,
)
from helpers.family_membership_helper import FamilyMembershipHelper
from models.base import MembershipStatus

logger = Logger(service=API_SERVICE)
router = APIRouter()


class UpdateFamilyMemberRoleRequest(BaseModel):
    target_user_id: str
    is_admin: bool


@router.put(
    "/{family_id}/members/role",
    summary="Update a family member's role (admin only)",
    response_description="The updated membership with new role",
)
@exceptions_decorator
def update_family_member_role(
    request: Request, family_id: str, body: UpdateFamilyMemberRoleRequest
):
    """
    Update Family Member Role

    Updates a family member's role (admin/member). Only family admins can change member roles.
    Admins can promote members to admin or demote admins to regular members.

    Args:
        family_id: The family ID containing the member
        body: Request body containing target_user_id and new is_admin status

    Returns:
        A JSON response containing the updated membership with new role
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Updating role for user {body.target_user_id} in family {family_id} to admin={body.is_admin}."
    )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = FamilyMembershipHelper(request_id=request.state.request_id)

    # Verify the requesting user is an admin of this family
    requesting_user_membership = helper.get_membership(family_id, token_user_id)

    if not requesting_user_membership:
        raise MemberPrivilegesRequired()

    if requesting_user_membership.get(
        "status"
    ) != MembershipStatus.MEMBER.value or not requesting_user_membership.get(
        "is_admin", False
    ):
        raise AdminPrivilegesRequired()

    # Get the target user's membership
    target_membership = helper.get_membership(family_id, body.target_user_id)

    if not target_membership:
        raise MembershipNotFound()

    if target_membership.get("status") != MembershipStatus.MEMBER.value:
        raise MembershipNotFound()

    # Update the role using the new update_member_role method
    updated_membership = helper.update_member_role(
        family_id=family_id,
        admin_user_id=token_user_id,
        target_user_id=body.target_user_id,
        is_admin=body.is_admin,
    )

    logger.info(
        f"Successfully updated role for user {body.target_user_id} in family {family_id} to admin={body.is_admin}."
    )

    return JSONResponse(
        content={"membership": updated_membership},
        status_code=200,
    )
