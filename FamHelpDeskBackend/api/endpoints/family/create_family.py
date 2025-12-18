from fastapi import APIRouter, Request
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


class CreateFamilyRequest(BaseModel):
    family_name: str
    family_description: Optional[str] = None


@router.post(
    "",
    summary="Create a family",
    response_description="The created family",
)
@exceptions_decorator
def create_family(request: Request, body: CreateFamilyRequest):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Creating family.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = FamilyHelper(request_id=request.state.request_id)
    family = helper.create_family(
        family_name=body.family_name,
        family_description=body.family_description,
        created_by=token_user_id,
    )

    return JSONResponse(
        content={"family": FamilyModel.clean_returned_family(family)},
        status_code=201,
    )
