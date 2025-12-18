from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.family_helper import FamilyHelper
from models.family import FamilyModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "",
    summary="Get all families",
    response_description="List of families",
)
@exceptions_decorator
def get_all_families(request: Request):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Getting all families.")

    helper = FamilyHelper(request_id=request.state.request_id)
    families = helper.get_all_families()

    return JSONResponse(
        content={"families": [FamilyModel.clean_returned_family(f) for f in families]},
        status_code=200,
    )
