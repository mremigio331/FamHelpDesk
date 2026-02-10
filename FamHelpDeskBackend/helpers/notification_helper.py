import time
import uuid
import json
import os
from typing import Optional, List, Dict
from aws_lambda_powertools import Logger
from models.notification import NotificationModel, NotificationType
from exceptions.notification_exceptions import MissingNotificationArn
from pynamodb.exceptions import DoesNotExist
import boto3


class NotificationHelper:
    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
        notification_queue_url: str = None,
    ):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        NotificationModel.set_stage_and_table(stage, table_name, notification_queue_url)
        self.notification_queue_url = NotificationModel.Meta.notification_queue_url
        self.sqs_client = boto3.client("sqs")

    def create_notification(
        self,
        user_id: str,
        message: str,
        notification_type: NotificationType,
        family_id: Optional[str] = None,
        ticket_id: Optional[str] = None,
    ) -> dict:
        """
        Create a notification for a user.

        Args:
            user_id: The user to notify
            message: The notification message
            notification_type: Type of notification (NotificationType enum)
            family_id: Optional family ID if notification is family-related
            ticket_id: Optional ticket ID if notification is ticket-related

        Returns:
            Dict representation of the created notification
        """
        notification_id = str(uuid.uuid4())
        timestamp = int(time.time())

        pk = NotificationModel.create_pk(user_id)
        sk = NotificationModel.create_sk(notification_id)

        notification = NotificationModel(
            pk=pk,
            sk=sk,
            notification_id=notification_id,
            user_id=user_id,
            message=message,
            notification_type=notification_type.value,
            timestamp=timestamp,
            viewed=False,
        )

        if family_id:
            notification.family_id = family_id
        if ticket_id:
            notification.ticket_id = ticket_id

        notification.save()

        self.logger.info(
            f"Notification created for user {user_id}: {message} [{notification_type.value}]",
            extra={
                "notification_id": notification_id,
                "user_id": user_id,
                "notification_type": notification_type.value,
            },
        )

        return NotificationModel.clean_returned_notification(notification)

    def acknowledge_notification(self, user_id: str, notification_id: str) -> bool:
        """
        Mark a notification as viewed.

        Args:
            user_id: The user who owns the notification
            notification_id: The notification ID to acknowledge

        Returns:
            True if successfully acknowledged, False otherwise
        """
        pk = NotificationModel.create_pk(user_id)
        sk = NotificationModel.create_sk(notification_id)

        try:
            notification = NotificationModel.get(pk, sk)
            notification.viewed = True
            notification.save()

            self.logger.info(
                f"Notification {notification_id} for user {user_id} acknowledged.",
                extra={"notification_id": notification_id, "user_id": user_id},
            )
            return True
        except DoesNotExist:
            self.logger.warning(
                f"Notification {notification_id} for user {user_id} not found.",
                extra={"notification_id": notification_id, "user_id": user_id},
            )
            return False

    def get_notifications(
        self,
        user_id: str,
        viewed: Optional[bool] = None,
        limit: int = 50,
        last_evaluated_key: Optional[dict] = None,
        raw=False,
        resolve_entities: bool = True,
    ) -> dict:
        """
        Get notifications for a user with pagination support and optional entity resolution.

        Args:
            user_id: The user to get notifications for
            viewed: Optional filter - True for viewed only, False for unviewed only, None for all
            limit: Maximum number of notifications to return (default: 50)
            last_evaluated_key: Pagination token from previous request
            raw: If True, return raw NotificationModel objects instead of dicts
            resolve_entities: If True, resolve UUIDs to display names (default: True)

        Returns:
            Dict containing:
                - notifications: List of notification dictionaries, sorted by timestamp (newest first)
                - next_token: Pagination token for next page (None if no more results)
                - count: Number of notifications in current page
        """
        pk = NotificationModel.create_pk(user_id)

        query_kwargs = {
            "hash_key": pk,
            "range_key_condition": NotificationModel.sk.startswith("NOTIFICATION#"),
            "limit": limit * 2,  # Fetch more to account for filtering
        }

        if last_evaluated_key:
            query_kwargs["last_evaluated_key"] = last_evaluated_key

        result_iterator = NotificationModel.query(**query_kwargs)

        notifications = []
        notification_models = []
        next_key = None

        for notification in result_iterator:
            # Filter by viewed status if specified
            if viewed is not None and notification.viewed != viewed:
                continue

            if raw:
                notifications.append(notification)
            else:
                notification_models.append(notification)

            # Stop if we've reached the limit
            if len(notifications) >= limit or len(notification_models) >= limit:
                break

        # Get the last evaluated key for pagination
        if hasattr(result_iterator, "last_evaluated_key"):
            next_key = result_iterator.last_evaluated_key

        # Resolve entities if requested and not raw
        if not raw:
            if resolve_entities and notification_models:
                from helpers.entity_ref import EntityRefHelper

                entity_lookup = self._batch_lookup_entities(notification_models)
                notifications = []
                for n in notification_models:
                    notif_dict = NotificationModel.clean_returned_notification(n)
                    # Resolve UUIDs in the message
                    notif_dict["message"] = EntityRefHelper.resolve_uuids_in_text(
                        notif_dict["message"], entity_lookup
                    )
                    notifications.append(notif_dict)
            else:
                notifications = [
                    NotificationModel.clean_returned_notification(n)
                    for n in notification_models
                ]

            # Sort by timestamp, newest first
            notifications.sort(key=lambda x: x["timestamp"], reverse=True)

        self.logger.info(
            f"Retrieved {len(notifications)} notifications for user {user_id}",
            extra={
                "user_id": user_id,
                "notification_count": len(notifications),
                "viewed_filter": viewed,
                "has_more": next_key is not None,
                "resolve_entities": resolve_entities,
            },
        )

        return {
            "notifications": notifications,
            "next_token": next_key,
            "count": len(notifications),
        }

    def get_unviewed_count(self, user_id: str) -> int:
        """
        Get the count of unviewed notifications for a user.

        Args:
            user_id: The user to count notifications for

        Returns:
            Count of unviewed notifications
        """
        pk = NotificationModel.create_pk(user_id)

        count = 0
        for notification in NotificationModel.query(
            pk,
            NotificationModel.sk.startswith("NOTIFICATION#"),
        ):
            if not notification.viewed:
                count += 1

        self.logger.info(
            f"User {user_id} has {count} unviewed notifications",
            extra={"user_id": user_id, "unviewed_count": count},
        )

        return count

    def mark_all_as_viewed(self, user_id: str) -> int:
        """
        Mark all notifications for a user as viewed.

        Args:
            user_id: The user whose notifications to mark as viewed

        Returns:
            Count of notifications that were updated
        """
        pk = NotificationModel.create_pk(user_id)

        updated_count = 0
        for notification in NotificationModel.query(
            pk,
            NotificationModel.sk.startswith("NOTIFICATION#"),
        ):
            if not notification.viewed:
                notification.viewed = True
                notification.save()
                updated_count += 1

        self.logger.info(
            f"Marked {updated_count} notifications as viewed for user {user_id}",
            extra={"user_id": user_id, "updated_count": updated_count},
        )

        return updated_count

    def create_notification_async(
        self, notification_type: NotificationType, **kwargs
    ) -> bool:
        """
        Create a notification asynchronously by publishing to SQS.
        This method is lightweight and returns immediately while the actual
        notification creation happens in the background via Lambda.

        Args:
            notification_type: Type of notification (NotificationType enum)
            **kwargs: Optional parameters like user_id, family_id, ticket_id, group_id, queue_id, etc.

        Returns:
            bool: True if successfully published to SQS, False otherwise
        """
        if not self.notification_queue_url:
            self.logger.warning(
                "NOTIFICATION_QUEUE_URL not configured, skipping async notification"
            )
            raise MissingNotificationArn()

        try:
            # Create the notification payload
            notification_payload = {
                "notification_type": notification_type.value,
                **kwargs,
            }

            # Send message to SQS queue
            response = self.sqs_client.send_message(
                QueueUrl=self.notification_queue_url,
                MessageBody=json.dumps(notification_payload),
                MessageAttributes={
                    "notification_type": {
                        "StringValue": notification_type.value,
                        "DataType": "String",
                    }
                },
            )

            self.logger.info(
                f"Sent notification to SQS: [{notification_type.value}]",
                extra={
                    "notification_type": notification_type.value,
                    "message_id": response.get("MessageId"),
                    "queue_url": self.notification_queue_url,
                },
            )

            return True

        except Exception as e:
            self.logger.error(
                f"Failed to send notification to SQS: {str(e)}",
                extra={
                    "notification_type": notification_type.value,
                    **kwargs,
                    "error": str(e),
                },
            )
            return False

    def _batch_lookup_entities(
        self, notifications: List[NotificationModel]
    ) -> Dict[str, str]:
        """
        Batch lookup entity names using entity_lookup_index GSI.

        Process:
        1. Extract all UUIDs from all notification messages
        2. Use EntityRefHelper._batch_lookup_names to resolve UUIDs to names
        3. Return mapping for use in resolve_message

        Args:
            notifications: List of NotificationModel instances

        Returns:
            Dict mapping UUID -> display_name
        """
        from helpers.entity_ref import EntityRefHelper

        # Extract all UUIDs from all messages
        all_uuids = set()
        for notification in notifications:
            uuids = EntityRefHelper.extract_uuids_from_text(notification.message)
            all_uuids.update(uuids)

        # Filter out ticket_ids (stored separately, not resolved)
        ticket_ids = {n.ticket_id for n in notifications if n.ticket_id}
        entity_uuids = [uuid for uuid in all_uuids if uuid not in ticket_ids]

        if not entity_uuids:
            return {}

        # Use EntityRefHelper's batch lookup
        entity_lookup = EntityRefHelper._batch_lookup_names(entity_uuids)

        return entity_lookup

    def send_to_ios_push_queue(
        self,
        user_id: str,
        title: str,
        message: str,
        notification_type: str,
        family_id: str = None,
        ticket_id: str = None,
        group_id: str = None,
    ) -> bool:
        """
        Send iOS push notification request to SQS queue if user has iOS devices.

        This method:
        1. Checks if user has any enabled iOS devices (lightweight check)
        2. If yes, sends message to ios-push-queue
        3. Returns immediately (non-blocking)

        Args:
            user_id: Target user ID
            title: Notification title
            message: Notification message (already formatted/cleaned)
            notification_type: Type of notification
            family_id: Optional family context
            ticket_id: Optional ticket context for deep linking
            group_id: Optional group context for deep linking

        Returns:
            bool: True if message sent to queue, False if no devices or error
        """
        from helpers.ios_device_helper import iOSDeviceHelper

        # Lightweight check - does user have any enabled iOS devices?
        ios_helper = iOSDeviceHelper(
            request_id=(
                self.logger.get_correlation_id()
                if hasattr(self.logger, "get_correlation_id")
                else None
            ),
            stage=NotificationModel.Meta.stage,
            table_name=NotificationModel.Meta.table_name,
        )

        if not ios_helper.has_ios_devices(user_id):
            self.logger.debug(
                f"User {user_id} has no iOS devices, skipping push notification"
            )
            return False

        # Get iOS push queue URL from environment
        ios_push_queue_url = os.environ.get("IOS_PUSH_NOTIFICATION_QUEUE_URL")
        if not ios_push_queue_url:
            self.logger.warning("IOS_PUSH_NOTIFICATION_QUEUE_URL not configured")
            return False

        try:
            # Send message to iOS Push SQS Queue
            self.sqs_client.send_message(
                QueueUrl=ios_push_queue_url,
                MessageBody=json.dumps(
                    {
                        "user_id": user_id,
                        "title": title,
                        "message": message,
                        "notification_type": notification_type,
                        "family_id": family_id,
                        "ticket_id": ticket_id,
                        "group_id": group_id,
                        "timestamp": int(time.time()),
                    }
                ),
            )

            self.logger.info(
                f"Sent iOS push notification to queue for user {user_id}",
                extra={"user_id": user_id, "notification_type": notification_type},
            )
            return True

        except Exception as e:
            self.logger.error(
                f"Failed to send iOS push notification to queue: {str(e)}",
                extra={"user_id": user_id, "error": str(e)},
            )
            return False

    def send_ios_push_notification(
        self,
        user_id: str,
        title: str,
        message: str,
        notification_type: str,
        data: dict = None,
    ) -> dict:
        """
        Send push notifications to all user's enabled iOS devices.

        This method is called by ios_push_processor Lambda.
        Settings check already happened in notification_processor before queuing.

        Args:
            user_id: Target user ID
            title: Notification title
            message: Notification message (already formatted/cleaned)
            notification_type: Type of notification
            data: Custom data payload for deep linking

        Returns:
            Dictionary with success/failure counts:
            {
                "success": int,      # Number of successful deliveries
                "failed": int,       # Number of failed deliveries
                "disabled": int,     # Number of devices disabled due to invalid tokens
            }
            OR
            {
                "skipped": True,
                "reason": str        # Reason for skipping (e.g., "no_devices")
            }
        """
        from helpers.ios_device_helper import iOSDeviceHelper
        from clients.apns_client import APNsClient

        # Query all enabled devices
        ios_helper = iOSDeviceHelper(
            request_id=(
                self.logger.get_correlation_id()
                if hasattr(self.logger, "get_correlation_id")
                else None
            ),
            stage=NotificationModel.Meta.stage,
            table_name=NotificationModel.Meta.table_name,
        )
        devices = ios_helper.get_user_devices(user_id, enabled_only=True)

        if not devices:
            self.logger.info(
                f"No enabled devices found for user {user_id}",
                extra={"user_id": user_id},
            )
            return {"skipped": True, "reason": "no_devices"}

        # Group devices by environment
        sandbox_devices = [d for d in devices if d.environment == "sandbox"]
        production_devices = [d for d in devices if d.environment == "production"]

        self.logger.info(
            f"Sending push notifications to {len(devices)} devices for user {user_id}",
            extra={
                "user_id": user_id,
                "total_devices": len(devices),
                "sandbox_devices": len(sandbox_devices),
                "production_devices": len(production_devices),
            },
        )

        # Track results
        results = {"success": 0, "failed": 0, "disabled": 0}

        # Send to each environment
        for device_list, env in [
            (sandbox_devices, "sandbox"),
            (production_devices, "production"),
        ]:
            if not device_list:
                continue

            try:
                # Create APNs client for this environment
                client = APNsClient(
                    environment=env,
                    stage=NotificationModel.Meta.stage,
                    request_id=(
                        self.logger.get_correlation_id()
                        if hasattr(self.logger, "get_correlation_id")
                        else None
                    ),
                )

                # Send to each device in this environment
                for device in device_list:
                    try:
                        response = self._send_with_retry(
                            client=client,
                            device_token=device.apns_token,
                            title=title,
                            body=message,
                            data=data,
                        )

                        if response.success:
                            results["success"] += 1
                            self.logger.info(
                                f"Successfully sent push notification to device {device.device_id}",
                                extra={
                                    "user_id": user_id,
                                    "device_id": device.device_id,
                                    "environment": env,
                                },
                            )
                        elif response.is_invalid_token():
                            # Disable device with invalid token
                            ios_helper.disable_device(
                                user_id=user_id,
                                device_id=device.device_id,
                                reason=f"APNs error: {response.error_reason}",
                            )
                            results["disabled"] += 1
                            self.logger.warning(
                                f"Disabled device {device.device_id} due to invalid token",
                                extra={
                                    "user_id": user_id,
                                    "device_id": device.device_id,
                                    "error_reason": response.error_reason,
                                },
                            )
                        else:
                            results["failed"] += 1
                            self.logger.warning(
                                f"Failed to send push notification to device {device.device_id}",
                                extra={
                                    "user_id": user_id,
                                    "device_id": device.device_id,
                                    "error_reason": response.error_reason,
                                    "status_code": response.status_code,
                                },
                            )

                    except Exception as e:
                        results["failed"] += 1
                        self.logger.error(
                            f"Exception sending push notification to device {device.device_id}: {str(e)}",
                            extra={
                                "user_id": user_id,
                                "device_id": device.device_id,
                                "error": str(e),
                            },
                        )

            except Exception as e:
                # Failed to create APNs client for this environment
                self.logger.error(
                    f"Failed to create APNs client for {env} environment: {str(e)}",
                    extra={"environment": env, "error": str(e)},
                )
                # Mark all devices in this environment as failed
                results["failed"] += len(device_list)

        return results

    def _send_with_retry(
        self,
        client,
        device_token: str,
        title: str,
        body: str,
        data: dict,
        max_retries: int = 3,
    ):
        """
        Send notification with exponential backoff retry.

        Only retries temporary errors (500, 503) and rate limits (429).
        Permanent errors (400, 403, 410, 413) are not retried.

        Args:
            client: APNsClient instance
            device_token: Device token
            title: Notification title
            body: Notification body
            data: Custom data
            max_retries: Maximum retry attempts (default: 3)

        Returns:
            Final APNsResponse
        """
        for attempt in range(max_retries):
            response = client.send_notification(
                device_token=device_token,
                title=title,
                body=body,
                data=data,
            )

            if response.success:
                return response

            # Check if error is retryable
            if not response.is_temporary_error() and not response.is_rate_limited():
                # Permanent error, don't retry
                self.logger.info(
                    f"Permanent error, not retrying (attempt {attempt + 1}/{max_retries})",
                    extra={
                        "status_code": response.status_code,
                        "error_reason": response.error_reason,
                        "attempt": attempt + 1,
                    },
                )
                return response

            # Exponential backoff for retryable errors
            if attempt < max_retries - 1:
                sleep_time = 2**attempt  # 1s, 2s, 4s
                self.logger.info(
                    f"Retryable error, waiting {sleep_time}s before retry "
                    f"(attempt {attempt + 1}/{max_retries})",
                    extra={
                        "status_code": response.status_code,
                        "error_reason": response.error_reason,
                        "sleep_time": sleep_time,
                        "attempt": attempt + 1,
                    },
                )
                time.sleep(sleep_time)
            else:
                self.logger.warning(
                    f"Max retries reached (attempt {attempt + 1}/{max_retries})",
                    extra={
                        "status_code": response.status_code,
                        "error_reason": response.error_reason,
                        "attempt": attempt + 1,
                    },
                )

        return response
