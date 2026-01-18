"""
Lambda function to process notification events from SNS.
This function receives notification events and creates notifications in DynamoDB.
"""

import json
import logging
import os
import time
from typing import Dict, Any, Optional

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_result,
    wait_random_exponential,
)

from helpers.notification_helper import NotificationHelper
from helpers.notification_settings_helper import NotificationSettingsHelper
from models.notification import NotificationType

# Initialize logger
logger = Logger()


def _should_retry_settings_check(result: bool) -> bool:
    """
    Determine if we should retry the notification settings check.
    Retry if the result is False (notification disabled/not found).
    """
    return not result


@retry(
    stop=stop_after_attempt(4),
    wait=wait_random_exponential(multiplier=0.1, min=0.1, max=2.0),
    retry=retry_if_result(_should_retry_settings_check),
    reraise=True,
)
def _check_notification_enabled_with_retry(
    settings_helper: NotificationSettingsHelper,
    user_id: str,
    notification_type: NotificationType,
) -> bool:
    """
    Check if notifications are enabled for a user with retry logic.
    Handles DynamoDB eventual consistency by retrying when settings are not found.

    Args:
        settings_helper: NotificationSettingsHelper instance
        user_id: User ID to check settings for
        notification_type: Type of notification to check

    Returns:
        bool: True if notification should be sent, False otherwise
    """
    logger.info(
        f"Checking notification settings for user {user_id}, type {notification_type.value}"
    )

    is_enabled = settings_helper.is_notification_enabled(user_id, notification_type)

    if not is_enabled:
        logger.info(
            f"Notification settings check returned False for user {user_id}, notification {notification_type.value} - will retry if attempts remain"
        )
    else:
        logger.info(
            f"Notification {notification_type.value} is enabled for user {user_id}"
        )

    return is_enabled


def lambda_handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    """
    Process notification events from SNS.

    Args:
        event: SNS event containing notification data
        context: Lambda context

    Returns:
        Dict with processing results
    """
    logger.info("Processing notification events", extra={"event": event})

    processed_count = 0
    failed_count = 0

    try:
        # Process each SNS record
        for record in event.get("Records", []):
            try:
                # Parse SNS message
                sns_message = json.loads(record["Sns"]["Message"])

                # Extract notification data
                notification_data = _extract_notification_data(sns_message)

                # Process the notification
                _process_notification(notification_data, context.aws_request_id)

                processed_count += 1
                logger.info(
                    f"Successfully processed notification for user {notification_data['user_id']}"
                )

            except Exception as e:
                failed_count += 1
                logger.error(
                    f"Failed to process notification record: {str(e)}",
                    extra={"record": record, "error": str(e)},
                )
                # Continue processing other records
                continue

    except Exception as e:
        logger.error(f"Critical error processing notification batch: {str(e)}")
        raise

    result = {"statusCode": 200, "processed": processed_count, "failed": failed_count}

    logger.info("Notification processing completed", extra=result)
    return result


def _extract_notification_data(sns_message: Dict[str, Any]) -> Dict[str, Any]:
    """
    Extract and validate notification data from SNS message.

    Args:
        sns_message: Parsed SNS message

    Returns:
        Dict containing validated notification data

    Raises:
        ValueError: If required fields are missing or invalid
    """
    required_fields = ["user_id", "message", "notification_type"]

    # Validate required fields
    for field in required_fields:
        if field not in sns_message:
            raise ValueError(f"Missing required field: {field}")

    # Validate notification type
    notification_type_str = sns_message["notification_type"]
    try:
        notification_type = NotificationType(notification_type_str)
    except ValueError:
        raise ValueError(f"Invalid notification type: {notification_type_str}")

    return {
        "user_id": sns_message["user_id"],
        "message": sns_message["message"],
        "notification_type": notification_type,
        # Include any additional fields dynamically
        **{
            k: v
            for k, v in sns_message.items()
            if k not in ["user_id", "message", "notification_type"]
        },
    }


def _process_notification(notification_data: Dict[str, Any], request_id: str) -> None:
    """
    Process a single notification by checking user preferences and creating the notification.

    Args:
        notification_data: Validated notification data
        request_id: Lambda request ID for logging correlation
    """
    user_id = notification_data["user_id"]
    notification_type = notification_data["notification_type"]

    # Initialize helpers
    notification_helper = NotificationHelper(request_id=request_id)
    settings_helper = NotificationSettingsHelper(request_id=request_id)

    # Check if user has notifications enabled for this type with retry logic
    try:
        is_enabled = _check_notification_enabled_with_retry(
            settings_helper, user_id, notification_type
        )

        if not is_enabled:
            logger.info(
                f"Notification {notification_type.value} disabled for user {user_id} after retries, skipping"
            )
            return

    except Exception as e:
        # If all retries failed, log the error but still send the notification as a fallback
        logger.warning(
            f"Failed to check notification settings for user {user_id} after retries: {str(e)}. "
            f"Defaulting to enabled for {notification_type.value}"
        )
        # Continue to send the notification

    # Create the notification
    # Extract kwargs (all fields except the required ones)
    notification_kwargs = {
        k: v
        for k, v in notification_data.items()
        if k not in ["user_id", "message", "notification_type"]
    }

    notification_helper.create_notification(
        user_id=user_id,
        message=notification_data["message"],
        notification_type=notification_type,
        **notification_kwargs,  # Pass all additional context dynamically
    )

    logger.info(f"Created notification {notification_type.value} for user {user_id}")
