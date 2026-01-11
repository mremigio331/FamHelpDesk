from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.group_membership_helper import GroupMembershipHelper
from helpers.user_profile_helper import UserProfileHelper
from models.user_profile import UserProfile

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/{group_id}/members/roles",
    summary="Get all group members with their roles",
    response_description="List of all active members with user details and explicit role information",
)
@exceptions_decorator
def get_group_members_with_roles(request: Request, family_id: str, group_id: str):
    """
    Get Group Members with Roles

    Returns all active members for the specified group within a family.
    Each member includes the user's display name, email, and explicit role information
    (admin or member) for easy role management.

    Args:
        family_id: The family ID containing the group
        group_id: The group ID to get members for

    Returns:
        A JSON response containing a list of members with user details and explicit roles
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Getting all members with roles for group {group_id} in family {family_id}."
    )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Get all active members
    membership_helper = GroupMembershipHelper(request_id=request.state.request_id)
    members = membership_helper.get_all_members(family_id, group_id)

    # Enrich with user profile information and explicit role information
    user_profile_helper = UserProfileHelper(request_id=request.state.request_id)
    enriched_members = []

    for membership in members:
        user_id = membership.get("user_id")
        user_profile_model = user_profile_helper.get_profile(user_id)
        user_profile = (
            UserProfile.clean_returned_profile(user_profile_model)
            if user_profile_model
            else None
        )

        # Determine explicit role
        is_admin = membership.get("is_admin", False)
        role = "admin" if is_admin else "member"

        enriched_member = {
            **membership,
            "user_display_name": (
                user_profile.get("display_name") if user_profile else None
            ),
            "user_email": user_profile.get("email") if user_profile else None,
            "role": role,  # Explicit role field for easier frontend consumption
        }
        enriched_members.append(enriched_member)

    # Sort members by role (admins first) then by display name
    enriched_members.sort(
        key=lambda x: (
            not x.get("is_admin", False),  # Admins first (False sorts before True)
            x.get("user_display_name", "").lower(),  # Then alphabetically by name
        )
    )

    logger.info(
        f"Found {len(enriched_members)} members with roles in group {group_id} of family {family_id}."
    )

    # Count admins and regular members
    admin_count = sum(1 for member in enriched_members if member.get("is_admin", False))
    member_count = len(enriched_members) - admin_count

    return JSONResponse(
        content={
            "members": enriched_members,
            "count": len(enriched_members),
            "admin_count": admin_count,
            "member_count": member_count,
        },
        status_code=200,
    )
