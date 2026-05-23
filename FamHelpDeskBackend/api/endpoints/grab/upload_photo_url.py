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
)
from helpers.grab_photo_helper import GrabPhotoHelper
from models.grab_request_item import GrabRequestItemModel

logger = Logger(service=API_SERVICE)
router = APIRouter()


class UploadPhotoBody(BaseModel):
    item_id: str


@router.post(
    "/{family_id}/grab/requests/{request_id}/photo/upload-url",
    summary="Get presigned upload URL for delivery photo",
    response_description="Presigned PUT URL and S3 key",
)
@exceptions_decorator
def upload_photo_url(
    request: Request, family_id: str, request_id: str, body: UploadPhotoBody
):
    logger.append_keys(request_id=request.state.request_id)
    logger.info(
        f"Generating upload URL for Grab Request {request_id} in family {family_id}."
    )

    token_user_id = getattr(request.state, "user_token", None)
    if not token_user_id:
        logger.warning("Token User ID could not be extracted from JWT.")
        raise InvalidUserIdException("Token User ID is required.")

    # Look up the specific item to verify the user is its claimer
    try:
        item = GrabRequestItemModel.get(
            hash_key=GrabRequestItemModel.create_pk(family_id),
            range_key=GrabRequestItemModel.create_sk(request_id, body.item_id),
        )
    except Exception:
        raise GrabRequestNotFoundException(
            f"Item {body.item_id} not found in request {request_id}"
        )

    if getattr(item, "claimer_id", None) != token_user_id:
        raise GrabUnauthorizedException(
            "Only the claimer of this item can upload a delivery photo"
        )

    # Generate the upload URL
    photo_helper = GrabPhotoHelper(request_id=request.state.request_id)
    result = photo_helper.generate_upload_url(
        family_id=family_id,
        request_id=request_id,
        claimer_id=token_user_id,
        user_id=token_user_id,
        item_id=body.item_id,
    )

    return JSONResponse(
        content={"upload_url": result["upload_url"], "s3_key": result["s3_key"]},
        status_code=200,
    )
