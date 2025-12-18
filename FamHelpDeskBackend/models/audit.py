from pynamodb.attributes import UnicodeAttribute, NumberAttribute, MapAttribute
from enum import Enum
from models.base import FamHelpDeskBaseModel


class AuditActions(str, Enum):
    CREATE = "CREATE"
    UPDATE = "UPDATE"
    DELETE = "DELETE"


class AuditEntityTypes(str, Enum):
    FAMILY = "FAMILY"
    MEMBER = "MEMBER"
    GROUP = "GROUP"
    QUEUE = "QUEUE"
    TICKET = "TICKET"
    COMMENT = "COMMENT"
    USER_PROFILE = "USER_PROFILE"


class AuditModel(FamHelpDeskBaseModel):

    family_id = UnicodeAttribute(null=True)
    entity_type = UnicodeAttribute()
    entity_id = UnicodeAttribute()
    action = UnicodeAttribute()
    actor_user_id = UnicodeAttribute()
    before = MapAttribute(null=True)
    after = MapAttribute(null=True)
    time = NumberAttribute()

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_user_profile_pk(user_id: str) -> str:
        return f"USER#{user_id}"

    @staticmethod
    def create_sk(entity_type: str, entity_id: str, timestamp: int, action: str) -> str:
        return f"AUDIT#{entity_type}#{entity_id}#TS#{timestamp}#ACTION#{action}"
