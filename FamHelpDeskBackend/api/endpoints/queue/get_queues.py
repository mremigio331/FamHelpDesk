from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from helpers.queue_helper import QueueHelper
from helpers.queue_validation_helper import QueueValidationHelper
from models.queue import QueueModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/groups/{group_id}",
    summary="Get all queues in a group",
    response_description="List of queues",
)
@exceptions_decorator
def get_queues(request: Request, family_id: str, group_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting queues for group {group_id} in family {family_id}.")

    # Validate family and group exist
    validation_helper = QueueValidationHelper(request_id=request.state.request_id)
    validation_helper.validate_family_exists(family_id)
    validation_helper.validate_group_exists(family_id, group_id)

    helper = QueueHelper(request_id=request.state.request_id)
    queues = helper.get_all_queues_by_group(family_id, group_id)

    return JSONResponse(
        content={"queues": [QueueModel.clean_returned_queue(q) for q in queues]},
        status_code=200,
    )
