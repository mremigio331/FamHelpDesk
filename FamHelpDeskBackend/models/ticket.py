from enum import Enum
from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute, BooleanAttribute
from pynamodb.indexes import GlobalSecondaryIndex, AllProjection


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


class TicketTimeIndex(GlobalSecondaryIndex):
    """
    GSI for querying tickets by family ordered by last_update_time
    """

    class Meta:
        index_name = "TicketTimeIndex"
        projection = AllProjection()

    family_id = UnicodeAttribute(hash_key=True)
    last_update_time = NumberAttribute(range_key=True)


class TicketIdIndex(GlobalSecondaryIndex):
    """
    GSI for direct ticket lookup by ticket_id only
    """

    class Meta:
        index_name = "TicketIdIndex"
        projection = AllProjection()

    ticket_id = UnicodeAttribute(hash_key=True)


class TicketModel(FamHelpDeskBaseModel):
    family_id = UnicodeAttribute()
    group_id = UnicodeAttribute()
    queue_id = UnicodeAttribute()
    ticket_id = UnicodeAttribute()
    title = UnicodeAttribute()
    description = UnicodeAttribute(null=True)
    severity = UnicodeAttribute()
    status = UnicodeAttribute()
    creation_date = NumberAttribute()
    created_by = UnicodeAttribute()
    last_update_time = NumberAttribute()
    resolved_date = NumberAttribute(null=True)
    closed_date = NumberAttribute(null=True)
    reopen_until = NumberAttribute(null=True)
    # GSI attributes for assignment queries (only populated if assigned)
    assigned_to = UnicodeAttribute(null=True)
    private = BooleanAttribute(null=False)

    # GSI indexes
    time_index = TicketTimeIndex()
    ticket_id_index = TicketIdIndex()

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(ticket_id: str) -> str:
        return f"TICKET#{ticket_id}"

    @staticmethod
    def clean_returned_ticket(ticket: "TicketModel") -> dict:
        data = {
            "family_id": ticket.family_id,
            "group_id": ticket.group_id,
            "queue_id": ticket.queue_id,
            "ticket_id": ticket.ticket_id,
            "title": ticket.title,
            "severity": ticket.severity,
            "status": ticket.status,
            "creation_date": ticket.creation_date,
            "created_by": ticket.created_by,
            "last_update_time": ticket.last_update_time,
            "private": ticket.private,
        }
        if getattr(ticket, "description", None) is not None:
            data["description"] = ticket.description
        if getattr(ticket, "resolved_date", None) is not None:
            data["resolved_date"] = ticket.resolved_date
        if getattr(ticket, "closed_date", None) is not None:
            data["closed_date"] = ticket.closed_date
        if getattr(ticket, "reopen_until", None) is not None:
            data["reopen_until"] = ticket.reopen_until
        if getattr(ticket, "assigned_to", None) is not None:
            data["assigned_to"] = ticket.assigned_to
        return data
