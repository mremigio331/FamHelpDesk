from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from exceptions.group_exceptions import InvalidGroupData
from helpers.group_helper import GroupHelper
from helpers.group_validation_helper import GroupValidationHelper
from models.group import GroupModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


class UpdateGroupRequest(BaseModel):
    family_id: str
    group_id: str
    group_name: Optional[str] = None
    group_description: Optional[str] = None


@router.put(
    "/edit",
    summary="Update group details",
    response_description="The updated group",
)
@exceptions_decorator
def update_group(request: Request, body: UpdateGroupRequest):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Updating group {body.group_id} in family {body.family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Build kwargs from non-None fields
    update_kwargs = {}
    if body.group_name is not None:
        update_kwargs["group_name"] = body.group_name
    if body.group_description is not None:
        update_kwargs["group_description"] = body.group_description

    if not update_kwargs:
        raise InvalidGroupData("No fields to update provided")

    # Validate group data
    validation_helper = GroupValidationHelper(request_id=request.state.request_id)
    validation_helper.validate_update_group_data(
        family_id=body.family_id,
        group_id=body.group_id,
        group_name=body.group_name,
        group_description=body.group_description,
    )

    helper = GroupHelper(request_id=request.state.request_id)
    group = helper.update_group(
        family_id=body.family_id,
        group_id=body.group_id,
        actor_user_id=token_user_id,
        **update_kwargs,
    )

    return JSONResponse(
        content={"group": GroupModel.clean_returned_group(group)},
        status_code=200,
    )
