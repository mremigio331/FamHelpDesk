from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from typing import Optional
import json
import base64

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.embolec_helper import EmbolecHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/grab/transactions",
    summary="List Embolec transactions for the family",
    response_description="Paginated list of transactions",
)
@exceptions_decorator
def get_transactions(
    request: Request,
    family_id: str,
    limit: int = Query(20, description="Page size (max 50)"),
    last_key: Optional[str] = Query(None, description="Pagination cursor"),
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Getting transactions for family {family_id}.")

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Decode last_key if provided
    decoded_last_key = None
    if last_key:
        try:
            decoded = base64.b64decode(last_key).decode("utf-8")
            decoded_last_key = json.loads(decoded)
        except Exception as e:
            logger.warning(f"Invalid last_key provided: {str(e)}")
            return JSONResponse(
                content={
                    "error": {
                        "code": "INVALID_PAGINATION_TOKEN",
                        "message": "Invalid pagination token",
                    }
                },
                status_code=400,
            )

    helper = EmbolecHelper(request_id=request.state.request_id)
    result = helper.get_transactions(
        family_id=family_id,
        limit=limit,
        last_key=decoded_last_key,
    )

    # Encode last_key for response
    response_last_key = None
    if result.get("last_key"):
        encoded = base64.b64encode(
            json.dumps(result["last_key"]).encode("utf-8")
        ).decode("utf-8")
        response_last_key = encoded

    return JSONResponse(
        content={
            "transactions": result["transactions"],
            "last_key": response_last_key,
        },
        status_code=200,
    )
