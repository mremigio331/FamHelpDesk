from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel, Field
from decorators.exceptions_decorator import exceptions_decorator
from helpers.ios_device_helper import iOSDeviceHelper
from constants.services import API_SERVICE

logger = Logger(service=API_SERVICE)
router = APIRouter()


class DeviceRegistrationRequest(BaseModel):
    device_id: str = Field(..., description="Unique device identifier (UUID)")
    apns_token: str = Field(..., description="Device token from APNs (hex string)")
    environment: str = Field(..., description="APNs environment: sandbox or production")
    bundle_id: str = Field(..., description="iOS app bundle identifier")


@router.post(
    "/register",
    summary="Register device for push notifications",
    response_description="Device registration confirmation",
)
@exceptions_decorator
def register_device(request: Request, body: DeviceRegistrationRequest):
    """
    Register Device Endpoint

    Registers an iOS device for push notifications. If the device already exists,
    updates the APNs token and last_updated timestamp.

    Args:
        request: FastAPI request object
        body: Device registration data

    Returns:
        A JSON response confirming device registration
    """
    logger.append_keys(request_id=request.state.request_id)
    logger.info("Registering device for push notifications")

    # Extract user_id from authenticated request
    user_id = getattr(request.state, "user_token", None)
    if not user_id:
        logger.warning("User ID could not be extracted from JWT")
        return JSONResponse(
            content={"success": False, "message": "Authentication required"},
            status_code=401,
        )

    # Use helper to register device
    device_helper = iOSDeviceHelper(request_id=request.state.request_id)

    # Check if device already exists to determine response status code
    existing_device = device_helper.get_device(user_id, body.device_id)

    device = device_helper.register_device(
        user_id=user_id,
        device_id=body.device_id,
        apns_token=body.apns_token,
        environment=body.environment,
        bundle_id=body.bundle_id,
    )

    if existing_device:
        return JSONResponse(
            content={
                "success": True,
                "device_id": device.device_id,
                "message": "Device token updated successfully",
            },
            status_code=200,
        )
    else:
        return JSONResponse(
            content={
                "success": True,
                "device_id": device.device_id,
                "message": "Device registered successfully",
            },
            status_code=201,
        )
