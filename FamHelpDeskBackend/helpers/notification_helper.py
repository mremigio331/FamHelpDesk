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
