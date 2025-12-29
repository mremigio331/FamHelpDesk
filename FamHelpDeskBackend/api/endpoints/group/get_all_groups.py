from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.group_helper import GroupHelper
from models.group import GroupModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}",
    summary="Get all groups in a family",
    response_description="List of groups",
)
@exceptions_decorator
def get_all_groups(request: Request, family_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Getting all groups.")

    helper = GroupHelper(request_id=request.state.request_id)
    groups = helper.get_all_groups(family_id)

    return JSONResponse(
        content={"groups": [GroupModel.clean_returned_group(g) for g in groups]},
        status_code=200,
    )
