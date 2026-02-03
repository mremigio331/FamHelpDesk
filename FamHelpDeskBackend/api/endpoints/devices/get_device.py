from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from decorators.exceptions_decorator import exceptions_decorator
from helpers.ios_device_helper import iOSDeviceHelper
from constants.services import API_SERVICE

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{device_id}",
    summary="Get device registration status",
    response_description="Device registration information",
)
@exceptions_decorator
def get_device(request: Request, device_id: str):
    """
    Get Device Endpoint

    Retrieves device registration information for the authenticated user.

    Args:
        request: FastAPI request object
        device_id: Device identifier to retrieve

    Returns:
        A JSON response with device information
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Retrieving device {device_id}")

    # Extract user_id from authenticated request
    user_id = getattr(request.state, "user_token", None)
    if not user_id:
        logger.warning("User ID could not be extracted from JWT")
        return JSONResponse(
            content={"success": False, "message": "Authentication required"},
            status_code=401,
        )

    # Use helper to get device
    device_helper = iOSDeviceHelper(request_id=request.state.request_id)
    device = device_helper.get_device(user_id, device_id)

    if not device:
        return JSONResponse(
            content={"success": False, "message": "Device not found"},
            status_code=404,
        )

    # Verify device belongs to authenticated user
    if device.user_id != user_id:
        logger.warning(
            f"User {user_id} attempted to access device belonging to {device.user_id}"
        )
        return JSONResponse(
            content={
                "success": False,
                "message": "Unauthorized: device does not belong to user",
            },
            status_code=403,
        )

    # Return device info (excluding full apns_token for security)
    return JSONResponse(
        content={
            "device_id": device.device_id,
            "environment": device.environment,
            "bundle_id": device.bundle_id,
            "enabled": device.enabled,
            "created_date": device.created_date,
            "last_updated": device.last_updated,
        },
        status_code=200,
    )
