"""Helper for moderating uploaded images using Amazon Rekognition."""

import os
import time
from typing import Optional, Dict, Any

import boto3
from aws_lambda_powertools import Logger


class ContentModerationHelper:
    """Scans uploaded images for inappropriate content and handles violations."""

    # Categories that trigger immediate rejection and escalation
    BLOCKED_CATEGORIES = [
        "Explicit Nudity",
        "Non-Explicit Nudity of Intimate parts and Coverage",
        "Sex",
        "Violence",
        "Visually Disturbing",
        "Drugs",
    ]

    MIN_CONFIDENCE = 70  # Minimum confidence threshold for flagging

    def __init__(self, request_id: str = None):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.rekognition = boto3.client("rekognition")
        self.s3 = boto3.client("s3")
        self.ses = boto3.client(
            "ses", region_name=os.environ.get("AWS_REGION", "us-west-2")
        )
        self.photos_bucket = os.environ.get("FAMGRAB_PHOTOS_BUCKET")
        self.escalation_email = os.environ.get("ESCALATION_EMAIL")
        self.sender_email = os.environ.get("SENDER_EMAIL", "noreply@famhelpdesk.com")

    def moderate_image(
        self,
        s3_key: str,
        user_id: str,
        family_id: str,
        request_id: str,
        item_id: str,
    ) -> Dict[str, Any]:
        """
        Analyze an uploaded image for inappropriate content.

        Args:
            s3_key: The S3 key of the uploaded image
            user_id: The user who uploaded the image
            family_id: The family context
            request_id: The grab request ID
            item_id: The item ID

        Returns:
            dict with:
                - is_safe: bool - whether the image passed moderation
                - labels: list - any moderation labels found
                - quarantine_key: str or None - new S3 key if quarantined
        """
        self.logger.info(f"Moderating image {s3_key} uploaded by {user_id}")

        try:
            response = self.rekognition.detect_moderation_labels(
                Image={"S3Object": {"Bucket": self.photos_bucket, "Name": s3_key}},
                MinConfidence=self.MIN_CONFIDENCE,
            )
        except Exception as e:
            self.logger.error(f"Rekognition call failed for {s3_key}: {e}")
            # If Rekognition fails, allow the image through but log the failure
            return {"is_safe": True, "labels": [], "quarantine_key": None}

        labels = response.get("ModerationLabels", [])

        if not labels:
            self.logger.info(f"Image {s3_key} passed moderation - no labels detected")
            return {"is_safe": True, "labels": [], "quarantine_key": None}

        # Check if any blocked category was detected
        blocked_labels = [
            label
            for label in labels
            if any(
                blocked in (label.get("Name", ""), label.get("ParentName", ""))
                for blocked in self.BLOCKED_CATEGORIES
            )
        ]

        if not blocked_labels:
            self.logger.info(
                f"Image {s3_key} passed moderation - labels found but not in blocked categories: "
                f"{[l['Name'] for l in labels]}"
            )
            return {"is_safe": True, "labels": labels, "quarantine_key": None}

        # Image is flagged - quarantine it
        self.logger.warning(
            f"Image {s3_key} FLAGGED by moderation. User: {user_id}, "
            f"Labels: {[l['Name'] for l in blocked_labels]}"
        )

        quarantine_key = self._quarantine_image(s3_key, user_id, family_id)
        self._send_escalation_email(
            user_id=user_id,
            family_id=family_id,
            request_id=request_id,
            item_id=item_id,
            s3_key=s3_key,
            quarantine_key=quarantine_key,
            labels=blocked_labels,
        )

        return {
            "is_safe": False,
            "labels": blocked_labels,
            "quarantine_key": quarantine_key,
        }

    def _quarantine_image(self, s3_key: str, user_id: str, family_id: str) -> str:
        """Move the flagged image to a quarantine prefix."""
        timestamp = int(time.time())
        filename = s3_key.split("/")[-1]
        quarantine_key = f"quarantine/{family_id}/{user_id}/{timestamp}_{filename}"

        try:
            # Copy to quarantine
            self.s3.copy_object(
                Bucket=self.photos_bucket,
                CopySource={"Bucket": self.photos_bucket, "Key": s3_key},
                Key=quarantine_key,
                MetadataDirective="COPY",
            )
            # Delete original
            self.s3.delete_object(Bucket=self.photos_bucket, Key=s3_key)
            self.logger.info(f"Quarantined image: {s3_key} -> {quarantine_key}")
        except Exception as e:
            self.logger.error(f"Failed to quarantine image {s3_key}: {e}")
            quarantine_key = s3_key  # Keep original key if move fails

        return quarantine_key

    def _send_escalation_email(
        self,
        user_id: str,
        family_id: str,
        request_id: str,
        item_id: str,
        s3_key: str,
        quarantine_key: str,
        labels: list,
    ):
        """Send an escalation email to the admin about flagged content."""
        if not self.escalation_email:
            self.logger.warning("No ESCALATION_EMAIL configured, skipping email alert")
            return

        labels_text = "\n".join(
            f"  - {l['Name']} (Confidence: {l['Confidence']:.1f}%, Parent: {l.get('ParentName', 'N/A')})"
            for l in labels
        )

        subject = f"[FamHelpDesk] Content Moderation Alert - Flagged Image"
        body = (
            f"A user-uploaded image has been flagged by content moderation.\n\n"
            f"--- Details ---\n"
            f"User ID: {user_id}\n"
            f"Family ID: {family_id}\n"
            f"Request ID: {request_id}\n"
            f"Item ID: {item_id}\n"
            f"Original S3 Key: {s3_key}\n"
            f"Quarantine Location: {quarantine_key}\n"
            f"Bucket: {self.photos_bucket}\n"
            f"Timestamp: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}\n\n"
            f"--- Moderation Labels ---\n"
            f"{labels_text}\n\n"
            f"--- Action Required ---\n"
            f"The image has been quarantined and is NOT visible to users.\n"
            f"Please review and take appropriate action.\n"
            f"If this content is illegal, contact law enforcement immediately.\n"
        )

        try:
            self.ses.send_email(
                Source=self.sender_email,
                Destination={"ToAddresses": [self.escalation_email]},
                Message={
                    "Subject": {"Data": subject},
                    "Body": {"Text": {"Data": body}},
                },
            )
            self.logger.info(f"Escalation email sent to {self.escalation_email}")
        except Exception as e:
            self.logger.error(f"Failed to send escalation email: {e}")
