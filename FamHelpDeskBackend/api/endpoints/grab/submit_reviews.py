from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel, Field
from typing import Optional, List

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.grab_review_helper import GrabReviewHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


class ItemRating(BaseModel):
    item_id: str
    star_rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = Field(None, max_length=500)


class SubmitReviewsBody(BaseModel):
    item_ratings: List[ItemRating] = Field(..., min_length=1)


@router.post(
    "/{family_id}/grab/requests/{request_id}/reviews",
    summary="Submit or update reviews for a Grab Request within the 48-hour grace window",
    response_description="The created or updated reviews",
)
@exceptions_decorator
def submit_reviews(
    request: Request,
    family_id: str,
    request_id: str,
    body: SubmitReviewsBody,
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Submitting late reviews for Grab Request {request_id} in family {family_id}."
    )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Convert item_ratings Pydantic models to list of dicts for the helper
    item_ratings_dicts = [rating.model_dump() for rating in body.item_ratings]

    helper = GrabReviewHelper()
    reviews = helper.submit_late_reviews(
        family_id, request_id, token_user_id, item_ratings_dicts
    )

    return JSONResponse(
        content={"reviews": reviews},
        status_code=200,
    )
