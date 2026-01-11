from fastapi import APIRouter, Request, Path
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.group_helper import GroupHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.delete(
    "/{family_id}/{group_id}",
    summary="Delete a group",
    response_description="Confirmation of group deletion",
)
@exceptions_decorator
def delete_group(
    request: Request,
    family_id: str = Path(..., description="Family ID"),
    group_id: str = Path(..., description="Group ID"),
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Deleting group {group_id} from family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GroupHelper(request_id=request.state.request_id)

    try:
        success = helper.delete_group(
            family_id=family_id,
            group_id=group_id,
            actor_user_id=token_user_id,
        )

        if success:
            return JSONResponse(
                content={"message": "Group deleted successfully"},
                status_code=200,
            )
        else:
            return JSONResponse(
                content={"error": "Failed to delete group"},
                status_code=500,
            )
    except ValueError as e:
        return JSONResponse(
            content={"error": str(e)},
            status_code=400,
        )
