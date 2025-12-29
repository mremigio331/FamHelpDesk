import time
import uuid
from typing import Optional
from aws_lambda_powertools import Logger
from models.notification import NotificationModel, NotificationType
from pynamodb.exceptions import DoesNotExist


class NotificationHelper:
    def __init__(self, request_id: str):
        self.logger = Logger()
        self.logger.append_keys(request_id=request_id)

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
    ) -> dict:
        """
        Get notifications for a user with pagination support.

        Args:
            user_id: The user to get notifications for
            viewed: Optional filter - True for viewed only, False for unviewed only, None for all
            limit: Maximum number of notifications to return (default: 50)
            last_evaluated_key: Pagination token from previous request

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
        next_key = None

        for notification in result_iterator:
            # Filter by viewed status if specified
            if viewed is not None and notification.viewed != viewed:
                continue

            notifications.append(
                NotificationModel.clean_returned_notification(notification)
            )

            # Stop if we've reached the limit
            if len(notifications) >= limit:
                break

        # Get the last evaluated key for pagination
        if hasattr(result_iterator, "last_evaluated_key"):
            next_key = result_iterator.last_evaluated_key

        # Sort by timestamp, newest first
        notifications.sort(key=lambda x: x["timestamp"], reverse=True)

        self.logger.info(
            f"Retrieved {len(notifications)} notifications for user {user_id}",
            extra={
                "user_id": user_id,
                "notification_count": len(notifications),
                "viewed_filter": viewed,
                "has_more": next_key is not None,
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
