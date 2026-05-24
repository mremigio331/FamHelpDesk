from aws_lambda_powertools import Logger

from helpers.notification_helper import NotificationHelper
from helpers.ios_notification_helper import iOSNotificationHelper
from helpers.family_notification_settings_helper import FamilyNotificationSettingsHelper
from helpers.family_membership_helper import FamilyMembershipHelper
from models.family_notification_settings import FamilyNotificationType


class GrabNotificationHelper:
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
        self.notification_helper = NotificationHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )
        self.ios_notification_helper = iOSNotificationHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
        )
        self.family_settings_helper = FamilyNotificationSettingsHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )
        self.family_membership_helper = FamilyMembershipHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )

    def process_notification(self, notification_type: FamilyNotificationType, **kwargs):
        self.logger.info(f"Processing grab notification: {notification_type}")
        try:
            if notification_type == FamilyNotificationType.GRAB_REQUEST_CREATED:
                self._process_grab_request_created(**kwargs)
            elif notification_type == FamilyNotificationType.GRAB_REQUEST_CLAIMED:
                self._process_grab_request_claimed(**kwargs)
            elif notification_type == FamilyNotificationType.GRAB_REQUEST_COMPLETED:
                self._process_grab_request_completed(**kwargs)
            elif notification_type == FamilyNotificationType.GRAB_REQUEST_CONFIRMED:
                self._process_grab_request_confirmed(**kwargs)
            elif notification_type == FamilyNotificationType.GRAB_REQUEST_CANCELLED:
                self._process_grab_request_cancelled(**kwargs)
            elif notification_type == FamilyNotificationType.GRAB_ITEMS_CLAIMED:
                self._process_grab_items_claimed(**kwargs)
            elif notification_type == FamilyNotificationType.GRAB_ITEMS_COMPLETED:
                self._process_grab_items_completed(**kwargs)
            elif notification_type == FamilyNotificationType.GRAB_ITEMS_CONFIRMED:
                self._process_grab_items_confirmed(**kwargs)
            elif notification_type == FamilyNotificationType.GRAB_ITEMS_CANCELLED:
                self._process_grab_items_cancelled(**kwargs)
            elif notification_type == FamilyNotificationType.GRAB_REVIEW_RECEIVED:
                self._process_grab_review_received(**kwargs)
            elif notification_type == FamilyNotificationType.GRAB_PICKUP_PHOTO:
                self._process_grab_pickup_photo(**kwargs)
            self.logger.info(f"Successfully processed {notification_type}")
        except Exception as e:
            self.logger.error(f"Error processing {notification_type}: {e}")
            raise

    def _process_grab_request_created(self, family_id, request_id, requestor_id):
        """
        Process GRAB_REQUEST_CREATED notification.
        Recipients: All family members EXCEPT the requestor.
        Setting check: grab_request_created enabled.
        """
        self.logger.info(
            f"Processing grab request created notification for request {request_id} in family {family_id}"
        )

        all_members = self.family_membership_helper.get_all_members(family_id)
        notification_type = FamilyNotificationType.GRAB_REQUEST_CREATED

        for member in all_members:
            if member["user_id"] == requestor_id:
                continue

            is_notification_enabled = (
                self.family_settings_helper.is_notification_enabled(
                    user_id=member["user_id"],
                    family_id=family_id,
                    notification_type=notification_type,
                )
            )

            if is_notification_enabled:
                message = f"{requestor_id} created a new Grab Request in {family_id}."
                self.notification_helper.create_notification(
                    user_id=member["user_id"],
                    message=message,
                    notification_type=notification_type,
                    family_id=family_id,
                )

                self.ios_notification_helper.send_ios_push_notification(
                    user_id=member["user_id"],
                    title="New Grab Request",
                    message=message,
                    notification_type=notification_type.value,
                    data={"request_id": request_id, "family_id": family_id},
                )

    def _process_grab_request_claimed(
        self, family_id, request_id, requestor_id, claimer_id
    ):
        """
        Process GRAB_REQUEST_CLAIMED notification.
        Recipients: Only the requestor.
        Setting check: grab_request_updates enabled.
        """
        self.logger.info(
            f"Processing grab request claimed notification for request {request_id}"
        )

        notification_type = FamilyNotificationType.GRAB_REQUEST_CLAIMED

        is_notification_enabled = self.family_settings_helper.is_notification_enabled(
            user_id=requestor_id,
            family_id=family_id,
            notification_type=notification_type,
        )

        if is_notification_enabled:
            message = f"{claimer_id} claimed your Grab Request in {family_id}."
            self.notification_helper.create_notification(
                user_id=requestor_id,
                message=message,
                notification_type=notification_type,
                family_id=family_id,
            )

            self.ios_notification_helper.send_ios_push_notification(
                user_id=requestor_id,
                title="Grab Request Claimed",
                message=message,
                notification_type=notification_type.value,
                data={"request_id": request_id, "family_id": family_id},
            )

    def _process_grab_request_completed(
        self, family_id, request_id, requestor_id, claimer_id
    ):
        """
        Process GRAB_REQUEST_COMPLETED notification.
        Recipients: Only the requestor.
        Setting check: grab_request_updates enabled.
        """
        self.logger.info(
            f"Processing grab request completed notification for request {request_id}"
        )

        notification_type = FamilyNotificationType.GRAB_REQUEST_COMPLETED

        is_notification_enabled = self.family_settings_helper.is_notification_enabled(
            user_id=requestor_id,
            family_id=family_id,
            notification_type=notification_type,
        )

        if is_notification_enabled:
            message = f"{claimer_id} completed your Grab Request in {family_id}. Please confirm delivery."
            self.notification_helper.create_notification(
                user_id=requestor_id,
                message=message,
                notification_type=notification_type,
                family_id=family_id,
            )

            self.ios_notification_helper.send_ios_push_notification(
                user_id=requestor_id,
                title="Grab Request Completed",
                message=message,
                notification_type=notification_type.value,
                data={"request_id": request_id, "family_id": family_id},
            )

    def _process_grab_request_confirmed(
        self, family_id, request_id, requestor_id, claimer_id
    ):
        """
        Process GRAB_REQUEST_CONFIRMED notification.
        Recipients: Only the claimer.
        Setting check: grab_request_updates enabled.
        """
        self.logger.info(
            f"Processing grab request confirmed notification for request {request_id}"
        )

        notification_type = FamilyNotificationType.GRAB_REQUEST_CONFIRMED

        is_notification_enabled = self.family_settings_helper.is_notification_enabled(
            user_id=claimer_id,
            family_id=family_id,
            notification_type=notification_type,
        )

        if is_notification_enabled:
            message = f"{requestor_id} confirmed delivery of Grab Request in {family_id}. Embolecs transferred!"
            self.notification_helper.create_notification(
                user_id=claimer_id,
                message=message,
                notification_type=notification_type,
                family_id=family_id,
            )

            self.ios_notification_helper.send_ios_push_notification(
                user_id=claimer_id,
                title="Grab Request Confirmed",
                message=message,
                notification_type=notification_type.value,
                data={"request_id": request_id, "family_id": family_id},
            )

    def _process_grab_request_cancelled(
        self, family_id, request_id, requestor_id, claimer_id, cancelled_by
    ):
        """
        Process GRAB_REQUEST_CANCELLED notification.
        Recipients: The OTHER party (if cancelled_by == requestor, notify claimer; vice versa).
        Setting check: grab_request_updates enabled.
        """
        self.logger.info(
            f"Processing grab request cancelled notification for request {request_id}"
        )

        notification_type = FamilyNotificationType.GRAB_REQUEST_CANCELLED

        # Determine recipient: notify the other party
        if cancelled_by == requestor_id:
            recipient_id = claimer_id
        else:
            recipient_id = requestor_id

        # If there's no recipient (e.g., cancelled before anyone claimed), skip
        if not recipient_id:
            self.logger.info("No recipient for cancellation notification, skipping")
            return

        is_notification_enabled = self.family_settings_helper.is_notification_enabled(
            user_id=recipient_id,
            family_id=family_id,
            notification_type=notification_type,
        )

        if is_notification_enabled:
            message = f"{cancelled_by} cancelled a Grab Request in {family_id}."
            self.notification_helper.create_notification(
                user_id=recipient_id,
                message=message,
                notification_type=notification_type,
                family_id=family_id,
            )

            self.ios_notification_helper.send_ios_push_notification(
                user_id=recipient_id,
                title="Grab Request Cancelled",
                message=message,
                notification_type=notification_type.value,
                data={"request_id": request_id, "family_id": family_id},
            )

    def _process_grab_items_claimed(
        self, family_id, request_id, requestor_id, claimer_id, item_names
    ):
        """
        Process GRAB_ITEMS_CLAIMED notification.
        Recipients: Only the requestor.
        Setting check: grab_request_updates enabled.
        """
        self.logger.info(
            f"Processing grab items claimed notification for request {request_id}"
        )

        notification_type = FamilyNotificationType.GRAB_ITEMS_CLAIMED

        is_notification_enabled = self.family_settings_helper.is_notification_enabled(
            user_id=requestor_id,
            family_id=family_id,
            notification_type=notification_type,
        )

        if is_notification_enabled:
            items_text = ", ".join(item_names[:3])
            if len(item_names) > 3:
                items_text += f" and {len(item_names) - 3} more"
            message = f"{claimer_id} claimed items: {items_text}"
            self.notification_helper.create_notification(
                user_id=requestor_id,
                message=message,
                notification_type=notification_type,
                family_id=family_id,
            )

            self.ios_notification_helper.send_ios_push_notification(
                user_id=requestor_id,
                title="Items Claimed",
                message=message,
                notification_type=notification_type.value,
                data={"request_id": request_id, "family_id": family_id},
            )

    def _process_grab_items_completed(
        self, family_id, request_id, requestor_id, claimer_id, item_names
    ):
        """
        Process GRAB_ITEMS_COMPLETED notification.
        Recipients: Only the requestor.
        Setting check: grab_request_updates enabled.
        """
        self.logger.info(
            f"Processing grab items completed notification for request {request_id}"
        )

        notification_type = FamilyNotificationType.GRAB_ITEMS_COMPLETED

        is_notification_enabled = self.family_settings_helper.is_notification_enabled(
            user_id=requestor_id,
            family_id=family_id,
            notification_type=notification_type,
        )

        if is_notification_enabled:
            items_text = ", ".join(item_names[:3])
            if len(item_names) > 3:
                items_text += f" and {len(item_names) - 3} more"
            message = (
                f"{claimer_id} completed items: {items_text}. Please confirm delivery."
            )
            self.notification_helper.create_notification(
                user_id=requestor_id,
                message=message,
                notification_type=notification_type,
                family_id=family_id,
            )

            self.ios_notification_helper.send_ios_push_notification(
                user_id=requestor_id,
                title="Items Completed",
                message=message,
                notification_type=notification_type.value,
                data={"request_id": request_id, "family_id": family_id},
            )

    def _process_grab_items_confirmed(
        self, family_id, request_id, requestor_id, claimer_id, item_names, total_earned
    ):
        """
        Process GRAB_ITEMS_CONFIRMED notification.
        Recipients: Only the claimer whose items were confirmed.
        Setting check: grab_request_updates enabled.
        """
        self.logger.info(
            f"Processing grab items confirmed notification for request {request_id}, claimer {claimer_id}"
        )

        notification_type = FamilyNotificationType.GRAB_ITEMS_CONFIRMED

        is_notification_enabled = self.family_settings_helper.is_notification_enabled(
            user_id=claimer_id,
            family_id=family_id,
            notification_type=notification_type,
        )

        if is_notification_enabled:
            items_text = ", ".join(item_names[:3])
            if len(item_names) > 3:
                items_text += f" and {len(item_names) - 3} more"
            message = f"Your items confirmed: {items_text}. You earned {total_earned} Embolecs!"
            self.notification_helper.create_notification(
                user_id=claimer_id,
                message=message,
                notification_type=notification_type,
                family_id=family_id,
            )

            self.ios_notification_helper.send_ios_push_notification(
                user_id=claimer_id,
                title="Items Confirmed",
                message=message,
                notification_type=notification_type.value,
                data={"request_id": request_id, "family_id": family_id},
            )

    def _process_grab_items_cancelled(
        self, family_id, request_id, requestor_id, cancelled_by, item_names
    ):
        """
        Process GRAB_ITEMS_CANCELLED notification.
        Recipients: The other party (if cancelled_by == requestor, notify claimers; otherwise notify requestor).
        Setting check: grab_request_updates enabled.
        """
        self.logger.info(
            f"Processing grab items cancelled notification for request {request_id}"
        )

        notification_type = FamilyNotificationType.GRAB_ITEMS_CANCELLED

        # Determine recipient: notify the other party
        if cancelled_by == requestor_id:
            # Requestor cancelled — we don't have a specific claimer here, skip
            # (the items may have been unclaimed OPEN items)
            self.logger.info("Requestor cancelled items, no specific claimer to notify")
            return
        else:
            # Claimer cancelled their own items — notify the requestor
            recipient_id = requestor_id

        is_notification_enabled = self.family_settings_helper.is_notification_enabled(
            user_id=recipient_id,
            family_id=family_id,
            notification_type=notification_type,
        )

        if is_notification_enabled:
            items_text = ", ".join(item_names[:3])
            if len(item_names) > 3:
                items_text += f" and {len(item_names) - 3} more"
            message = f"{cancelled_by} cancelled items: {items_text}"
            self.notification_helper.create_notification(
                user_id=recipient_id,
                message=message,
                notification_type=notification_type,
                family_id=family_id,
            )

            self.ios_notification_helper.send_ios_push_notification(
                user_id=recipient_id,
                title="Items Cancelled",
                message=message,
                notification_type=notification_type.value,
                data={"request_id": request_id, "family_id": family_id},
            )

    def _process_grab_review_received(
        self,
        family_id,
        request_id,
        requestor_id,
        claimer_id,
        request_title,
        average_rating,
    ):
        """
        Process GRAB_REVIEW_RECEIVED notification.
        Recipients: Only the claimer (the person being reviewed).
        Setting check: grab_request_updates enabled (uses GRAB_REQUEST_CONFIRMED type).
        """
        self.logger.info(
            f"Processing grab review received notification for request {request_id}"
        )

        notification_type = FamilyNotificationType.GRAB_REQUEST_CONFIRMED

        is_notification_enabled = self.family_settings_helper.is_notification_enabled(
            user_id=claimer_id,
            family_id=family_id,
            notification_type=notification_type,
        )

        if is_notification_enabled:
            message = f"You received a review on '{request_title}' with an average rating of {average_rating} stars."
            self.notification_helper.create_notification(
                user_id=claimer_id,
                message=message,
                notification_type=FamilyNotificationType.GRAB_REVIEW_RECEIVED,
                family_id=family_id,
            )

            self.ios_notification_helper.send_ios_push_notification(
                user_id=claimer_id,
                title="Grab Review Received",
                message=message,
                notification_type=FamilyNotificationType.GRAB_REVIEW_RECEIVED.value,
                data={"request_id": request_id, "family_id": family_id},
            )

    def _process_grab_pickup_photo(
        self, family_id, request_id, requestor_id, claimer_id, item_name
    ):
        """
        Process GRAB_PICKUP_PHOTO notification.
        Recipients: Only the requestor.
        Setting check: grab_request_updates enabled.
        Message format: "{claimer_id} picked up {item_name} from your order"
        """
        self.logger.info(
            f"Processing grab pickup photo notification for request {request_id}"
        )

        notification_type = FamilyNotificationType.GRAB_PICKUP_PHOTO

        is_notification_enabled = self.family_settings_helper.is_notification_enabled(
            user_id=requestor_id,
            family_id=family_id,
            notification_type=notification_type,
        )

        if is_notification_enabled:
            message = f"{claimer_id} picked up {item_name} from your order"
            self.notification_helper.create_notification(
                user_id=requestor_id,
                message=message,
                notification_type=notification_type,
                family_id=family_id,
            )

            self.ios_notification_helper.send_ios_push_notification(
                user_id=requestor_id,
                title="Pickup Photo",
                message=message,
                notification_type=notification_type.value,
                data={"request_id": request_id, "family_id": family_id},
            )
