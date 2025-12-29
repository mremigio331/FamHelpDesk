from fastapi import APIRouter, Request, Query
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from exceptions.user_exceptions import InvalidUserIdException
from decorators.exceptions_decorator import exceptions_decorator
from helpers.notification_helper import NotificationHelper
from constants.services import API_SERVICE
from typing import Optional
import json
import base64

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "",
    summary="Get notifications for the current user",
    response_description="Paginated list of notifications for the requester",
)
@exceptions_decorator
def get_notifications(
    request: Request,
    limit: int = Query(
        default=50, ge=1, le=100, description="Number of notifications to return"
    ),
    next_token: Optional[str] = Query(
        default=None, description="Pagination token from previous response"
    ),
):
    """
    Get Notifications Endpoint

    Returns notifications for the current authenticated user with pagination.
    Notifications are sorted by timestamp (newest first).

    Args:
        limit: Number of notifications to return (default: 50, max: 100)
        next_token: Pagination token to get the next page of results

    Returns:
        A JSON response containing:
        - notifications: List of notification objects
        - count: Number of notifications in this response
        - next_token: Token for next page (null if no more results)
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Getting notifications for user.")

    token_user_id = getattr(request.state, "user_token", None)
    logger.info(f"Extracted token_user_id: {token_user_id}")

    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Decode next_token if provided
    last_evaluated_key = None
    if next_token:
        try:
            decoded = base64.b64decode(next_token).decode("utf-8")
            last_evaluated_key = json.loads(decoded)
        except Exception as e:
            logger.warning(f"Invalid next_token provided: {str(e)}")
            return JSONResponse(
                content={"error": "Invalid pagination token"},
                status_code=400,
            )

    notification_helper = NotificationHelper(request_id=request.state.request_id)
    result = notification_helper.get_notifications(
        user_id=token_user_id,
        limit=limit,
        last_evaluated_key=last_evaluated_key,
    )

    # Encode next_token if present
    response_next_token = None
    if result["next_token"]:
        encoded = base64.b64encode(
            json.dumps(result["next_token"]).encode("utf-8")
        ).decode("utf-8")
        response_next_token = encoded

    return JSONResponse(
        content={
            "notifications": result["notifications"],
            "count": result["count"],
            "next_token": response_next_token,
        },
        status_code=200,
    )
