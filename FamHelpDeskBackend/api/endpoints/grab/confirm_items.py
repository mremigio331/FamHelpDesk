from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel, Field
from typing import List, Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.grab_request_helper import GrabRequestHelper
from helpers.entity_ref import EntityRefHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


class ItemRating(BaseModel):
    item_id: str
    star_rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = Field(None, max_length=500)


class ConfirmItemsBody(BaseModel):
    item_ids: List[str]
    tip_amount: Optional[float] = None
    item_ratings: Optional[List[ItemRating]] = None


@router.post(
    "/{family_id}/grab/requests/{request_id}/confirm-items",
    summary="Confirm delivery of specific items",
    response_description="The confirmed items with transactions",
)
@exceptions_decorator
def confirm_items(
    request: Request,
    family_id: str,
    request_id: str,
    body: ConfirmItemsBody,
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Confirming items in Grab Request {request_id} in family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Convert item_ratings Pydantic models to list of dicts for the helper
    item_ratings_dicts = None
    if body.item_ratings:
        item_ratings_dicts = [rating.model_dump() for rating in body.item_ratings]

    helper = GrabRequestHelper(request_id=request.state.request_id)
    result = helper.confirm_items(
        family_id=family_id,
        request_id=request_id,
        user_id=token_user_id,
        item_ids=body.item_ids,
        tip_amount=body.tip_amount,
        item_ratings=item_ratings_dicts,
    )

    response_content = {
        "items": result["items"],
        "transactions": result["transactions"],
    }
    if result.get("reviews"):
        response_content["reviews"] = result["reviews"]

    return JSONResponse(
        content=EntityRefHelper.enrich_entity_refs(response_content),
        status_code=200,
    )
