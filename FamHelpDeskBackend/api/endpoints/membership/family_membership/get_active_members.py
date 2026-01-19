from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.family_membership_helper import FamilyMembershipHelper
from helpers.entity_ref import EntityRefHelper, EntityRef

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/active-members",
    summary="Get all active members for a family (for ticket assignment)",
    response_description="List of all active members with EntityRef format for ticket assignment",
)
@exceptions_decorator
def get_active_members(request: Request, family_id: str):
    """
    Get All Active Members for Family (Optimized for Ticket Assignment)

    Returns all active members for the specified family in EntityRef format.
    This endpoint is optimized for ticket assignment use cases where you need
    user IDs and display names.

    Args:
        family_id: The family ID to get active members for

    Returns:
        A JSON response containing a list of active members with user_id and display_name
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting active members for family {family_id} for ticket assignment.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Get all active members
    membership_helper = FamilyMembershipHelper(request_id=request.state.request_id)
    members = membership_helper.get_all_members(family_id)

    # Convert to EntityRef format and enrich with user names
    member_refs = []
    for membership in members:
        user_id = membership.get("user_id")
        if user_id:
            # Create EntityRef for the user
            member_ref = EntityRef(id=user_id, name=None)
            member_refs.append(member_ref)

    # Enrich all member references with user names in one batch
    enriched_refs = EntityRefHelper.enrich_entity_refs(member_refs)

    # Convert to the expected format for the API response
    enriched_members = []
    for ref_dict in enriched_refs:
        enriched_members.append(
            {"user_id": ref_dict["id"], "display_name": ref_dict["name"]}
        )

    logger.info(f"Found {len(enriched_members)} active members in family {family_id}.")

    return JSONResponse(
        content={
            "members": enriched_members,
            "count": len(enriched_members),
        },
        status_code=200,
    )
