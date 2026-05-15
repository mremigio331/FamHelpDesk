from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel
from typing import List

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.grab_request_helper import GrabRequestHelper
from helpers.entity_ref import EntityRefHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


class ClaimItemsBody(BaseModel):
    item_ids: List[str]


@router.post(
    "/{family_id}/grab/requests/{request_id}/claim-items",
    summary="Claim specific items within a Grab Request",
    response_description="The claimed items",
)
@exceptions_decorator
def claim_items(
    request: Request,
    family_id: str,
    request_id: str,
    body: ClaimItemsBody,
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Claiming items in Grab Request {request_id} in family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GrabRequestHelper(request_id=request.state.request_id)
    result = helper.claim_items(family_id, request_id, token_user_id, body.item_ids)

    return JSONResponse(
        content=EntityRefHelper.enrich_entity_refs({"items": result["items"]}),
        status_code=200,
    )
