from fastapi import APIRouter, Request, Path
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.family_helper import FamilyHelper
from models.family import FamilyModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}",
    summary="Get family details",
    response_description="The family details",
)
@exceptions_decorator
def get_family(request: Request, family_id: str = Path(..., description="Family ID")):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting family {family_id}.")

    helper = FamilyHelper(request_id=request.state.request_id)
    family = helper.get_family(family_id)

    if not family:
        return JSONResponse(
            content={"error": "Family not found"},
            status_code=404,
        )

    return JSONResponse(
        content={"family": FamilyModel.clean_returned_family(family)},
        status_code=200,
    )
