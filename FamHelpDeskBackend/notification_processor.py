import json
import os
from typing import Dict, Any

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext

from helpers.notification_helper import NotificationHelper
from helpers.notification_helpers import (
    FamilyMembershipNotificationHelper,
    GroupMembershipNotificationHelper,
    TicketNotificationHelper,
    GrabNotificationHelper,
)
from models.family_notification_settings import FamilyNotificationType
from constants.services import NOTIFICATION_SERVICE

logger = Logger(service=NOTIFICATION_SERVICE, level="INFO")

# Environment variables
STAGE = os.environ.get("STAGE")
TABLE_NAME = os.environ.get("TABLE_NAME")
NOTIFICATION_QUEUE_URL = os.environ.get("NOTIFICATION_QUEUE_URL")


def _process_welcome_notification(message: Dict[str, Any], request_id: str) -> None:
    user_id = message.get("user_id")
    if not user_id:
        raise ValueError("Missing user_id in welcome notification")

    notification_helper = NotificationHelper(
        request_id=request_id,
        stage=STAGE,
        table_name=TABLE_NAME,
        notification_queue_url=NOTIFICATION_QUEUE_URL,
    )
    welcome_message = (
        "Welcome to FamHelpDesk! You can find a family in the Find Family "
        "section or create your own."
    )
    notification_helper.create_notification(
        user_id=user_id,
        message=welcome_message,
        notification_type=FamilyNotificationType.WELCOME,
    )
    logger.info(
        "Created welcome notification",
        extra={"user_id": user_id},
    )


def lambda_handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    """
    Process notification events from SQS.
    Routes notifications to appropriate helper based on notification type.

    Args:
        event: SQS event containing notification data
        context: Lambda context

    Returns:
        Dict with batchItemFailures for partial batch failure reporting

    Raises:
        Exception: Any processing error will be raised to trigger SQS retry
    """
    logger.info("Processing notification events from SQS", extra={"event": event})

    processed_count = 0
    failed_message_ids = []

    # Process each SQS record
    for record in event.get("Records", []):
        message_id = record.get("messageId")

        try:
            # Parse SQS message body
            message = json.loads(record["body"])

            # Extract notification type
            notification_type_str = message.get("notification_type")
            if not notification_type_str:
                logger.error(f"Missing notification_type in message {message_id}")
                failed_message_ids.append(message_id)
                continue

            # Convert to enum
            try:
                notification_type = FamilyNotificationType(notification_type_str)
            except ValueError:
                logger.error(
                    f"Invalid notification type: {notification_type_str} in message {message_id}"
                )
                failed_message_ids.append(message_id)
                continue

            # Route to appropriate helper based on notification type
            request_id = context.aws_request_id

            # Remove notification_type and message from kwargs to avoid conflicts
            # Helpers generate their own messages based on the context
            message_kwargs = {
                k: v
                for k, v in message.items()
                if k not in ["notification_type", "message"]
            }

            # Family membership notifications
            if notification_type in [
                FamilyNotificationType.NEW_FAMILY_CREATION,
                FamilyNotificationType.FAMILY_MEMBERSHIP_REQUEST,
                FamilyNotificationType.FAMILY_MEMBERSHIP_APPROVED,
                FamilyNotificationType.FAMILY_MEMBERSHIP_DENIED,
                FamilyNotificationType.FAMILY_MEMBERSHIP_INVITATION,
                FamilyNotificationType.FAMILY_MEMBER_JOINED,
                FamilyNotificationType.FAMILY_MEMBERSHIP_LEFT,
                FamilyNotificationType.FAMILY_MEMBERSHIP_REQUEST,
                FamilyNotificationType.NEW_FAMILY_MEMEBER,
                FamilyNotificationType.WELCOME_TO_FAMILY,
            ]:
                helper = FamilyMembershipNotificationHelper(
                    request_id=request_id,
                    stage=STAGE,
                    table_name=TABLE_NAME,
                    notification_queue_url=NOTIFICATION_QUEUE_URL,
                )
                helper.process_notification(notification_type, **message_kwargs)

            # Group membership notifications
            elif notification_type in [
                FamilyNotificationType.NEW_GROUP_CREATION,
                FamilyNotificationType.GROUP_MEMBERSHIP_REQUEST,
                FamilyNotificationType.GROUP_MEMBERSHIP_APPROVED,
                FamilyNotificationType.GROUP_MEMBERSHIP_DENIED,
                FamilyNotificationType.GROUP_MEMBERSHIP_ADDED,
                FamilyNotificationType.GROUP_MEMBER_JOINED,
                FamilyNotificationType.GROUP_MEMBERSHIP_LEFT,
            ]:
                helper = GroupMembershipNotificationHelper(
                    request_id=request_id,
                    stage=STAGE,
                    table_name=TABLE_NAME,
                    notification_queue_url=NOTIFICATION_QUEUE_URL,
                )
                helper.process_notification(notification_type, **message_kwargs)

            # Ticket notifications
            elif notification_type in [
                FamilyNotificationType.TICKET_CREATION_FAMILY,
                FamilyNotificationType.TICKET_CREATION_GROUP,
                FamilyNotificationType.TICKET_ASSIGNED,
                FamilyNotificationType.TICKET_COMMENT,
                FamilyNotificationType.TICKET_STATUS_CHANGED,
                FamilyNotificationType.TICKET_RESOLVED,
            ]:
                helper = TicketNotificationHelper(
                    request_id=request_id,
                    stage=STAGE,
                    table_name=TABLE_NAME,
                    notification_queue_url=NOTIFICATION_QUEUE_URL,
                )
                helper.process_notification(notification_type, **message_kwargs)

            # Grab request notifications
            elif notification_type in [
                FamilyNotificationType.GRAB_REQUEST_CREATED,
                FamilyNotificationType.GRAB_REQUEST_CLAIMED,
                FamilyNotificationType.GRAB_REQUEST_COMPLETED,
                FamilyNotificationType.GRAB_REQUEST_CONFIRMED,
                FamilyNotificationType.GRAB_REQUEST_CANCELLED,
                FamilyNotificationType.GRAB_ITEMS_CLAIMED,
                FamilyNotificationType.GRAB_ITEMS_COMPLETED,
                FamilyNotificationType.GRAB_ITEMS_CONFIRMED,
                FamilyNotificationType.GRAB_ITEMS_CANCELLED,
                FamilyNotificationType.GRAB_REVIEW_RECEIVED,
            ]:
                helper = GrabNotificationHelper(
                    request_id=request_id,
                    stage=STAGE,
                    table_name=TABLE_NAME,
                    notification_queue_url=NOTIFICATION_QUEUE_URL,
                )
                helper.process_notification(notification_type, **message_kwargs)

            elif notification_type == FamilyNotificationType.WELCOME:
                _process_welcome_notification(message, request_id)

            else:
                logger.error(
                    f"Unhandled notification type: {notification_type.value} in message {message_id}"
                )
                failed_message_ids.append(message_id)
                continue

            processed_count += 1
            logger.info(
                f"Successfully processed notification: {notification_type.value}",
            )

        except Exception as e:
            logger.error(
                f"Error processing message {message_id}: {str(e)}", exc_info=True
            )
            failed_message_ids.append(message_id)

    # Return batch item failures for SQS partial batch failure reporting
    result = {
        "batchItemFailures": [
            {"itemIdentifier": msg_id} for msg_id in failed_message_ids
        ]
    }

    logger.info(
        "Notification processing completed",
        extra={
            "processed": processed_count,
            "failed": len(failed_message_ids),
            "total": len(event.get("Records", [])),
        },
    )

    return result
