from typing import List
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.family_helper import FamilyHelper
from helpers.family_membership_helper import FamilyMembershipHelper
from models.family import FamilyModel
from models.base import MembershipStatus

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/mine",
    summary="Get families for the requesting user",
    response_description="Dict keyed by family_id with membership and family info",
)
@exceptions_decorator
def get_my_families(request: Request):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Getting families for requesting user.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    membership_helper = FamilyMembershipHelper(request_id=request.state.request_id)
    memberships = membership_helper.get_all_memberships_by_user(token_user_id)
    # Include active members and pending requests
    included_statuses = {MembershipStatus.MEMBER.value, MembershipStatus.AWAITING.value}
    included_memberships = [m for m in memberships if m["status"] in included_statuses]
    member_family_ids = [m["family_id"] for m in included_memberships]

    # Index memberships by family_id for quick lookup
    membership_by_family = {m["family_id"]: m for m in included_memberships}

    family_helper = FamilyHelper(request_id=request.state.request_id)
    result = {}
    for fid in member_family_ids:
        family = family_helper.get_family(fid)
        if family:
            result[fid] = {
                "membership": membership_by_family.get(fid),
                "family": FamilyModel.clean_returned_family(family),
            }

    return JSONResponse(content={"families": result}, status_code=200)
