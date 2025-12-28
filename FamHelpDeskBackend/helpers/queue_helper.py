from typing import Optional, List
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger

from models.queue import QueueModel
from helpers.audit_helper import AuditHelper
from models.audit import AuditActions, AuditEntityTypes


class QueueHelper:
    def __init__(self, request_id: str = None):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.request_id = request_id
        self.audit_helper = AuditHelper(request_id=request_id)

    def create_queue(
        self,
        family_id: str,
        group_id: str,
        queue_name: str,
        created_by: str,
        queue_description: Optional[str] = None,
    ) -> QueueModel:
        queue_id = QueueModel.generate_uuid()
        creation_date = QueueModel.now_epoch()

        queue = QueueModel(
            pk=QueueModel.create_pk(family_id),
            sk=QueueModel.create_sk(group_id, queue_id),
            family_id=family_id,
            group_id=group_id,
            queue_id=queue_id,
            queue_name=queue_name,
            creation_date=creation_date,
        )

        if queue_description is not None:
            queue.queue_description = queue_description

        queue.save()
        self.logger.info(f"Created queue {queue_id} in family {family_id}")

        # Audit record for creation
        queue_data = QueueModel.clean_returned_queue(queue)
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.QUEUE,
            entity_id=queue_id,
            action=AuditActions.CREATE,
            actor_user_id=created_by,
            after=queue_data,
        )

        return queue

    def update_queue(
        self,
        family_id: str,
        group_id: str,
        queue_id: str,
        updated_by: str,
        queue_name: Optional[str] = None,
        queue_description: Optional[str] = None,
    ) -> QueueModel | None:
        queue = self.get_queue(family_id, group_id, queue_id)
        if queue is None:
            self.logger.warning(
                f"Queue {queue_id} not found in family {family_id} for update"
            )
            return None

        # Capture before state
        before_data = QueueModel.clean_returned_queue(queue)

        # Update fields if provided
        if queue_name is not None:
            queue.queue_name = queue_name
        if queue_description is not None:
            queue.queue_description = queue_description

        queue.save()
        self.logger.info(f"Updated queue {queue_id} in family {family_id}")

        # Capture after state and audit
        after_data = QueueModel.clean_returned_queue(queue)
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.QUEUE,
            entity_id=queue_id,
            action=AuditActions.UPDATE,
            actor_user_id=updated_by,
            before=before_data,
            after=after_data,
        )

        return queue

    def get_queue(
        self, family_id: str, group_id: str, queue_id: str
    ) -> QueueModel | None:
        try:
            queue = QueueModel.get(
                QueueModel.create_pk(family_id),
                QueueModel.create_sk(group_id, queue_id),
            )
            return queue
        except DoesNotExist:
            self.logger.info(f"No queue found for {queue_id} in family {family_id}.")
            return None

    def get_all_queues_by_group(
        self, family_id: str, group_id: str
    ) -> List[QueueModel]:
        items: List[QueueModel] = []
        sk_prefix = f"GROUP#{group_id}#QUEUE#"

        for item in QueueModel.query(
            QueueModel.create_pk(family_id),
            QueueModel.sk.startswith(sk_prefix),
        ):
            items.append(item)

        self.logger.info(
            f"Fetched {len(items)} queues for group {group_id} in family {family_id}."
        )
        return items
        return items
