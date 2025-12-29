from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.group_helper import GroupHelper
from models.group import GroupModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


class CreateGroupRequest(BaseModel):
    family_id: str
    group_name: str
    group_description: Optional[str] = None


@router.post(
    "",
    summary="Create a group",
    response_description="The created group",
)
@exceptions_decorator
def create_group(request: Request, body: CreateGroupRequest):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Creating group.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GroupHelper(request_id=request.state.request_id)
    group = helper.create_group(
        family_id=body.family_id,
        group_name=body.group_name,
        group_description=body.group_description,
        created_by=token_user_id,
    )

    return JSONResponse(
        content={"group": GroupModel.clean_returned_group(group)},
        status_code=201,
    )
