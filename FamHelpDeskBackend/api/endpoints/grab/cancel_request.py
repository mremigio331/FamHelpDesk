from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.grab_request_helper import GrabRequestHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.post(
    "/{family_id}/grab/requests/{request_id}/cancel",
    summary="Cancel a Grab Request",
    response_description="The cancelled Grab Request",
)
@exceptions_decorator
def cancel_request(request: Request, family_id: str, request_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Cancelling Grab Request {request_id} in family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = GrabRequestHelper(request_id=request.state.request_id)
    result = helper.cancel_request(family_id, request_id, token_user_id)

    response_content = {"request": result["request"]}
    if result.get("items"):
        response_content["items"] = result["items"]

    return JSONResponse(
        content=response_content,
        status_code=200,
    )
