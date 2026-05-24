from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from pydantic import BaseModel

from constants.services import API_SERVICE
from decorators.exceptions_decorator import exceptions_decorator
from exceptions.user_exceptions import InvalidUserIdException
from exceptions.grab_exceptions import (
    GrabUnauthorizedException,
    GrabRequestNotFoundException,
    InvalidGrabStatusTransitionException,
)
from helpers.grab_photo_helper import GrabPhotoHelper
from models.grab_request_item import GrabRequestItemModel
from models.base import FamHelpDeskBaseModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


class UploadPickupPhotoBody(BaseModel):
    item_id: str


@router.post(
    "/{family_id}/grab/requests/{request_id}/pickup-photo/upload-url",
    summary="Get presigned upload URL for pickup photo",
    response_description="Presigned PUT URL and S3 key",
)
@exceptions_decorator
def upload_pickup_photo_url(
    request: Request, family_id: str, request_id: str, body: UploadPickupPhotoBody
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Generating pickup photo upload URL for item {body.item_id} "
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
            "Only the claimer of this item can upload a pickup photo"
        )

    # Generate the upload URL with /pickup/ segment in the key
    photo_helper = GrabPhotoHelper(request_id=request.state.request_id)
    photo_id = FamHelpDeskBaseModel.generate_random_id()
    s3_key = f"{family_id}/{request_id}/{body.item_id}/pickup/{photo_id}.jpg"

    url = photo_helper.s3_client.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": photo_helper.photos_bucket,
            "Key": s3_key,
            "ContentType": "image/jpeg",
        },
        ExpiresIn=GrabPhotoHelper.UPLOAD_TTL_SECONDS,
    )

    logger.info(
        f"Generated pickup photo upload URL for item {body.item_id} "
        f"in request {request_id}, family {family_id}, user {token_user_id}"
    )

    return JSONResponse(
        content={"upload_url": url, "s3_key": s3_key},
        status_code=200,
    )
