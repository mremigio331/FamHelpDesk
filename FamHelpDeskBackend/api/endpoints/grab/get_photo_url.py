from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from exceptions.grab_exceptions import (
    GrabUnauthorizedException,
    NoPhotoAvailableException,
)
from helpers.grab_request_helper import GrabRequestHelper
from helpers.grab_photo_helper import GrabPhotoHelper
from helpers.family_membership_helper import FamilyMembershipHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/grab/requests/{request_id}/photo",
    summary="Get presigned view URL for delivery photo",
    response_description="Presigned GET URL for the delivery photo",
)
@exceptions_decorator
def get_photo_url(request: Request, family_id: str, request_id: str):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Generating view URL for Grab Request {request_id} in family {family_id}."
    )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Get the request and items
    request_helper = GrabRequestHelper(request_id=request.state.request_id)
    grab_request_data = request_helper.get_request(family_id, request_id)
    grab_request = grab_request_data["request"]
    items = grab_request_data.get("items", [])

    # Extract requestor_id (may be EntityRef object or dict)
    requestor_id_raw = grab_request.get("requestor_id")
    if hasattr(requestor_id_raw, "id"):
        requestor_id = requestor_id_raw.id
    elif isinstance(requestor_id_raw, dict):
        requestor_id = requestor_id_raw.get("id")
    else:
        requestor_id = requestor_id_raw

    # Check authorization: requestor, any claimer of items, or admin
    is_requestor = token_user_id == requestor_id
    is_claimer = False
    for item in items:
        claimer = item.get("claimer_id")
        if claimer is None:
            continue
        if hasattr(claimer, "id"):
            if claimer.id == token_user_id:
                is_claimer = True
                break
        elif isinstance(claimer, dict):
            if claimer.get("id") == token_user_id:
                is_claimer = True
                break
        elif claimer == token_user_id:
            is_claimer = True
            break

    is_admin = False
    if not is_requestor and not is_claimer:
        membership_helper = FamilyMembershipHelper(request_id=request.state.request_id)
        admin_ids = membership_helper.get_all_admins(family_id)
        is_admin = token_user_id in admin_ids

    if not is_requestor and not is_claimer and not is_admin:
        raise GrabUnauthorizedException(
            "Only the requestor, claimer, or a family admin can view the delivery photo"
        )

    # Find the photo key from items (first item with a proof_photo_key)
    photo_key = None
    for item in items:
        key = item.get("proof_photo_key")
        if key:
            photo_key = key
            break

    # Fall back to request-level photo key
    if not photo_key:
        photo_key = grab_request.get("proof_photo_key")

    if not photo_key:
        raise NoPhotoAvailableException(
            f"No delivery photo available for request {request_id}"
        )

    # Generate presigned view URL directly (we've already done auth)
    photo_helper = GrabPhotoHelper(request_id=request.state.request_id)
    result = photo_helper.generate_view_url(
        family_id=family_id,
        request_id=request_id,
        user_id=token_user_id,
        requestor_id=token_user_id,  # Pass same ID to bypass helper's internal check
        claimer_id=token_user_id,  # since we already verified authorization above
        is_admin=is_admin,
        photo_key=photo_key,
    )

    return JSONResponse(
        content={"view_url": result["view_url"]},
        status_code=200,
    )
