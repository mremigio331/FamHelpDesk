from models.ios_notifications import iOSDeviceTokenModel
from helpers.audit_helper import AuditHelper
from models.audit import AuditActions, AuditEntityTypes
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger
from typing import Optional, List


class iOSDeviceHelper:
    """
    Helper class for managing iOS device registrations for push notifications.

    This helper provides methods to create, retrieve, update, and delete
    iOS device tokens used for APNs push notifications.
    """

    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
    ):
        """
        Initialize the iOS Device Helper.

        Args:
            request_id: Optional request ID for logging context
            stage: Optional stage name (e.g., "Testing", "Production")
            table_name: Optional DynamoDB table name
        """
        self.logger = Logger()
        self.request_id = request_id
        if request_id:
            self.logger.append_keys(request_id=request_id)

        iOSDeviceTokenModel.set_stage_and_table(stage, table_name)
        self.audit_helper = AuditHelper(
            request_id=request_id, stage=stage, table_name=table_name
        )

    def register_device(
        self,
        user_id: str,
        device_id: str,
        apns_token: str,
        environment: str,
        bundle_id: str,
    ) -> iOSDeviceTokenModel:
        """
        Register or update an iOS device for push notifications.

        If the device already exists, updates the APNs token and metadata.
        If the device is new, creates a new registration.

        Args:
            user_id: User ID who owns the device
            device_id: Unique device identifier (UUID)
            apns_token: Device token from APNs (hex string)
            environment: APNs environment ("sandbox" or "production")
            bundle_id: iOS app bundle identifier

        Returns:
            The created or updated iOSDeviceTokenModel
        """
        pk = iOSDeviceTokenModel.create_pk(user_id)
        sk = iOSDeviceTokenModel.create_sk(device_id)

        # Check if device already exists
        existing_device = self.get_device(user_id, device_id)

        if existing_device:
            self.logger.info(f"Device {device_id} already exists, updating token")

            # Capture old state for audit
            before_data = iOSDeviceTokenModel.serialize_for_audit(existing_device)

            # Update existing device
            existing_device.apns_token = apns_token
            existing_device.environment = environment
            existing_device.bundle_id = bundle_id
            existing_device.last_updated = iOSDeviceTokenModel.now_epoch()
            existing_device.save()

            # Capture new state for audit
            after_data = iOSDeviceTokenModel.serialize_for_audit(existing_device)

            # Create audit record
            self.audit_helper.create_user_audit_record(
                user_id=user_id,
                action=AuditActions.UPDATE,
                before=before_data,
                after=after_data,
            )

            return existing_device
        else:
            self.logger.info(f"Creating new device registration for {device_id}")

            # Create new device
            now = iOSDeviceTokenModel.now_epoch()
            device = iOSDeviceTokenModel(
                pk=pk,
                sk=sk,
                user_id=user_id,
                device_id=device_id,
                apns_token=apns_token,
                environment=environment,
                bundle_id=bundle_id,
                enabled=True,
                created_date=now,
                last_updated=now,
            )
            device.save()

            # Create audit record
            after_data = iOSDeviceTokenModel.serialize_for_audit(device)
            self.audit_helper.create_user_audit_record(
                user_id=user_id,
                action=AuditActions.CREATE,
                after=after_data,
            )

            return device

    def get_device(
        self,
        user_id: str,
        device_id: str,
    ) -> Optional[iOSDeviceTokenModel]:
        """
        Retrieve a specific device registration.

        Args:
            user_id: User ID who owns the device
            device_id: Device identifier to retrieve

        Returns:
            The iOSDeviceTokenModel if found, None otherwise
        """
        pk = iOSDeviceTokenModel.create_pk(user_id)
        sk = iOSDeviceTokenModel.create_sk(device_id)

        try:
            device = iOSDeviceTokenModel.get(pk, sk)
            self.logger.info(f"Retrieved device {device_id} for user {user_id}")
            return device
        except DoesNotExist:
            self.logger.info(f"Device {device_id} not found for user {user_id}")
            return None

    def get_user_devices(
        self,
        user_id: str,
        enabled_only: bool = False,
    ) -> List[iOSDeviceTokenModel]:
        """
        Retrieve all devices for a user.

        Args:
            user_id: User ID to query devices for
            enabled_only: If True, only return enabled devices

        Returns:
            List of iOSDeviceTokenModel objects
        """
        pk = iOSDeviceTokenModel.create_pk(user_id)

        try:
            # Query all devices for the user
            devices = list(
                iOSDeviceTokenModel.query(
                    pk,
                    iOSDeviceTokenModel.sk.startswith("DEVICE#"),
                )
            )

            if enabled_only:
                devices = [d for d in devices if d.enabled]

            self.logger.info(
                f"Retrieved {len(devices)} devices for user {user_id} "
                f"(enabled_only={enabled_only})"
            )
            return devices
        except Exception as e:
            self.logger.error(f"Error querying devices for user {user_id}: {e}")
            return []

    def unregister_device(
        self,
        user_id: str,
        device_id: str,
    ) -> bool:
        """
        Unregister (delete) a device.

        Args:
            user_id: User ID who owns the device
            device_id: Device identifier to unregister

        Returns:
            True if device was deleted, False if device not found
        """
        device = self.get_device(user_id, device_id)

        if not device:
            self.logger.warning(f"Device {device_id} not found for user {user_id}")
            return False

        # Verify device belongs to the user
        if device.user_id != user_id:
            self.logger.warning(
                f"User {user_id} attempted to unregister device belonging to {device.user_id}"
            )
            return False

        # Capture state before deletion for audit
        before_data = iOSDeviceTokenModel.serialize_for_audit(device)

        device.delete()
        self.logger.info(f"Unregistered device {device_id} for user {user_id}")

        # Create audit record
        self.audit_helper.create_user_audit_record(
            user_id=user_id,
            action=AuditActions.DELETE,
            before=before_data,
        )

        return True

    def disable_device(
        self,
        user_id: str,
        device_id: str,
        reason: str = None,
    ) -> bool:
        """
        Disable a device (set enabled=False).

        This is typically called when APNs returns an invalid token error.

        Args:
            user_id: User ID who owns the device
            device_id: Device identifier to disable
            reason: Optional reason for disabling (for logging)

        Returns:
            True if device was disabled, False if device not found
        """
        device = self.get_device(user_id, device_id)

        if not device:
            self.logger.warning(f"Device {device_id} not found for user {user_id}")
            return False

        # Capture state before change for audit
        before_data = iOSDeviceTokenModel.serialize_for_audit(device)

        device.enabled = False
        device.last_updated = iOSDeviceTokenModel.now_epoch()
        device.save()

        log_msg = f"Disabled device {device_id} for user {user_id}"
        if reason:
            log_msg += f" - Reason: {reason}"
        self.logger.info(log_msg)

        # Capture state after change for audit
        after_data = iOSDeviceTokenModel.serialize_for_audit(device)

        # Create audit record with reason in the after data if provided
        if reason:
            after_data["disable_reason"] = reason

        self.audit_helper.create_user_audit_record(
            user_id=user_id,
            action=AuditActions.UPDATE,
            before=before_data,
            after=after_data,
        )

        return True

    def enable_device(
        self,
        user_id: str,
        device_id: str,
    ) -> bool:
        """
        Enable a device (set enabled=True).

        Args:
            user_id: User ID who owns the device
            device_id: Device identifier to enable

        Returns:
            True if device was enabled, False if device not found
        """
        device = self.get_device(user_id, device_id)

        if not device:
            self.logger.warning(f"Device {device_id} not found for user {user_id}")
            return False

        # Capture state before change for audit
        before_data = iOSDeviceTokenModel.serialize_for_audit(device)

        device.enabled = True
        device.last_updated = iOSDeviceTokenModel.now_epoch()
        device.save()

        self.logger.info(f"Enabled device {device_id} for user {user_id}")

        # Capture state after change for audit
        after_data = iOSDeviceTokenModel.serialize_for_audit(device)

        self.audit_helper.create_user_audit_record(
            user_id=user_id,
            action=AuditActions.UPDATE,
            before=before_data,
            after=after_data,
        )

        return True

    def get_devices_by_environment(
        self,
        user_id: str,
        environment: str,
        enabled_only: bool = True,
    ) -> List[iOSDeviceTokenModel]:
        """
        Get all devices for a user filtered by environment.

        Args:
            user_id: User ID to query devices for
            environment: APNs environment ("sandbox" or "production")
            enabled_only: If True, only return enabled devices

        Returns:
            List of iOSDeviceTokenModel objects matching the environment
        """
        devices = self.get_user_devices(user_id, enabled_only=enabled_only)
        filtered_devices = [d for d in devices if d.environment == environment]

        self.logger.info(
            f"Retrieved {len(filtered_devices)} {environment} devices for user {user_id}"
        )
        return filtered_devices
