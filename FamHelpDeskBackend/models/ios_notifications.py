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
