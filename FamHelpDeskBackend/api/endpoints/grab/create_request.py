from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel, validator
from typing import Optional, List

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.grab_request_helper import GrabRequestHelper
from helpers.entity_ref import EntityRefHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


class GrabRequestItemInput(BaseModel):
    name: str
    embolec_cost: float
    quantity: Optional[int] = 1
    note: Optional[str] = None

    @validator("name")
    def validate_name_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("Item name cannot be empty")
        return v.strip()

    @validator("embolec_cost")
    def validate_item_cost_positive(cls, v):
        if v < 1:
            raise ValueError("Item cost must be at least 1 Embolec")
        return v


class CreateGrabRequestBody(BaseModel):
    title: str
    items: List[GrabRequestItemInput]
    note: Optional[str] = None

    @validator("title")
    def validate_title_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError("Title cannot be empty")
        return v.strip()

    @validator("items")
    def validate_items_not_empty(cls, v):
        if not v or len(v) == 0:
            raise ValueError("At least one item is required")
        # Ensure at least one item has a cost > 0
        total_cost = sum(item.embolec_cost for item in v)
        if total_cost < 1:
            raise ValueError("Total cost must be at least 1 Embolec")
        return v


@router.post(
    "/{family_id}/grab/requests",
    summary="Create a new Grab Request",
    response_description="The created Grab Request with items",
)
@exceptions_decorator
def create_request(request: Request, family_id: str, body: CreateGrabRequestBody):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Creating Grab Request in family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GrabRequestHelper(request_id=request.state.request_id)
    result = helper.create_request(
        family_id=family_id,
        requestor_id=token_user_id,
        title=body.title,
        items=[item.dict() for item in body.items],
        note=body.note,
    )

    return JSONResponse(
        content=EntityRefHelper.enrich_entity_refs(
            {"request": result["request"], "items": result["items"]}
        ),
        status_code=201,
    )
