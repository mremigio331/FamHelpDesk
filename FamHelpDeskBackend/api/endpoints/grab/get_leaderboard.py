from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.grab_leaderboard_helper import GrabLeaderboardHelper
from helpers.entity_ref import EntityRef, EntityRefHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/grab/leaderboard",
    summary="Get family leaderboard",
    response_description="Leaderboard ranked by total earned",
)
@exceptions_decorator
def get_leaderboard(request: Request, family_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting leaderboard for family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GrabLeaderboardHelper(request_id=request.state.request_id)
    result = helper.get_leaderboard(family_id)

    # Enrich user_id fields with display names
    for entry in result["leaderboard"]:
        entry["user_id"] = EntityRef(id=entry["user_id"])

    enriched = EntityRefHelper.enrich_entity_refs(result["leaderboard"])

    return JSONResponse(
        content={"leaderboard": enriched},
        status_code=200,
    )
