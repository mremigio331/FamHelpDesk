from enum import Enum
from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute


class TicketSeverity(str, Enum):
    SEV_1 = "1.0"
    SEV_2 = "2.0"
    SEV_2_5 = "2.5"
    SEV_3 = "3.0"
    SEV_4 = "4.0"
    SEV_5 = "5.0"


class TicketStatus(str, Enum):
    OPEN = "OPEN"
    RESOLVED = "RESOLVED"
    CLOSED = "CLOSED"


class TicketModel(FamHelpDeskBaseModel):
    family_id = UnicodeAttribute()
    queue_id = UnicodeAttribute()
    ticket_id = UnicodeAttribute()
    title = UnicodeAttribute()
    description = UnicodeAttribute(null=True)
    severity = UnicodeAttribute()
    status = UnicodeAttribute()
    creation_date = NumberAttribute()
    resolved_date = NumberAttribute(null=True)
    closed_date = NumberAttribute(null=True)
    reopen_until = NumberAttribute(null=True)
    assigned_to = UnicodeAttribute(null=True)

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(queue_id: str, ticket_id: str) -> str:
        return f"QUEUE#{queue_id}#TICKET#{ticket_id}"
