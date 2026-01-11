from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.queue_helper import QueueHelper
from helpers.queue_validation_helper import QueueValidationHelper, QueueNotFound
from models.queue import QueueModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


class UpdateQueueRequest(BaseModel):
    family_id: str
    group_id: str
    queue_id: str
    queue_name: Optional[str] = None
    queue_description: Optional[str] = None


@router.post(
    "/update",
    summary="Update a queue",
    response_description="The updated queue",
)
@exceptions_decorator
def update_queue(request: Request, body: UpdateQueueRequest):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Updating queue {body.queue_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Validate queue data
    validation_helper = QueueValidationHelper(request_id=request.state.request_id)
    validation_helper.validate_update_queue_data(
        family_id=body.family_id,
        group_id=body.group_id,
        queue_id=body.queue_id,
        queue_name=body.queue_name,
        queue_description=body.queue_description,
    )

    helper = QueueHelper(request_id=request.state.request_id)
    queue = helper.update_queue(
        family_id=body.family_id,
        group_id=body.group_id,
        queue_id=body.queue_id,
        queue_name=body.queue_name,
        queue_description=body.queue_description,
        updated_by=token_user_id,
    )

    if queue is None:
        raise QueueNotFound(
            f"Queue {body.queue_id} not found in group {body.group_id} of family {body.family_id}."
        )

    return JSONResponse(
        content={"queue": QueueModel.clean_returned_queue(queue)},
        status_code=200,
    )
