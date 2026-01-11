from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from exceptions.queue_exceptions import QueueHasActiveTickets
from helpers.queue_helper import QueueHelper
from helpers.queue_validation_helper import QueueValidationHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.delete(
    "/{family_id}/{group_id}/{queue_id}",
    summary="Delete a queue",
    response_description="Confirmation of queue deletion",
)
@exceptions_decorator
def delete_queue(request: Request, family_id: str, group_id: str, queue_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Deleting queue {queue_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required")

    # Validate queue exists and relationships
    validation_helper = QueueValidationHelper(request_id=request.state.request_id)
    validation_helper.validate_queue_operation(
        family_id=family_id,
        group_id=group_id,
        queue_id=queue_id,
    )

    helper = QueueHelper(request_id=request.state.request_id)

    # Check if queue has active tickets before deletion
    # This should be implemented in the queue helper
    # For now, we'll let the helper handle this validation

    success = helper.delete_queue(
        family_id=family_id,
        group_id=group_id,
        queue_id=queue_id,
        deleted_by=token_user_id,
    )

    if not success:
        # This could happen if queue has active tickets or other business rules
        logger.error(f"Queue deletion failed for queue {queue_id}")
        raise QueueHasActiveTickets(
            f"Cannot delete queue {queue_id} - it may have active tickets"
        )

    return JSONResponse(
        content={"message": f"Queue {queue_id} deleted successfully"},
        status_code=200,
    )
