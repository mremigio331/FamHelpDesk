from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.queue_helper import QueueHelper
from helpers.queue_validation_helper import QueueValidationHelper, QueueNotFound
from models.queue import QueueModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/{group_id}/{queue_id}",
    summary="Get a single queue by ID",
    response_description="The queue details",
)
@exceptions_decorator
def get_queue(request: Request, family_id: str, group_id: str, queue_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting queue {queue_id}.")

    # Validate queue exists
    validation_helper = QueueValidationHelper(request_id=request.state.request_id)
    validation_helper.validate_queue_operation(
        family_id=family_id,
        group_id=group_id,
        queue_id=queue_id,
    )

    helper = QueueHelper(request_id=request.state.request_id)
    queue = helper.get_queue(family_id, group_id, queue_id)

    if queue is None:
        raise QueueNotFound(
            f"Queue {queue_id} not found in group {group_id} of family {family_id}."
        )

    return JSONResponse(
        content={"queue": QueueModel.clean_returned_queue(queue)},
        status_code=200,
    )
