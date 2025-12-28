from fastapi import APIRouter, Request, Path
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.family_helper import FamilyHelper
from models.family import FamilyModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


class UpdateFamilyRequest(BaseModel):
    family_name: Optional[str] = None
    family_description: Optional[str] = None


@router.put(
    "/{family_id}",
    summary="Update family details",
    response_description="The updated family",
)
@exceptions_decorator
def update_family(
    request: Request,
    body: UpdateFamilyRequest,
    family_id: str = Path(..., description="Family ID"),
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Updating family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = FamilyHelper(request_id=request.state.request_id)

    # Build kwargs from non-None fields
    update_kwargs = {}
    if body.family_name is not None:
        update_kwargs["family_name"] = body.family_name
    if body.family_description is not None:
        update_kwargs["family_description"] = body.family_description

    if not update_kwargs:
        return JSONResponse(
            content={"error": "No fields to update provided"},
            status_code=400,
        )

    try:
        family = helper.update_family(
            family_id=family_id,
            actor_user_id=token_user_id,
            **update_kwargs,
        )

        return JSONResponse(
            content={"family": FamilyModel.clean_returned_family(family)},
            status_code=200,
        )
    except ValueError as e:
        return JSONResponse(
            content={"error": str(e)},
            status_code=404,
        )
