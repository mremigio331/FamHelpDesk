from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.grab_request_helper import GrabRequestHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


class CompleteRequestBody(BaseModel):
    proof_photo_key: Optional[str] = None


@router.post(
    "/{family_id}/grab/requests/{request_id}/complete",
    summary="Mark all items claimed by user as completed",
    response_description="The completed items",
)
@exceptions_decorator
def complete_request(
    request: Request,
    family_id: str,
    request_id: str,
    body: CompleteRequestBody = CompleteRequestBody(),
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Completing Grab Request {request_id} in family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GrabRequestHelper(request_id=request.state.request_id)

    # Find all items claimed by this user with status CLAIMED
    items = helper._get_request_item_models(family_id, request_id)
    user_claimed_item_ids = [
        item.item_id
        for item in items
        if item.status == "CLAIMED"
        and getattr(item, "claimer_id", None) == token_user_id
    ]

    if not user_claimed_item_ids:
        return JSONResponse(
            content={"items": []},
            status_code=200,
        )

    result = helper.complete_items(
        family_id,
        request_id,
        token_user_id,
        user_claimed_item_ids,
        body.proof_photo_key,
    )

    return JSONResponse(
        content={"items": result["items"]},
        status_code=200,
    )
