from typing import Optional, List
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger

from models.group import GroupModel
from helpers.audit_helper import AuditHelper
from helpers.queue_helper import QueueHelper
from helpers.group_membership_helper import GroupMembershipHelper
from models.audit import AuditActions, AuditEntityTypes
from exceptions.group_exceptions import GroupNotFound


class GroupHelper:
    def __init__(self, request_id: str = None):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.request_id = request_id
        self.audit_helper = AuditHelper(request_id=request_id)
        self.queue_helper = QueueHelper(request_id=request_id)
        self.group_membership_helper = GroupMembershipHelper(request_id=request_id)

    def create_group(
        self,
        family_id: str,
        group_name: str,
        created_by: str,
        group_description: Optional[str] = None,
    ) -> GroupModel:
        group_id = GroupModel.generate_uuid()
        creation_date = GroupModel.now_epoch()

        group = GroupModel(
            pk=GroupModel.create_pk(family_id),
            sk=GroupModel.create_sk(group_id),
            family_id=family_id,
            group_id=group_id,
            group_name=group_name,
            created_by=created_by,
            creation_date=creation_date,
        )

        if group_description is not None:
            group.group_description = group_description

        group.save()
        self.logger.info(f"Created group {group_id} in family {family_id}")

        # Audit record for creation
        group_data = GroupModel.clean_returned_group(group)
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.GROUP,
            entity_id=group_id,
            action=AuditActions.CREATE,
            actor_user_id=created_by,
            after=group_data,
        )

        # Create default queue for the group
        self.queue_helper.create_queue(
            family_id=family_id,
            group_id=group_id,
            queue_name="General",
            created_by=created_by,
            queue_description="Default queue for general requests",
        )
        self.logger.info(f"Created default queue for group {group_id}")

        # Add the creator as an admin member of the group
        self.group_membership_helper.create_membership(
            family_id=family_id,
            group_id=group_id,
            user_id=created_by,
            is_admin=True,
        )
        self.logger.info(
            f"Added creator {created_by} as admin member of group {group_id}"
        )

        return group

    def get_group(self, family_id: str, group_id: str) -> GroupModel | None:
        try:
            group = GroupModel.get(
                GroupModel.create_pk(family_id),
                GroupModel.create_sk(group_id),
            )
            return group
        except DoesNotExist:
            self.logger.info(f"No group found for {group_id} in family {family_id}.")
            return None

    def get_all_groups(self, family_id: str) -> List[GroupModel]:
        items: List[GroupModel] = []
        for item in GroupModel.scan(GroupModel.family_id == family_id):
            # Ensure this is a group META record
            if (
                str(item.pk).startswith("FAMILY#")
                and str(item.sk).startswith("GROUP#")
                and str(item.sk).endswith("#META")
            ):
                items.append(item)
        self.logger.info(f"Fetched {len(items)} groups for family {family_id}.")
        return items

    def update_group(
        self,
        family_id: str,
        group_id: str,
        actor_user_id: str,
        **kwargs,
    ) -> GroupModel:
        group = self.get_group(family_id, group_id)
        if not group:
            raise GroupNotFound(f"Group {group_id} not found in family {family_id}")

        # Capture old state for auditing
        old_group_data = GroupModel.clean_returned_group(group)

        # Only allow updates to specific fields
        allowed_fields = {"group_name", "group_description"}
        for key, value in kwargs.items():
            if key in allowed_fields and hasattr(group, key):
                setattr(group, key, value)

        group.save()
        self.logger.info(f"Updated group {group_id} in family {family_id}")

        # Audit record for update
        new_group_data = GroupModel.clean_returned_group(group)
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.GROUP,
            entity_id=group_id,
            action=AuditActions.UPDATE,
            actor_user_id=actor_user_id,
            before=old_group_data,
            after=new_group_data,
        )

        return group

    def delete_group(
        self,
        family_id: str,
        group_id: str,
        actor_user_id: str,
    ) -> bool:
        group = self.get_group(family_id, group_id)
        if not group:
            raise GroupNotFound(f"Group {group_id} not found in family {family_id}")

        # Delete all queues in the group first
        try:
            deleted_queues = self.queue_helper.delete_all_queues_by_group(
                family_id, group_id, actor_user_id
            )
            self.logger.info(f"Deleted {deleted_queues} queues for group {group_id}")
        except Exception as e:
            self.logger.error(f"Failed to delete queues for group {group_id}: {str(e)}")
            raise ValueError("Failed to delete group queues")

        # Capture group data for auditing before deletion
        group_data = GroupModel.clean_returned_group(group)

        # Delete all group memberships
        try:
            self.group_membership_helper.delete_all_group_memberships(
                family_id, group_id
            )
            self.logger.info(f"Deleted all memberships for group {group_id}")
        except Exception as e:
            self.logger.error(f"Failed to delete group memberships: {str(e)}")
            raise ValueError("Failed to delete group memberships")

        # Delete the group
        group.delete()
        self.logger.info(f"Deleted group {group_id} from family {family_id}")

        # Audit record for deletion
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.GROUP,
            entity_id=group_id,
            action=AuditActions.DELETE,
            actor_user_id=actor_user_id,
            before=group_data,
        )

        return True
