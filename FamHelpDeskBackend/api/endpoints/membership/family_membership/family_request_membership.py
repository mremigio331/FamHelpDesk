from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.family_membership_helper import FamilyMembershipHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.post(
    "/{family_id}/request",
    summary="Request membership to a family",
    response_description="The created membership request",
)
@exceptions_decorator
def request_family_membership(request: Request, family_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"User requesting membership to family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = FamilyMembershipHelper(request_id=request.state.request_id)
    membership = helper.create_membership_request(
        family_id=family_id,
        user_id=token_user_id,
    )

    return JSONResponse(
        content={"membership": membership},
        status_code=201,
    )
