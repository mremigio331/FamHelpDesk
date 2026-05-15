from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from typing import Optional
import json
import base64

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from helpers.grab_request_helper import GrabRequestHelper
from helpers.entity_ref import EntityRefHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/grab/requests",
    summary="List Grab Requests with filters and pagination",
    response_description="Paginated list of Grab Requests",
)
@exceptions_decorator
def list_requests(
    request: Request,
    family_id: str,
    status: Optional[str] = Query(None, description="Filter by status"),
    user_role: Optional[str] = Query(
        None, description="Filter by user role (requestor or claimer)"
    ),
    start_date: Optional[int] = Query(None, description="Filter by start date (epoch)"),
    end_date: Optional[int] = Query(None, description="Filter by end date (epoch)"),
    limit: int = Query(20, description="Page size (max 50)"),
    last_key: Optional[str] = Query(None, description="Pagination cursor"),
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Listing Grab Requests in family {family_id}.")

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

    helper = GrabRequestHelper(request_id=request.state.request_id)
    try:
        result = helper.list_requests(
            family_id=family_id,
            status=status,
            user_role=user_role,
            user_id=token_user_id,
            start_date=start_date,
            end_date=end_date,
            limit=limit,
            last_key=decoded_last_key,
        )
    except Exception as e:
        logger.error(f"Error in list_requests: {type(e).__name__}: {str(e)}")
        raise

    # Encode last_key for response
    response_last_key = None
    if result.get("last_key"):
        encoded = base64.b64encode(
            json.dumps(result["last_key"]).encode("utf-8")
        ).decode("utf-8")
        response_last_key = encoded

    return JSONResponse(
        content=EntityRefHelper.enrich_entity_refs(
            {
                "requests": result["requests"],
                "last_key": response_last_key,
            }
        ),
        status_code=200,
    )
