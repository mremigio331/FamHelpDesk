from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, BooleanAttribute, NumberAttribute


class iOSDeviceTokenModel(FamHelpDeskBaseModel):
    """
    PK: USER#{user_id}
    SK: DEVICE#{device_id}
    """

    user_id = UnicodeAttribute()
    device_id = UnicodeAttribute()

    apns_token = UnicodeAttribute()
    environment = UnicodeAttribute()
    bundle_id = UnicodeAttribute()

    enabled = BooleanAttribute(default=True)

    created_date = NumberAttribute()
    last_updated = NumberAttribute()

    @staticmethod
    def create_pk(user_id: str) -> str:
        return f"USER#{user_id}"

    @staticmethod
    def create_sk(device_id: str) -> str:
        return f"DEVICE#{device_id}"

    @staticmethod
    def serialize_for_audit(device: "iOSDeviceTokenModel") -> dict:
        """
        Serialize device data for audit records.

        Args:
            device: The device model to serialize

        Returns:
            Dictionary with device data (excluding sensitive apns_token)
        """
        return {
            "device_id": device.device_id,
            "user_id": device.user_id,
            "environment": device.environment,
            "bundle_id": device.bundle_id,
            "enabled": device.enabled,
            "created_date": device.created_date,
            "last_updated": device.last_updated,
            # Note: apns_token is intentionally excluded for security
        }
