"""
Lambda function to process notification events from SNS.
This function receives notification events and routes them to the appropriate
notification helper based on the notification type.
"""

import json
import os
from typing import Dict, Any

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext

from helpers.notification_helpers import (
    FamilyMembershipNotificationHelper,
    GroupMembershipNotificationHelper,
    TicketNotificationHelper,
)
from models.family_notification_settings import FamliyNotificationType
from constants.services import NOTIFICATION_SERVICE

# Initialize logger with service name
logger = Logger(service=NOTIFICATION_SERVICE, level="INFO")

# Environment variables
STAGE = os.environ.get("STAGE", "dev")
TABLE_NAME = os.environ.get("TABLE_NAME")
NOTIFICATION_QUEUE_URL = os.environ.get("NOTIFICATION_QUEUE_URL")


def lambda_handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    """
    Process notification events from SQS.
    Routes notifications to appropriate helper based on notification type.

    Args:
        event: SQS event containing notification data
        context: Lambda context

    Returns:
        Dict with processing results
    """
    logger.info("Processing notification events from SQS", extra={"event": event})

    processed_count = 0
    failed_count = 0

    try:
        # Process each SQS record
        for record in event.get("Records", []):
            try:
                # Parse SQS message body
                message = json.loads(record["body"])

                # Extract notification type
                notification_type_str = message.get("notification_type")
                if not notification_type_str:
                    raise ValueError("Missing notification_type in message")

                # Convert to enum
                try:
                    notification_type = FamliyNotificationType(notification_type_str)
                except ValueError:
                    logger.error(f"Invalid notification type: {notification_type_str}")
                    raise

                # Route to appropriate helper based on notification type
                request_id = context.aws_request_id

                # Family membership notifications
                if notification_type in [
                    FamliyNotificationType.NEW_FAMILY_CREATION,
                    FamliyNotificationType.FAMILY_MEMBERSHIP_REQUEST,
                    FamliyNotificationType.FAMILY_MEMBERSHIP_APPROVED,
                    FamliyNotificationType.FAMILY_MEMBERSHIP_DENIED,
                    FamliyNotificationType.FAMILY_MEMBERSHIP_INVITATION,
                    FamliyNotificationType.FAMILY_MEMBER_JOINED,
                    FamliyNotificationType.FAMILY_MEMBERSHIP_LEFT,
                    FamliyNotificationType.FAMILY_MEMBERSHIP_REQUEST,
                    FamliyNotificationType.NEW_FAMILY_MEMEBER,
                    FamliyNotificationType.WELCOME_TO_FAMILY,
                ]:
                    helper = FamilyMembershipNotificationHelper(
                        request_id=request_id,
                        stage=STAGE,
                        table_name=TABLE_NAME,
                        notification_topic_arn=NOTIFICATION_TOPIC_ARN,
                    )
                    helper.process_notification(notification_type, **message)

                # Group membership notifications
                elif notification_type in [
                    FamliyNotificationType.NEW_GROUP_CREATION,
                    FamliyNotificationType.GROUP_MEMBERSHIP_REQUEST,
                    FamliyNotificationType.GROUP_MEMBERSHIP_APPROVED,
                    FamliyNotificationType.GROUP_MEMBERSHIP_DENIED,
                    FamliyNotificationType.GROUP_MEMBERSHIP_ADDED,
                    FamliyNotificationType.GROUP_MEMBER_JOINED,
                    FamliyNotificationType.GROUP_MEMBERSHIP_LEFT,
                ]:
                    helper = GroupMembershipNotificationHelper(
                        request_id=request_id,
                        stage=STAGE,
                        table_name=TABLE_NAME,
                        notification_topic_arn=NOTIFICATION_TOPIC_ARN,
                    )
                    helper.process_notification(notification_type, **message)

                # Ticket notifications
                elif notification_type in [
                    FamliyNotificationType.TICKET_CREATION_FAMILY,
                    FamliyNotificationType.TICKET_CREATION_GROUP,
                    FamliyNotificationType.TICKET_ASSIGNED,
                    FamliyNotificationType.TICKET_COMMENT,
                    FamliyNotificationType.TICKET_STATUS_CHANGED,
                ]:
                    helper = TicketNotificationHelper(
                        request_id=request_id,
                        stage=STAGE,
                        table_name=TABLE_NAME,
                        notification_topic_arn=NOTIFICATION_TOPIC_ARN,
                    )
                    helper.process_notification(notification_type, **message)

                else:
                    logger.error(
                        f"Unhandled notification type: {notification_type.value}"
                    )
                    raise ValueError(
                        f"Unhandled notification type: {notification_type.value}"
                    )

                processed_count += 1
                logger.info(
                    f"Successfully processed notification: {notification_type.value}",
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

    result = {
        "statusCode": 200,
        "processed": processed_count,
        "failed": failed_count,
    }

    logger.info("Notification processing completed", extra=result)

    return result
