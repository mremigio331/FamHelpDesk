from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.grab_request_helper import GrabRequestHelper
from helpers.entity_ref import EntityRefHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/grab/requests/{request_id}",
    summary="Get a specific Grab Request with items",
    response_description="The Grab Request details with items",
)
@exceptions_decorator
def get_request(request: Request, family_id: str, request_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting Grab Request {request_id} in family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GrabRequestHelper(request_id=request.state.request_id)
    result = helper.get_request(family_id, request_id)

    content = {"request": result["request"], "items": result["items"]}
    if "reviews" in result:
        content["reviews"] = result["reviews"]

    enriched_content = EntityRefHelper.enrich_entity_refs(content)

    return JSONResponse(
        content=enriched_content,
        status_code=200,
    )
