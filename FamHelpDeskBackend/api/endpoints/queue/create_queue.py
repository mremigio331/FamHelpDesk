from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.queue_helper import QueueHelper
from helpers.queue_validation_helper import QueueValidationHelper
from models.queue import QueueModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


class CreateQueueRequest(BaseModel):
    family_id: str
    group_id: str
    queue_name: str
    queue_description: Optional[str] = None


@router.post(
    "/create",
    summary="Create a queue",
    response_description="The created queue",
)
@exceptions_decorator
def create_queue(request: Request, body: CreateQueueRequest):
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Creating queue.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Validate queue data
    validation_helper = QueueValidationHelper(request_id=request.state.request_id)
    validation_helper.validate_create_queue_data(
        family_id=body.family_id,
        group_id=body.group_id,
        queue_name=body.queue_name,
        queue_description=body.queue_description,
    )

    helper = QueueHelper(request_id=request.state.request_id)
    queue = helper.create_queue(
        family_id=body.family_id,
        group_id=body.group_id,
        queue_name=body.queue_name,
        queue_description=body.queue_description,
        created_by=token_user_id,
    )

    return JSONResponse(
        content={"queue": QueueModel.clean_returned_queue(queue)},
        status_code=201,
    )
