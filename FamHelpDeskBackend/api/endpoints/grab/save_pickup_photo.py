from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel
from typing import Optional

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from exceptions.grab_exceptions import (
    GrabUnauthorizedException,
    GrabRequestNotFoundException,
    InvalidGrabStatusTransitionException,
)
from helpers.content_moderation_helper import ContentModerationHelper
from helpers.notification_helper import NotificationHelper
from helpers.entity_ref import EntityRefHelper
from models.base import FamHelpDeskBaseModel
from models.grab_request import GrabRequestModel
from models.grab_request_item import GrabRequestItemModel
from models.family_notification_settings import FamilyNotificationType

logger = Logger(service=API_SERVICE)
router = APIRouter()


class SavePickupPhotoBody(BaseModel):
    item_id: str
    s3_key: str
    photo_visibility: Optional[str] = "private"


@router.post(
    "/{family_id}/grab/requests/{request_id}/pickup-photo/save",
    summary="Save pickup photo for a claimed item",
    response_description="The updated item",
)
@exceptions_decorator
def save_pickup_photo(
    request: Request, family_id: str, request_id: str, body: SavePickupPhotoBody
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Saving pickup photo for item {body.item_id} "
        f"in request {request_id}, family {family_id}."
    )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Look up the specific item
    try:
        item = GrabRequestItemModel.get(
            hash_key=GrabRequestItemModel.create_pk(family_id),
            range_key=GrabRequestItemModel.create_sk(request_id, body.item_id),
        )
    except Exception:
        raise GrabRequestNotFoundException(
            f"Item {body.item_id} not found in request {request_id}"
        )

    # Validate item status is CLAIMED
    if getattr(item, "status", None) != "CLAIMED":
        raise InvalidGrabStatusTransitionException(
            f"Item {body.item_id} is not in CLAIMED status. "
            f"Current status: {getattr(item, 'status', 'UNKNOWN')}"
        )

    # Validate user is the claimer
    if getattr(item, "claimer_id", None) != token_user_id:
        raise GrabUnauthorizedException(
            "Only the claimer of this item can save a pickup photo"
        )

    # Run content moderation
    moderation_helper = ContentModerationHelper(request_id=request.state.request_id)
    moderation_result = moderation_helper.moderate_image(
        s3_key=body.s3_key,
        user_id=token_user_id,
        family_id=family_id,
        request_id=request_id,
        item_id=body.item_id,
    )

    if moderation_result["is_safe"]:
        # Photo is safe — persist pickup photo fields on item
        now = FamHelpDeskBaseModel.now_epoch()
        one_week_seconds = 7 * 24 * 60 * 60

        item.pickup_photo_key = body.s3_key
        item.pickup_photo_visibility = body.photo_visibility or "private"
        item.pickup_photo_expires_at = now + one_week_seconds
        item.save()

        logger.info(
            f"Pickup photo saved for item {body.item_id} "
            f"in request {request_id}, family {family_id}, user {token_user_id}"
        )
    else:
        # Photo flagged — log warning, return item without pickup photo
        logger.warning(
            f"Pickup photo {body.s3_key} flagged by moderation for item {body.item_id} "
            f"in request {request_id}. Returning item without pickup photo."
        )

    # Send async notification to requestor
    try:
        grab_request = GrabRequestModel.get(
            hash_key=GrabRequestModel.create_pk(family_id),
            range_key=GrabRequestModel.create_sk(request_id),
        )

        notification_helper = NotificationHelper(
            request_id=request.state.request_id,
        )
        notification_helper.create_notification_async(
            notification_type=FamilyNotificationType.GRAB_PICKUP_PHOTO,
            family_id=family_id,
            request_id=request_id,
            requestor_id=grab_request.requestor_id,
            claimer_id=token_user_id,
            item_name=item.name,
        )
    except Exception as e:
        logger.warning(
            f"Failed to send pickup photo notification for item {body.item_id}: {e}"
        )

    # Return updated item
    cleaned_item = GrabRequestItemModel.clean_returned_item(item)

    return JSONResponse(
        content=EntityRefHelper.enrich_entity_refs({"item": cleaned_item}),
        status_code=200,
    )
