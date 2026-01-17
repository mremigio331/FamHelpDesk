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


class TicketGroupIndex(GlobalSecondaryIndex):
    """
    GSI for querying tickets by group across all queues
    """

    class Meta:
        index_name = "TicketGroupIndex"
        projection = AllProjection()

    TicketGroupPK = UnicodeAttribute(hash_key=True)
    TicketGroupSK = UnicodeAttribute(range_key=True)


class TicketAssignmentIndex(GlobalSecondaryIndex):
    """
    GSI for querying tickets by assigned user across all queues
    """

    class Meta:
        index_name = "TicketAssignmentIndex"
        projection = AllProjection()

    TicketAssignmentPK = UnicodeAttribute(hash_key=True)
    TicketAssignmentSK = UnicodeAttribute(range_key=True)


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
    resolved_date = NumberAttribute(null=True)
    closed_date = NumberAttribute(null=True)
    reopen_until = NumberAttribute(null=True)
    assigned_to = UnicodeAttribute(null=True)
    private = BooleanAttribute(null=False)

    # GSI attributes for group-level queries (auto-populated)
    TicketGroupPK = UnicodeAttribute(null=True)
    TicketGroupSK = UnicodeAttribute(null=True)

    # GSI attributes for assignment queries (auto-populated)
    TicketAssignmentPK = UnicodeAttribute(null=True)
    TicketAssignmentSK = UnicodeAttribute(null=True)

    # GSI indexes
    group_index = TicketGroupIndex()
    assignment_index = TicketAssignmentIndex()

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Auto-populate GSI attributes when model is instantiated
        self._populate_gsi_attributes()

    def _populate_gsi_attributes(self):
        """Automatically populate GSI attributes based on ticket data"""
        # Group GSI (always populated for tickets)
        if self.family_id and self.group_id and self.ticket_id:
            self.TicketGroupPK = self.create_group_gsi_pk(self.family_id, self.group_id)
            self.TicketGroupSK = self.create_group_gsi_sk(self.ticket_id)

        # Assignment GSI (only if ticket is assigned)
        if self.family_id and self.ticket_id:
            if hasattr(self, "assigned_to") and self.assigned_to:
                self.TicketAssignmentPK = self.create_assignment_gsi_pk(
                    self.family_id, self.assigned_to
                )
                self.TicketAssignmentSK = self.create_assignment_gsi_sk(self.ticket_id)
            else:
                # Clear assignment GSI if ticket is unassigned
                self.TicketAssignmentPK = None
                self.TicketAssignmentSK = None

    def save(self, **kwargs):
        """Override save to ensure GSI attributes are populated before saving"""
        self._populate_gsi_attributes()
        return super().save(**kwargs)

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(queue_id: str, ticket_id: str) -> str:
        return f"QUEUE#{queue_id}#TICKET#{ticket_id}"

    @staticmethod
    def create_group_gsi_pk(family_id: str, group_id: str) -> str:
        return f"FAMILY#{family_id}#GROUP#{group_id}"

    @staticmethod
    def create_group_gsi_sk(ticket_id: str) -> str:
        return f"TICKET#{ticket_id}"

    @staticmethod
    def create_assignment_gsi_pk(family_id: str, assigned_to: str) -> str:
        return f"FAMILY#{family_id}#ASSIGNED#{assigned_to}"

    @staticmethod
    def create_assignment_gsi_sk(ticket_id: str) -> str:
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
