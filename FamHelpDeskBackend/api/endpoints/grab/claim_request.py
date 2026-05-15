from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.post(
    "/{family_id}/grab/requests/{request_id}/claim",
    summary="[DEPRECATED] Claim an open Grab Request",
    response_description="Deprecation notice",
)
@exceptions_decorator
def claim_request(request: Request, family_id: str, request_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Deprecated claim endpoint called for request {request_id} in family {family_id}."
    )

    return JSONResponse(
        content={
            "error": {
                "code": "ENDPOINT_DEPRECATED",
                "message": (
                    "This endpoint is deprecated. Use POST "
                    f"/{family_id}/grab/requests/{request_id}/claim-items instead."
                ),
            }
        },
        status_code=410,
    )
