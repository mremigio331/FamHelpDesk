from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel
from typing import List, Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.grab_request_helper import GrabRequestHelper
from helpers.entity_ref import EntityRefHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


class CompleteItemsBody(BaseModel):
    item_ids: List[str]
    proof_photo_key: Optional[str] = None
    photo_visibility: Optional[str] = None


@router.post(
    "/{family_id}/grab/requests/{request_id}/complete-items",
    summary="Mark specific items as completed",
    response_description="The completed items",
)
@exceptions_decorator
def complete_items(
    request: Request,
    family_id: str,
    request_id: str,
    body: CompleteItemsBody,
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Completing items in Grab Request {request_id} in family {family_id}.")

    if body.photo_visibility is not None and body.photo_visibility not in {
        "public",
        "private",
    }:
        raise HTTPException(
            status_code=422,
            detail="photo_visibility must be 'public' or 'private'",
        )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GrabRequestHelper(request_id=request.state.request_id)
    result = helper.complete_items(
        family_id,
        request_id,
        token_user_id,
        body.item_ids,
        body.proof_photo_key,
        photo_visibility=body.photo_visibility,
    )

    return JSONResponse(
        content=EntityRefHelper.enrich_entity_refs({"items": result["items"]}),
        status_code=200,
    )
