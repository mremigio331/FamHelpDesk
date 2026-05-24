import time
from typing import Optional

from fastapi import APIRouter, Query, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from exceptions.grab_exceptions import (
    GrabUnauthorizedException,
    NoPhotoAvailableException,
    PickupPhotoExpiredException,
)
from helpers.grab_request_helper import GrabRequestHelper
from helpers.grab_photo_helper import GrabPhotoHelper
from helpers.family_membership_helper import FamilyMembershipHelper

logger = Logger(service=API_SERVICE)
router = APIRouter()


@router.get(
    "/{family_id}/grab/requests/{request_id}/pickup-photo",
    summary="Get presigned view URL for pickup photo",
    response_description="Presigned GET URL for the pickup photo",
)
@exceptions_decorator
def get_pickup_photo_url(
    request: Request,
    family_id: str,
    request_id: str,
    item_id: Optional[str] = Query(
        None, description="Item ID to get pickup photo for (required)"
    ),
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Generating pickup photo view URL for request {request_id} "
        f"in family {family_id}, item {item_id}."
    )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Validate item_id query param is provided
    if not item_id:
        return JSONResponse(
            content={
                "error": {
                    "code": "MISSING_ITEM_ID",
                    "message": "item_id query parameter is required.",
                }
            },
            status_code=400,
        )

    # Get the request and items
    request_helper = GrabRequestHelper(request_id=request.state.request_id)
    grab_request_data = request_helper.get_request(family_id, request_id)
    grab_request = grab_request_data["request"]
    items = grab_request_data.get("items", [])

    # Find the specific item
    target_item = None
    for item in items:
        if item.get("item_id") == item_id:
            target_item = item
            break

    if target_item is None:
        raise NoPhotoAvailableException(
            f"Item {item_id} not found in request {request_id}"
        )

    # Check pickup_photo_key exists
    photo_key = target_item.get("pickup_photo_key")
    if not photo_key:
        raise NoPhotoAvailableException(f"No pickup photo available for item {item_id}")

    # Check pickup_photo_expires_at — if expired, return 410
    expires_at = target_item.get("pickup_photo_expires_at")
    now = int(time.time())
    if expires_at and now > expires_at:
        raise PickupPhotoExpiredException(
            f"Pickup photo for item {item_id} has expired"
        )

    # Authorization based on visibility
    visibility = target_item.get("pickup_photo_visibility", "private")

    # Extract requestor_id
    requestor_id_raw = grab_request.get("requestor_id")
    if hasattr(requestor_id_raw, "id"):
        requestor_id = requestor_id_raw.id
    elif isinstance(requestor_id_raw, dict):
        requestor_id = requestor_id_raw.get("id")
    else:
        requestor_id = requestor_id_raw

    # Extract claimer_id for this item
    claimer_id_raw = target_item.get("claimer_id")
    if hasattr(claimer_id_raw, "id"):
        claimer_id = claimer_id_raw.id
    elif isinstance(claimer_id_raw, dict):
        claimer_id = claimer_id_raw.get("id")
    else:
        claimer_id = claimer_id_raw

    if visibility == "public":
        # Any family member can view
        membership_helper = FamilyMembershipHelper(request_id=request.state.request_id)
        membership = membership_helper.get_membership(family_id, token_user_id)
        if not membership:
            raise GrabUnauthorizedException(
                "Only family members can view this pickup photo"
            )
    else:
        # Private: only requestor, claimer, or admin
        is_requestor = token_user_id == requestor_id
        is_claimer = token_user_id == claimer_id

        is_admin = False
        if not is_requestor and not is_claimer:
            membership_helper = FamilyMembershipHelper(
                request_id=request.state.request_id
            )
            admin_ids = membership_helper.get_all_admins(family_id)
            is_admin = token_user_id in admin_ids

        if not is_requestor and not is_claimer and not is_admin:
            raise GrabUnauthorizedException(
                "Only the requestor, claimer, or a family admin can view this pickup photo"
            )

    # Generate presigned GET URL (bypass internal auth since we already checked)
    photo_helper = GrabPhotoHelper(request_id=request.state.request_id)
    result = photo_helper.generate_view_url(
        family_id=family_id,
        request_id=request_id,
        user_id=token_user_id,
        requestor_id=token_user_id,  # Pass same ID to bypass helper's internal check
        claimer_id=token_user_id,  # since we already verified authorization above
        is_admin=True,  # bypass internal auth
        photo_key=photo_key,
    )

    return JSONResponse(
        content={"view_url": result["view_url"]},
        status_code=200,
    )
