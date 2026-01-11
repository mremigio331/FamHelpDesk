from typing import Optional
from aws_lambda_powertools import Logger

from exceptions.group_exceptions import (
    InvalidGroupData,
    GroupFamilyMismatch,
    FamilyNotFound,
)
from exceptions.queue_exceptions import (
    InvalidQueueData,
    QueueNameTooLong,
    QueueDescriptionTooLong,
    QueueNotFound,
    QueueGroupMismatch,
)
from helpers.family_helper import FamilyHelper
from helpers.group_helper import GroupHelper
from helpers.queue_helper import QueueHelper


class QueueValidationHelper:
    """Helper class for validating queue operations and data."""

    def __init__(self, request_id: str = None):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.request_id = request_id
        self.family_helper = FamilyHelper(request_id=request_id)
        self.group_helper = GroupHelper(request_id=request_id)
        self.queue_helper = QueueHelper(request_id=request_id)

    def validate_queue_name(self, queue_name: str, max_length: int = 100) -> None:
        """Validate queue name format and length."""
        if not queue_name or not queue_name.strip():
            raise InvalidQueueData("Queue name is required and cannot be empty")

        if len(queue_name) > max_length:
            raise QueueNameTooLong(max_length)

        # Check for invalid characters
        if any(char in queue_name for char in ["<", ">", "&", '"', "'"]):
            raise InvalidQueueData("Queue name contains invalid characters")

    def validate_queue_description(
        self, queue_description: Optional[str], max_length: int = 500
    ) -> None:
        """Validate queue description length."""
        if queue_description is not None and len(queue_description) > max_length:
            raise QueueDescriptionTooLong(max_length)

    def validate_family_exists(self, family_id: str) -> None:
        """Validate that the family exists."""
        if not family_id or not family_id.strip():
            raise InvalidQueueData("Family ID is required")

        family = self.family_helper.get_family(family_id)
        if not family:
            raise FamilyNotFound(f"Family with ID {family_id} not found")

    def validate_group_exists(self, family_id: str, group_id: str) -> None:
        """Validate that the group exists in the specified family."""
        if not group_id or not group_id.strip():
            raise InvalidQueueData("Group ID is required")

        group = self.group_helper.get_group(family_id, group_id)
        if not group:
            raise InvalidQueueData(
                f"Group {group_id} does not exist in family {family_id}"
            )

        if group.family_id != family_id:
            raise GroupFamilyMismatch(
                f"Group {group_id} does not belong to family {family_id}"
            )

    def validate_queue_exists(
        self, family_id: str, group_id: str, queue_id: str
    ) -> None:
        """Validate that the queue exists in the specified group."""
        if not queue_id or not queue_id.strip():
            raise InvalidQueueData("Queue ID is required")

        queue = self.queue_helper.get_queue(family_id, group_id, queue_id)
        if not queue:
            raise QueueNotFound(
                f"Queue {queue_id} does not exist in group {group_id} of family {family_id}"
            )

        if queue.family_id != family_id or queue.group_id != group_id:
            raise QueueGroupMismatch(
                f"Queue {queue_id} does not belong to group {group_id} in family {family_id}"
            )

    def validate_create_queue_data(
        self,
        family_id: str,
        group_id: str,
        queue_name: str,
        queue_description: Optional[str] = None,
    ) -> None:
        """Validate all data required for creating a queue."""
        self.validate_family_exists(family_id)
        self.validate_group_exists(family_id, group_id)
        self.validate_queue_name(queue_name)
        self.validate_queue_description(queue_description)

    def validate_update_queue_data(
        self,
        family_id: str,
        group_id: str,
        queue_id: str,
        queue_name: Optional[str] = None,
        queue_description: Optional[str] = None,
    ) -> None:
        """Validate all data required for updating a queue."""
        self.validate_queue_exists(family_id, group_id, queue_id)

        if queue_name is not None:
            self.validate_queue_name(queue_name)

        if queue_description is not None:
            self.validate_queue_description(queue_description)

    def validate_queue_operation(
        self, family_id: str, group_id: str, queue_id: str
    ) -> None:
        """Validate that a queue operation can be performed."""
        self.validate_queue_exists(family_id, group_id, queue_id)
