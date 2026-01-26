from pynamodb.models import Model
from pynamodb.attributes import UnicodeAttribute
from enum import Enum
import uuid
import time
import os
import random
import string


class MembershipStatus(str, Enum):
    MEMBER = "MEMBER"
    AWAITING = "AWAITING"
    DECLINED = "DECLINED"


class FamHelpDeskBaseModel(Model):
    class Meta:
        stage = os.getenv("STAGE", "Testing")
        table_name = os.getenv("TABLE_NAME", "FamHelpDesk-Testing")
        region = "us-west-2"

    pk = UnicodeAttribute(hash_key=True)
    sk = UnicodeAttribute(range_key=True)

    @staticmethod
    def generate_random_id(prefix: str = None) -> str:
        """
        Generate a random ID consisting of a single letter (provided or random) followed by a 10-digit number.

        Args:
            prefix (str): Optional letter to prefix the ID. If not provided, a random uppercase letter is used.

        Returns:
            str: The generated random ID.
        """
        letter = prefix if prefix else random.choice(string.ascii_uppercase)
        number = "".join(random.choices("0123456789", k=10))
        return f"{letter}{number}"

    @staticmethod
    def now_epoch() -> int:
        return int(time.time())
