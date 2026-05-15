from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.embolec_helper import EmbolecHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/grab/balance",
    summary="Get current user's Embolec balance",
    response_description="The user's Embolec balance",
)
@exceptions_decorator
def get_balance(request: Request, family_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting Embolec balance for family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    helper = EmbolecHelper(request_id=request.state.request_id)
    try:
        balance = helper.get_or_create_balance(family_id, token_user_id)
    except Exception as e:
        logger.error(f"Error in get_balance: {type(e).__name__}: {str(e)}")
        raise

    return JSONResponse(
        content={"balance": balance},
        status_code=200,
    )
