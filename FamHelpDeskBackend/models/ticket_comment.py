from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute
from helpers.entity_ref import EntityRef


class TicketCommentModel(FamHelpDeskBaseModel):
    family_id = UnicodeAttribute()
    group_id = UnicodeAttribute()
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
    def create_sk(ticket_id: str, comment_id: str) -> str:
        return f"TICKET#{ticket_id}#COMMENT#{comment_id}"

    @staticmethod
    def clean_returned_comment(comment: "TicketCommentModel") -> dict:
        return {
            "family_id": EntityRef(id=comment.family_id),
            "group_id": EntityRef(id=comment.group_id),
            "queue_id": EntityRef(id=comment.queue_id),
            "ticket_id": comment.ticket_id,
            "comment_id": comment.comment_id,
            "comment_user": EntityRef(id=comment.comment_user),
            "comment_body": comment.comment_body,
            "comment_date": comment.comment_date,
            "last_update": comment.last_update,
        }
