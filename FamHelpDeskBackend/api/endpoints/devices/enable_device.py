from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from decorators.exceptions_decorator import exceptions_decorator
from helpers.ios_device_helper import iOSDeviceHelper
from constants.services import API_SERVICE

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.put(
    "/{device_id}/enable",
    summary="Enable device for push notifications",
    response_description="Updated device information",
)
@exceptions_decorator
def enable_device(request: Request, device_id: str):
    """
    Enable Device Endpoint

    Enables push notifications for a registered device.

    Args:
        request: FastAPI request object
        device_id: Device identifier to enable

    Returns:
        A JSON response with updated device information
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Enabling device {device_id}")

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
            f"User {user_id} attempted to enable device belonging to {device.user_id}"
        )
        return JSONResponse(
            content={
                "success": False,
                "message": "Unauthorized: device does not belong to user",
            },
            status_code=403,
        )

    # Enable the device
    device_helper.enable_device(user_id, device_id)

    # Get updated device
    updated_device = device_helper.get_device(user_id, device_id)

    # Return updated device info
    return JSONResponse(
        content={
            "device_id": updated_device.device_id,
            "environment": updated_device.environment,
            "bundle_id": updated_device.bundle_id,
            "enabled": updated_device.enabled,
            "created_date": updated_device.created_date,
            "last_updated": updated_device.last_updated,
        },
        status_code=200,
    )
