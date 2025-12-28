from models.base import FamHelpDeskBaseModel
from pynamodb.attributes import UnicodeAttribute, NumberAttribute


class QueueModel(FamHelpDeskBaseModel):
    family_id = UnicodeAttribute()
    group_id = UnicodeAttribute()
    queue_id = UnicodeAttribute()
    queue_name = UnicodeAttribute()
    queue_description = UnicodeAttribute(null=True)
    creation_date = NumberAttribute()

    @staticmethod
    def create_pk(family_id: str) -> str:
        return f"FAMILY#{family_id}"

    @staticmethod
    def create_sk(group_id: str, queue_id: str) -> str:
        return f"GROUP#{group_id}#QUEUE#{queue_id}"

    @staticmethod
    def clean_returned_queue(queue: "QueueModel") -> dict:
        data = {
            "family_id": queue.family_id,
            "group_id": queue.group_id,
            "queue_id": queue.queue_id,
            "queue_name": queue.queue_name,
            "creation_date": queue.creation_date,
        }
        if getattr(queue, "queue_description", None) is not None:
            data["queue_description"] = queue.queue_description
        return data
