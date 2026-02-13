import time
import json
import os
from typing import Optional, Any
from uuid import UUID
from aws_lambda_powertools import Logger
from models.notification import NotificationModel
from helpers.ios_device_helper import iOSDeviceHelper
from helpers.entity_ref import EntityRefHelper
from clients.apns_client import APNsClient
import boto3


class iOSNotificationHelper:
    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
    ):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.stage = stage
        self.table_name = table_name
        self.sqs_client = boto3.client("sqs")

    @staticmethod
    def _convert_uuids_to_strings(data: Any) -> Any:
        """
        Recursively convert all UUID objects to strings in a data structure.
        This ensures JSON serialization works properly for iOS push notifications.

        Args:
            data: Can be a dict, list, UUID, or any other type

        Returns:
            The same data structure with all UUIDs converted to strings
        """
        if isinstance(data, UUID):
            return str(data)
        elif isinstance(data, dict):
            return {
                key: iOSNotificationHelper._convert_uuids_to_strings(value)
                for key, value in data.items()
            }
        elif isinstance(data, list):
            return [
                iOSNotificationHelper._convert_uuids_to_strings(item) for item in data
            ]
        else:
            return data

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
        # Lightweight check - does user have any enabled iOS devices?
        ios_helper = iOSDeviceHelper(
            request_id=(
                self.logger.get_correlation_id()
                if hasattr(self.logger, "get_correlation_id")
                else None
            ),
            stage=self.stage,
            table_name=self.table_name,
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
            # Prepare message data and convert any UUIDs to strings
            message_data = {
                "user_id": user_id,
                "title": title,
                "message": message,
                "notification_type": notification_type,
                "family_id": family_id,
                "ticket_id": ticket_id,
                "group_id": group_id,
                "timestamp": int(time.time()),
            }

            # Convert UUIDs to strings for JSON serialization
            message_data = self._convert_uuids_to_strings(message_data)

            # Send message to iOS Push SQS Queue
            self.sqs_client.send_message(
                QueueUrl=ios_push_queue_url,
                MessageBody=json.dumps(message_data),
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

    def _get_device_attr(self, device, attr_name: str):
        """
        Safely get device attribute, handling both object and dict patterns.

        Args:
            device: Device object or dictionary
            attr_name: Attribute name to retrieve

        Returns:
            Attribute value or None
        """
        if hasattr(device, attr_name):
            return getattr(device, attr_name)
        elif isinstance(device, dict):
            return device.get(attr_name)
        return None

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
                "rate_limited": int, # Number of rate limit errors (429)
                "server_errors": int # Number of server errors (500, 503)
            }
            OR
            {
                "skipped": True,
                "reason": str        # Reason for skipping (e.g., "no_devices")
            }
        """
        # Resolve UUIDs in title and message
        combined_text = f"{title} {message}"
        uuids = EntityRefHelper.extract_uuids_from_text(combined_text)

        if uuids:
            entity_lookup = EntityRefHelper._batch_lookup_names(uuids)
            title = EntityRefHelper.resolve_uuids_in_text(title, entity_lookup)
            message = EntityRefHelper.resolve_uuids_in_text(message, entity_lookup)

        devices = self._query_user_devices(user_id)
        if not devices:
            return {"skipped": True, "reason": "no_devices"}

        sandbox_devices, production_devices = self._group_devices_by_environment(
            devices, user_id
        )

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
        results = {
            "success": 0,
            "failed": 0,
            "disabled": 0,
            "rate_limited": 0,
            "server_errors": 0,
        }

        # Send to each environment
        for device_list, env in [
            (sandbox_devices, "sandbox"),
            (production_devices, "production"),
        ]:
            if device_list:
                self._send_to_environment(
                    device_list=device_list,
                    env=env,
                    user_id=user_id,
                    title=title,
                    message=message,
                    notification_type=notification_type,
                    data=data,
                    results=results,
                )

        return results

    def _query_user_devices(self, user_id: str):
        """
        Query all enabled iOS devices for a user.

        Args:
            user_id: Target user ID

        Returns:
            List of device objects, or empty list if none found
        """
        ios_helper = iOSDeviceHelper(
            request_id=(
                self.logger.get_correlation_id()
                if hasattr(self.logger, "get_correlation_id")
                else None
            ),
            stage=self.stage,
            table_name=self.table_name,
        )
        devices = ios_helper.get_user_devices(user_id, enabled_only=True)

        if not devices:
            self.logger.info(
                f"No enabled devices found for user {user_id}",
                extra={"user_id": user_id},
            )
            return []

        # Log device details for debugging
        self.logger.info(
            f"Retrieved devices details",
            extra={
                "user_id": user_id,
                "device_count": len(devices),
                "device_types": [type(d).__name__ for d in devices],
            },
        )

        return devices

    def _group_devices_by_environment(self, devices, user_id: str) -> tuple:
        """
        Group devices by APNs environment (sandbox vs production).

        Args:
            devices: List of device objects
            user_id: For logging context

        Returns:
            Tuple of (sandbox_devices, production_devices)
        """
        sandbox_devices = [d for d in devices if d.environment == "sandbox"]
        production_devices = [d for d in devices if d.environment == "production"]
        return sandbox_devices, production_devices

    def _send_to_environment(
        self,
        device_list,
        env: str,
        user_id: str,
        title: str,
        message: str,
        notification_type: str,
        data: dict,
        results: dict,
    ):
        """
        Send notifications to all devices in a specific APNs environment.

        Args:
            device_list: List of devices for this environment
            env: Environment name (sandbox or production)
            user_id: Target user ID
            title: Notification title
            message: Notification message
            notification_type: Type of notification
            data: Custom data payload
            results: Results dict to update with counts
        """
        try:
            # Create APNs client for this environment
            client = APNsClient(
                environment=env,
                stage=self.stage,
                request_id=(
                    self.logger.get_correlation_id()
                    if hasattr(self.logger, "get_correlation_id")
                    else None
                ),
            )

            # Send to each device in this environment
            for device in device_list:
                self._process_device(
                    device=device,
                    client=client,
                    env=env,
                    user_id=user_id,
                    title=title,
                    message=message,
                    notification_type=notification_type,
                    data=data,
                    results=results,
                )

        except Exception as e:
            # Failed to create APNs client for this environment
            self.logger.error(
                f"Failed to create APNs client for {env} environment: {str(e)}",
                extra={"environment": env, "error": str(e)},
            )
            # Mark all devices in this environment as failed
            results["failed"] += len(device_list)

    def _process_device(
        self,
        device,
        client,
        env: str,
        user_id: str,
        title: str,
        message: str,
        notification_type: str,
        data: dict,
        results: dict,
    ):
        """
        Send a notification to a single device and track the result.

        Args:
            device: Device object to send to
            client: APNsClient instance for this environment
            env: Environment name (sandbox or production)
            user_id: Target user ID
            title: Notification title
            message: Notification message
            notification_type: Type of notification
            data: Custom data payload
            results: Results dict to update
        """
        try:
            device_token = self._get_device_attr(device, "apns_token")
            device_id = self._get_device_attr(device, "device_id")

            self.logger.info(
                f"Processing device",
                extra={
                    "user_id": user_id,
                    "device_type": type(device).__name__,
                    "device_id": device_id,
                    "device_token_type": (
                        type(device_token).__name__ if device_token else "None"
                    ),
                    "device_token_length": len(device_token) if device_token else 0,
                    "data_type": type(data).__name__ if data else "None",
                    "data": str(data) if data else "None",
                },
            )

            if not device_token or not device_id:
                self.logger.warning(f"Invalid device: missing token or ID")
                results["failed"] += 1
                return

            self.logger.info(
                f"About to call _send_with_retry",
                extra={
                    "user_id": user_id,
                    "device_id": device_id,
                    "device_token_type": type(device_token).__name__,
                    "title_type": type(title).__name__,
                    "body_type": type(message).__name__,
                    "data_type": type(data).__name__,
                    "data_is_dict": isinstance(data, dict),
                    "data_keys": list(data.keys()) if isinstance(data, dict) else None,
                },
            )

            response = self._send_with_retry(
                client=client,
                device_token=device_token,
                title=title,
                body=message,
                data=data,
            )

            self._handle_response(
                response=response,
                device=device,
                device_id=device_id,
                env=env,
                user_id=user_id,
                notification_type=notification_type,
                results=results,
            )

        except Exception as e:
            import traceback

            results["failed"] += 1
            device_id = (
                self._get_device_attr(device, "device_id") if device else "unknown"
            )
            device_token = (
                self._get_device_attr(device, "apns_token") if device else None
            )
            self.logger.error(
                f"Exception sending push notification to device {device_id}: {str(e)}",
                extra={
                    "user_id": user_id,
                    "device_id": device_id,
                    "device_type": type(device).__name__ if device else "unknown",
                    "device_token_type": (
                        type(device_token).__name__ if device_token else "None"
                    ),
                    "data_type": type(data).__name__ if data else "None",
                    "error": str(e),
                    "exception_type": type(e).__name__,
                    "traceback": traceback.format_exc(),
                },
            )

    def _handle_response(
        self,
        response,
        device,
        device_id: str,
        env: str,
        user_id: str,
        notification_type: str,
        results: dict,
    ):
        """
        Handle APNs response and update results accordingly.

        Args:
            response: APNsResponse object
            device: Device object
            device_id: Device ID
            env: Environment name
            user_id: Target user ID
            notification_type: Type of notification
            results: Results dict to update
        """
        from helpers.ios_device_helper import iOSDeviceHelper

        if response.success:
            results["success"] += 1
            self.logger.info(
                f"Successfully sent push notification to device {device_id}",
                extra={
                    "user_id": user_id,
                    "device_id": device_id,
                    "environment": env,
                    "notification_type": notification_type,
                },
            )
        elif response.is_invalid_token():
            # Disable device with invalid token
            ios_helper = iOSDeviceHelper(
                request_id=(
                    self.logger.get_correlation_id()
                    if hasattr(self.logger, "get_correlation_id")
                    else None
                ),
                stage=self.stage,
                table_name=self.table_name,
            )
            ios_helper.disable_device(
                user_id=user_id,
                device_id=device_id,
                reason=f"APNs error: {response.error_reason}",
            )
            results["disabled"] += 1
            self.logger.warning(
                f"Disabled device {device_id} due to invalid token",
                extra={
                    "user_id": user_id,
                    "device_id": device_id,
                    "environment": env,
                    "error_reason": response.error_reason,
                    "notification_type": notification_type,
                },
            )
        else:
            results["failed"] += 1

            # Track specific error types
            if response.is_rate_limited():
                results["rate_limited"] += 1
                self.logger.warning(
                    f"Rate limited when sending to device {device_id}",
                    extra={
                        "user_id": user_id,
                        "device_id": device_id,
                        "environment": env,
                        "status_code": response.status_code,
                        "notification_type": notification_type,
                    },
                )
            elif response.is_temporary_error():
                results["server_errors"] += 1
                self.logger.warning(
                    f"Server error when sending to device {device_id}",
                    extra={
                        "user_id": user_id,
                        "device_id": device_id,
                        "environment": env,
                        "status_code": response.status_code,
                        "error_reason": response.error_reason,
                        "notification_type": notification_type,
                    },
                )
            else:
                self.logger.warning(
                    f"Failed to send push notification to device {device_id}",
                    extra={
                        "user_id": user_id,
                        "device_id": device_id,
                        "environment": env,
                        "error_reason": response.error_reason,
                        "status_code": response.status_code,
                        "notification_type": notification_type,
                    },
                )

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
            self.logger.info(
                f"Attempt {attempt + 1}/{max_retries} to send notification",
                extra={
                    "attempt": attempt + 1,
                    "device_token_type": type(device_token).__name__,
                    "title_type": type(title).__name__,
                    "body_type": type(body).__name__,
                    "data_type": type(data).__name__ if data else "None",
                    "data_is_dict": isinstance(data, dict) if data else False,
                },
            )
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
