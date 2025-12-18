from pynamodb.models import Model
from pynamodb.attributes import UnicodeAttribute
from enum import Enum
import uuid
import time
import os


class MembershipStatus(str, Enum):
    MEMBER = "MEMBER"
    AWAITING = "AWAITING"
    DECLINED = "DECLINED"


class FamHelpDeskBaseModel(Model):
    class Meta:
        stage = os.getenv("STAGE", "Testing")
        table_name = os.getenv("DYNAMODB_TABLE_NAME", "FamHelpDesk-Testing")
        region = "us-west-2"

    pk = UnicodeAttribute(hash_key=True)
    sk = UnicodeAttribute(range_key=True)

    @staticmethod
    def generate_uuid() -> str:
        return str(uuid.uuid4())

    @staticmethod
    def now_epoch() -> int:
        return int(time.time())
