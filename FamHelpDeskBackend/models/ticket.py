from enum import Enum
from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute, BooleanAttribute
from pynamodb.indexes import GlobalSecondaryIndex, AllProjection
from helpers.entity_ref import EntityRef


# Valid severity values
VALID_SEVERITY_VALUES = [1.0, 2.0, 2.5, 3.0, 4.0, 5.0]


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
    severity = NumberAttribute()
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

    def __setattr__(self, name, value):
        # Validate severity when it's being set
        if name == "severity" and value is not None:
            if value not in VALID_SEVERITY_VALUES:
                from exceptions.ticket_exceptions import InvalidTicketSeverityException

                raise InvalidTicketSeverityException(
                    f"Invalid severity: {value}. Must be one of: {VALID_SEVERITY_VALUES}"
                )
        super().__setattr__(name, value)

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(ticket_id: str) -> str:
        return f"TICKET#{ticket_id}"

    @staticmethod
    def clean_returned_ticket(ticket: "TicketModel") -> dict:
        data = {
            "family_id": EntityRef(id=ticket.family_id),
            "group_id": EntityRef(id=ticket.group_id),
            "queue_id": EntityRef(id=ticket.queue_id),
            "ticket_id": ticket.ticket_id,
            "title": ticket.title,
            "severity": ticket.severity,
            "status": ticket.status,
            "creation_date": ticket.creation_date,
            "created_by": EntityRef(id=ticket.created_by),
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
            data["assigned_to"] = EntityRef(id=ticket.assigned_to)
        return data

    @staticmethod
    def clean_returned_ticket_for_audit(ticket: "TicketModel") -> dict:
        """Return a serializable version of the ticket for audit records"""
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
