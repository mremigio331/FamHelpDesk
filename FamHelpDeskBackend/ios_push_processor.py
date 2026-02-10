import json
import os
from typing import Dict, Any

from aws_lambda_powertools import Logger, Metrics
from aws_lambda_powertools.metrics import MetricUnit
from aws_lambda_powertools.utilities.typing import LambdaContext

from helpers.notification_helper import NotificationHelper

# Initialize logger and metrics
logger = Logger()
metrics = Metrics(namespace="FamHelpDesk/Notifications")


@logger.inject_lambda_context
@metrics.log_metrics
def lambda_handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    """
    Process iOS push notification requests from SQS.

    Args:
        event: SQS event containing notification messages
        context: Lambda context

    Returns:
        Dictionary with processing results
    """
    # Get environment variables
    stage = os.environ.get("STAGE")
    table_name = os.environ.get("TABLE_NAME")

    if not table_name:
        logger.error("TABLE_NAME environment variable not set")
        raise ValueError("TABLE_NAME environment variable is required")

    # Initialize notification helper
    notification_helper = NotificationHelper(
        request_id=context.request_id if context else None,
        stage=stage,
        table_name=table_name,
    )

    # Track overall results
    total_processed = 0
    total_success = 0
    total_failed = 0
    total_skipped = 0

    # Process each SQS record
    for record in event.get("Records", []):
        try:
            # Parse message body
            message = json.loads(record["body"])

            user_id = message.get("user_id")
            title = message.get("title")
            message_text = message.get("message")
            notification_type = message.get("notification_type")
            family_id = message.get("family_id")
            ticket_id = message.get("ticket_id")
            group_id = message.get("group_id")

            # Validate required fields
            if not all([user_id, title, message_text, notification_type]):
                logger.warning(
                    "Missing required fields in message",
                    extra={
                        "user_id": user_id,
                        "has_title": bool(title),
                        "has_message": bool(message_text),
                        "has_notification_type": bool(notification_type),
                    },
                )
                total_failed += 1
                continue

            logger.info(
                f"Processing iOS push notification for user {user_id}",
                extra={
                    "user_id": user_id,
                    "notification_type": notification_type,
                    "family_id": family_id,
                    "ticket_id": ticket_id,
                    "group_id": group_id,
                },
            )

            # Send push notifications
            result = notification_helper.send_ios_push_notification(
                user_id=user_id,
                title=title,
                message=message_text,
                notification_type=notification_type,
                data={
                    "ticket_id": ticket_id,
                    "group_id": group_id,
                    "family_id": family_id,
                },
            )

            # Track results
            total_processed += 1

            if result.get("skipped"):
                total_skipped += 1
                logger.info(
                    f"Skipped push notification for user {user_id}: {result.get('reason')}",
                    extra={"user_id": user_id, "reason": result.get("reason")},
                )
            else:
                success_count = result.get("success", 0)
                failed_count = result.get("failed", 0)
                disabled_count = result.get("disabled", 0)

                total_success += success_count
                total_failed += failed_count

                logger.info(
                    f"iOS push results for user {user_id}: "
                    f"{success_count} success, {failed_count} failed, {disabled_count} disabled",
                    extra={
                        "user_id": user_id,
                        "success": success_count,
                        "failed": failed_count,
                        "disabled": disabled_count,
                    },
                )

                # Emit CloudWatch metrics
                metrics.add_metric(
                    name="PushNotificationsSent",
                    unit=MetricUnit.Count,
                    value=success_count,
                )
                metrics.add_metric(
                    name="PushNotificationsFailed",
                    unit=MetricUnit.Count,
                    value=failed_count,
                )
                metrics.add_metric(
                    name="DevicesDisabled",
                    unit=MetricUnit.Count,
                    value=disabled_count,
                )

        except json.JSONDecodeError as e:
            logger.error(
                f"Failed to parse SQS message body: {str(e)}",
                extra={"error": str(e), "record": record},
            )
            total_failed += 1

        except Exception as e:
            logger.error(
                f"Error processing iOS push notification: {str(e)}",
                extra={"error": str(e), "record": record},
            )
            total_failed += 1

    # Log summary
    logger.info(
        f"iOS push processor completed: {total_processed} processed, "
        f"{total_success} success, {total_failed} failed, {total_skipped} skipped",
        extra={
            "total_processed": total_processed,
            "total_success": total_success,
            "total_failed": total_failed,
            "total_skipped": total_skipped,
        },
    )

    return {
        "statusCode": 200,
        "body": {
            "processed": total_processed,
            "success": total_success,
            "failed": total_failed,
            "skipped": total_skipped,
        },
    }
