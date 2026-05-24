"""Helper for generating presigned S3 URLs for grab request photos (delivery and pickup)."""

import os
from typing import Optional

import boto3
from aws_lambda_powertools import Logger

from models.base import FamHelpDeskBaseModel
from exceptions.grab_exceptions import (
    GrabUnauthorizedException,
    NoPhotoAvailableException,
)


class GrabPhotoHelper:
    """Handles presigned URL generation for grab request delivery photos."""

    ALLOWED_CONTENT_TYPES = ["image/jpeg", "image/png", "image/heic"]
    UPLOAD_TTL_SECONDS = 300  # 5 minutes
    VIEW_TTL_SECONDS = 900  # 15 minutes
    MAX_UPLOAD_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB

    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
        notification_queue_url: str = None,
        photos_bucket: Optional[str] = None,
    ):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.photos_bucket = photos_bucket or os.environ.get("FAMGRAB_PHOTOS_BUCKET")
        self.s3_client = boto3.client("s3")

    def generate_upload_url(
        self,
        family_id: str,
        request_id: str,
        claimer_id: str,
        user_id: str,
        item_id: Optional[str] = None,
        photo_type: str = "delivery",
    ) -> dict:
        """
        Generate a presigned PUT URL for uploading a photo.

        Only the claimer of a request is authorized to upload a photo.

        Args:
            family_id: The family ID
            request_id: The grab request ID
            claimer_id: The claimer of the request
            user_id: The user requesting the upload URL
            item_id: Optional item ID to include in the S3 key for per-item photos
            photo_type: Type of photo - "delivery" (default) or "pickup".
                        When "pickup", includes a /pickup/ segment in the S3 key.

        Returns:
            dict with "upload_url" and "s3_key"

        Raises:
            GrabUnauthorizedException: If user is not the claimer
        """
        if user_id != claimer_id:
            raise GrabUnauthorizedException(
                "Only the claimer can upload a delivery photo"
            )

        photo_id = FamHelpDeskBaseModel.generate_random_id()
        if item_id:
            if photo_type == "pickup":
                s3_key = f"{family_id}/{request_id}/{item_id}/pickup/{photo_id}.jpg"
            else:
                s3_key = f"{family_id}/{request_id}/{item_id}/{photo_id}.jpg"
        else:
            s3_key = f"{family_id}/{request_id}/{photo_id}.jpg"

        url = self.s3_client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": self.photos_bucket,
                "Key": s3_key,
                "ContentType": "image/jpeg",
            },
            ExpiresIn=self.UPLOAD_TTL_SECONDS,
        )

        self.logger.info(
            f"Generated upload URL for request {request_id} in family {family_id} "
            f"by user {user_id}"
        )

        return {
            "upload_url": url,
            "s3_key": s3_key,
        }

    def generate_public_view_url(self, photo_key: str) -> dict:
        """
        Generate a presigned GET URL for a public photo.
        No authorization check - caller is responsible for verifying
        photo_visibility == "public" and family membership.

        Args:
            photo_key: The S3 key of the photo

        Returns:
            dict with "view_url"
        """
        url = self.s3_client.generate_presigned_url(
            "get_object",
            Params={
                "Bucket": self.photos_bucket,
                "Key": photo_key,
            },
            ExpiresIn=self.VIEW_TTL_SECONDS,
        )

        self.logger.info(f"Generated public view URL for photo key {photo_key}")

        return {
            "view_url": url,
        }

    def generate_view_url(
        self,
        family_id: str,
        request_id: str,
        user_id: str,
        requestor_id: str,
        claimer_id: str,
        is_admin: bool = False,
        photo_key: Optional[str] = None,
    ) -> dict:
        """
        Generate a presigned GET URL for viewing a delivery proof photo.

        Only the requestor, claimer, or a family admin can view the photo.

        Args:
            family_id: The family ID
            request_id: The grab request ID
            user_id: The user requesting the view URL
            requestor_id: The requestor of the grab request
            claimer_id: The claimer of the grab request
            is_admin: Whether the user is a family admin
            photo_key: The S3 key of the photo (proof_photo_key from the request)

        Returns:
            dict with "view_url"

        Raises:
            GrabUnauthorizedException: If user is not authorized to view
            NoPhotoAvailableException: If no photo key exists
        """
        # Check authorization
        is_requestor = user_id == requestor_id
        is_claimer = user_id == claimer_id
        if not is_requestor and not is_claimer and not is_admin:
            raise GrabUnauthorizedException(
                "Only the requestor, claimer, or a family admin can view the delivery photo"
            )

        # Check photo exists
        if not photo_key:
            raise NoPhotoAvailableException(
                f"No delivery photo available for request {request_id}"
            )

        url = self.s3_client.generate_presigned_url(
            "get_object",
            Params={
                "Bucket": self.photos_bucket,
                "Key": photo_key,
            },
            ExpiresIn=self.VIEW_TTL_SECONDS,
        )

        self.logger.info(
            f"Generated view URL for request {request_id} in family {family_id} "
            f"by user {user_id}"
        )

        return {
            "view_url": url,
        }
