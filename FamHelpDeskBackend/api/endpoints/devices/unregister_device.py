from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from decorators.exceptions_decorator import exceptions_decorator
from helpers.ios_device_helper import iOSDeviceHelper
from constants.services import API_SERVICE

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.delete(
    "/{device_id}",
    summary="Unregister device from push notifications",
    response_description="Device unregistration confirmation",
)
@exceptions_decorator
def unregister_device(request: Request, device_id: str):
    """
    Unregister Device Endpoint

    Removes a device registration for push notifications.

    Args:
        request: FastAPI request object
        device_id: Device identifier to unregister

    Returns:
        A JSON response confirming device unregistration
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info(f"Unregistering device {device_id}")

    # Extract user_id from authenticated request
    user_id = getattr(request.state, "user_token", None)
    if not user_id:
        logger.warning("User ID could not be extracted from JWT")
        return JSONResponse(
            content={"success": False, "message": "Authentication required"},
            status_code=401,
        )

    # Use helper to unregister device
    device_helper = iOSDeviceHelper(request_id=request.state.request_id)
    success = device_helper.unregister_device(user_id, device_id)

    if success:
        return JSONResponse(
            content={
                "success": True,
                "message": "Device unregistered successfully",
            },
            status_code=200,
        )
    else:
        return JSONResponse(
            content={"success": False, "message": "Device not found"},
            status_code=404,
        )
