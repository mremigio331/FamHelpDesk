from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute


class TicketCommentModel(FamHelpDeskBaseModel):
    family_id = UnicodeAttribute()
    queue_id = UnicodeAttribute()
    ticket_id = UnicodeAttribute()
    comment_id = UnicodeAttribute()
    comment_user = UnicodeAttribute()
    comment_body = UnicodeAttribute()
    comment_date = NumberAttribute()
    last_update = NumberAttribute()

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(queue_id: str, ticket_id: str, comment_id: str) -> str:
        return f"QUEUE#{queue_id}#TICKET#{ticket_id}#COMMENT#{comment_id}"
