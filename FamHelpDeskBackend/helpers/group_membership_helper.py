from typing import List, Optional
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger

from models.group_membership import GroupMembershipModel
from models.base import MembershipStatus
from helpers.audit_helper import AuditHelper
from helpers.notification_helper import NotificationHelper
from models.notification import NotificationType
from models.audit import AuditActions, AuditEntityTypes
from exceptions.membership_exceptions import (
    MembershipNotFound,
    MembershipAlreadyExistsAsMember,
    MembershipRequestPendingExists,
    MembershipPendingRequired,
    MembershipActiveRequired,
    AdminPrivilegesRequired,
    MemberPrivilegesRequired,
)


class GroupMembershipHelper:
    def __init__(self, request_id: str = None):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.audit_helper = AuditHelper(request_id=request_id)
        self.notification_helper = NotificationHelper(request_id=request_id)

    # Core getters
    def get_membership(
        self, family_id: str, group_id: str, user_id: str
    ) -> Optional[dict]:
        try:
            item = GroupMembershipModel.get(
                GroupMembershipModel.create_pk(family_id),
                GroupMembershipModel.create_sk(group_id, user_id),
            )
            return self._clean_membership(item)
        except DoesNotExist:
            self.logger.info(
                f"No membership for family {family_id}, group {group_id} and user {user_id}."
            )
            return None

    def get_all_admins(self, family_id: str, group_id: str) -> List[str]:
        """Get all admin user IDs for a group."""
        admin_ids = []
        pk = GroupMembershipModel.create_pk(family_id)
        sk_prefix = f"GROUP#{group_id}#MEMBER#"
        for item in GroupMembershipModel.query(
            pk,
            GroupMembershipModel.sk.startswith(sk_prefix),
        ):
            if item.status == MembershipStatus.MEMBER.value and item.is_admin:
                admin_ids.append(item.user_id)
        self.logger.info(
            f"Found {len(admin_ids)} admins in group {group_id} of family {family_id}."
        )
        return admin_ids

    # Create a membership request (awaiting approval)
    def create_membership_request(
        self, family_id: str, group_id: str, user_id: str
    ) -> dict:
        existing = self.get_membership(family_id, group_id, user_id)
        if existing:
            if existing["status"] == MembershipStatus.MEMBER.value:
                raise MembershipAlreadyExistsAsMember()
            if existing["status"] == MembershipStatus.AWAITING.value:
                raise MembershipRequestPendingExists()

        item = GroupMembershipModel(
            pk=GroupMembershipModel.create_pk(family_id),
            sk=GroupMembershipModel.create_sk(group_id, user_id),
            family_id=family_id,
            group_id=group_id,
            user_id=user_id,
            status=MembershipStatus.AWAITING.value,
            is_admin=False,
            request_date=GroupMembershipModel.now_epoch(),
        )
        item.save()
        self.logger.info(
            f"Created group membership request for user {user_id} in family {family_id}, group {group_id}."
        )

        after = self._clean_membership(item)
        # Audit
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.MEMBER,
            entity_id=user_id,
            action=AuditActions.CREATE,
            actor_user_id=user_id,
            after=after,
        )

        # Notify all group admins about the membership request
        admin_ids = self.get_all_admins(family_id, group_id)
        for admin_id in admin_ids:
            self.notification_helper.create_notification(
                user_id=admin_id,
                message=f"User {user_id} has requested to join the group.",
                notification_type=NotificationType.MEMBERSHIP_REQUEST,
                family_id=family_id,
            )

        return after

    # Create a membership (immediate member), e.g., direct grant
    def create_membership(
        self, family_id: str, group_id: str, user_id: str, is_admin: bool = False
    ) -> dict:
        existing = self.get_membership(family_id, group_id, user_id)
        if existing and existing["status"] == MembershipStatus.MEMBER.value:
            raise MembershipAlreadyExistsAsMember()

        item = GroupMembershipModel(
            pk=GroupMembershipModel.create_pk(family_id),
            sk=GroupMembershipModel.create_sk(group_id, user_id),
            family_id=family_id,
            group_id=group_id,
            user_id=user_id,
            status=MembershipStatus.MEMBER.value,
            is_admin=is_admin,
            request_date=GroupMembershipModel.now_epoch(),
        )
        item.save()
        self.logger.info(
            f"Created group membership for user {user_id} in family {family_id}, group {group_id} (admin={is_admin})."
        )

        after = self._clean_membership(item)
        # Audit
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.MEMBER,
            entity_id=user_id,
            action=AuditActions.CREATE,
            actor_user_id=user_id,
            after=after,
        )
        return after

    # List all group memberships by user across families/groups
    def get_all_memberships_by_user(self, user_id: str) -> List[dict]:
        items: List[dict] = []
        # Fallback to scan since GSI might not exist in all environments
        try:
            # Try GSI first
            for item in GroupMembershipModel.user_index.query(user_id):
                items.append(self._clean_membership(item))
            self.logger.info(
                f"Fetched {len(items)} group memberships for user {user_id} via GSI."
            )
        except Exception as e:
            self.logger.warning(f"GSI query failed, falling back to scan: {str(e)}")
            # Fallback to scan operation
            for item in GroupMembershipModel.scan(
                GroupMembershipModel.user_id == user_id
            ):
                items.append(self._clean_membership(item))
            self.logger.info(
                f"Fetched {len(items)} group memberships for user {user_id} via scan."
            )
        return items

    # Get all pending membership requests for a group
    def get_pending_membership_requests(
        self, family_id: str, group_id: str
    ) -> List[dict]:
        """Get all pending membership requests for a group."""
        items: List[dict] = []
        pk = GroupMembershipModel.create_pk(family_id)
        sk_prefix = f"GROUP#{group_id}#MEMBER#"
        for item in GroupMembershipModel.query(
            pk,
            GroupMembershipModel.sk.startswith(sk_prefix),
        ):
            if item.status == MembershipStatus.AWAITING.value:
                items.append(self._clean_membership(item))
        self.logger.info(f"Found {len(items)} pending requests in group {group_id}.")
        return items

    # Get all active members for a group
    def get_all_members(self, family_id: str, group_id: str) -> List[dict]:
        """Get all active members for a group."""
        items: List[dict] = []
        pk = GroupMembershipModel.create_pk(family_id)
        sk_prefix = f"GROUP#{group_id}#MEMBER#"
        for item in GroupMembershipModel.query(
            pk,
            GroupMembershipModel.sk.startswith(sk_prefix),
        ):
            if item.status == MembershipStatus.MEMBER.value:
                items.append(self._clean_membership(item))
        self.logger.info(f"Found {len(items)} active members in group {group_id}.")
        return items

    # Delete a pending membership request
    def delete_membership_request(
        self, family_id: str, group_id: str, user_id: str, actor_user_id: str
    ) -> dict:
        try:
            item = GroupMembershipModel.get(
                GroupMembershipModel.create_pk(family_id),
                GroupMembershipModel.create_sk(group_id, user_id),
            )
        except DoesNotExist:
            raise MembershipNotFound()

        if item.status != MembershipStatus.AWAITING.value:
            raise MembershipPendingRequired()

        before = self._clean_membership(item)
        item.delete()
        self.logger.info(
            f"Deleted group membership request for user {user_id} in family {family_id}, group {group_id}."
        )

        # Audit
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.MEMBER,
            entity_id=user_id,
            action=AuditActions.DELETE,
            actor_user_id=actor_user_id,
            before=before,
        )
        return before

    # Delete an active membership (remove user from group)
    def delete_membership(
        self, family_id: str, group_id: str, user_id: str, actor_user_id: str
    ) -> dict:
        try:
            item = GroupMembershipModel.get(
                GroupMembershipModel.create_pk(family_id),
                GroupMembershipModel.create_sk(group_id, user_id),
            )
        except DoesNotExist:
            raise MembershipNotFound()

        if item.status != MembershipStatus.MEMBER.value:
            raise MembershipActiveRequired()

        before = self._clean_membership(item)
        item.delete()
        self.logger.info(
            f"Removed user {user_id} from group {group_id} in family {family_id}."
        )

        # Audit
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.MEMBER,
            entity_id=user_id,
            action=AuditActions.DELETE,
            actor_user_id=actor_user_id,
            before=before,
        )
        return before

    # Admin approves or denies a pending request
    def review_membership_request(
        self,
        family_id: str,
        group_id: str,
        admin_user_id: str,
        target_user_id: str,
        approve: bool,
    ) -> dict:
        # Verify admin privileges in this group
        try:
            admin_item = GroupMembershipModel.get(
                GroupMembershipModel.create_pk(family_id),
                GroupMembershipModel.create_sk(group_id, admin_user_id),
            )
        except DoesNotExist:
            raise MemberPrivilegesRequired()

        if (
            admin_item.status != MembershipStatus.MEMBER.value
            or not admin_item.is_admin
        ):
            raise AdminPrivilegesRequired()

        try:
            item = GroupMembershipModel.get(
                GroupMembershipModel.create_pk(family_id),
                GroupMembershipModel.create_sk(group_id, target_user_id),
            )
        except DoesNotExist:
            raise MembershipNotFound()

        if item.status != MembershipStatus.AWAITING.value:
            raise MembershipPendingRequired()

        before = self._clean_membership(item)
        if approve:
            item.status = MembershipStatus.MEMBER.value
        else:
            item.status = MembershipStatus.DECLINED.value

        item.save()
        self.logger.info(
            f"{'Approved' if approve else 'Declined'} group membership request for user {target_user_id} in family {family_id}, group {group_id}."
        )

        after = self._clean_membership(item)
        # Audit
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.MEMBER,
            entity_id=target_user_id,
            action=AuditActions.UPDATE,
            actor_user_id=admin_user_id,
            before=before,
            after=after,
        )

        # Notify the target user about approval/denial
        if approve:
            self.notification_helper.create_notification(
                user_id=target_user_id,
                message=f"Your request to join the group has been approved.",
                notification_type=NotificationType.MEMBERSHIP_APPROVED,
                family_id=family_id,
            )
        else:
            self.notification_helper.create_notification(
                user_id=target_user_id,
                message=f"Your request to join the group has been denied.",
                notification_type=NotificationType.MEMBERSHIP_DENIED,
                family_id=family_id,
            )

        return after

    def grant_access(
        self,
        family_id: str,
        group_id: str,
        granter_user_id: str,
        target_user_id: str,
        make_admin: bool = False,
    ) -> dict:
        """
        Grant group membership access to target_user_id.
        - Any current GROUP MEMBER can grant non-admin access within the group.
        - Only a GROUP ADMIN can grant admin access within the group.
        Returns cleaned membership dict for the target user.
        """
        # Verify granter is a member of this group
        try:
            granter = GroupMembershipModel.get(
                GroupMembershipModel.create_pk(family_id),
                GroupMembershipModel.create_sk(group_id, granter_user_id),
            )
        except DoesNotExist:
            raise MemberPrivilegesRequired()

        if granter.status != MembershipStatus.MEMBER.value:
            raise MemberPrivilegesRequired()
        if make_admin and not granter.is_admin:
            raise AdminPrivilegesRequired()

        # Load or create target membership
        try:
            target = GroupMembershipModel.get(
                GroupMembershipModel.create_pk(family_id),
                GroupMembershipModel.create_sk(group_id, target_user_id),
            )
            is_new = False
        except DoesNotExist:
            target = None
            is_new = True

        if is_new:
            target = GroupMembershipModel(
                pk=GroupMembershipModel.create_pk(family_id),
                sk=GroupMembershipModel.create_sk(group_id, target_user_id),
                family_id=family_id,
                group_id=group_id,
                user_id=target_user_id,
                status=MembershipStatus.MEMBER.value,
                is_admin=bool(make_admin),
                request_date=GroupMembershipModel.now_epoch(),
            )
            target.save()
            after = self._clean_membership(target)
            # Audit create
            self.audit_helper.create_family_audit_record(
                family_id=family_id,
                entity_type=AuditEntityTypes.MEMBER,
                entity_id=target_user_id,
                action=AuditActions.CREATE,
                actor_user_id=granter_user_id,
                after=after,
            )
            self.logger.info(
                f"Granted {'admin ' if make_admin else ''}group access to user {target_user_id} in family {family_id}, group {group_id} by {granter_user_id}."
            )
            return after

        # Update existing membership
        before = self._clean_membership(target)
        # If pending/declined, promote to member
        if target.status in (
            MembershipStatus.AWAITING.value,
            MembershipStatus.DECLINED.value,
        ):
            target.status = MembershipStatus.MEMBER.value
        # Admin flag change only if requested and permitted
        if make_admin and not target.is_admin:
            target.is_admin = True
        elif not make_admin and target.is_admin:
            # Do not downgrade admin via grant_access; keep admin as-is
            pass

        target.save()
        after = self._clean_membership(target)
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.MEMBER,
            entity_id=target_user_id,
            action=AuditActions.UPDATE,
            actor_user_id=granter_user_id,
            before=before,
            after=after,
        )
        self.logger.info(
            f"Updated group access for user {target_user_id} in family {family_id}, group {group_id} by {granter_user_id} (admin_grant={make_admin})."
        )
        return after

    def delete_all_group_memberships(self, family_id: str, group_id: str) -> int:
        """Delete all memberships for a group."""
        deleted_count = 0
        pk = GroupMembershipModel.create_pk(family_id)
        sk_prefix = f"GROUP#{group_id}#MEMBER#"

        # Get all memberships for this group
        memberships = []
        for item in GroupMembershipModel.query(
            pk, GroupMembershipModel.sk.startswith(sk_prefix)
        ):
            memberships.append(item)

        # Delete each membership
        for membership in memberships:
            try:
                membership.delete()
                deleted_count += 1
                self.logger.info(
                    f"Deleted membership for user {membership.user_id} in group {group_id}"
                )
            except Exception as e:
                self.logger.error(
                    f"Failed to delete membership for user {membership.user_id}: {str(e)}"
                )

        self.logger.info(
            f"Deleted {deleted_count} memberships for group {group_id} in family {family_id}"
        )
        return deleted_count

    def update_member_role(
        self,
        family_id: str,
        group_id: str,
        admin_user_id: str,
        target_user_id: str,
        is_admin: bool,
    ) -> dict:
        """
        Update a group member's role (admin/member).
        Only group admins can update member roles.
        This method can both promote members to admin and demote admins to regular members.
        """
        # Verify admin privileges
        try:
            admin_item = GroupMembershipModel.get(
                GroupMembershipModel.create_pk(family_id),
                GroupMembershipModel.create_sk(group_id, admin_user_id),
            )
        except DoesNotExist:
            raise MemberPrivilegesRequired()

        if (
            admin_item.status != MembershipStatus.MEMBER.value
            or not admin_item.is_admin
        ):
            raise AdminPrivilegesRequired()

        # Get target membership
        try:
            target_item = GroupMembershipModel.get(
                GroupMembershipModel.create_pk(family_id),
                GroupMembershipModel.create_sk(group_id, target_user_id),
            )
        except DoesNotExist:
            raise MembershipNotFound()

        if target_item.status != MembershipStatus.MEMBER.value:
            raise MembershipNotFound()

        before = self._clean_membership(target_item)
        target_item.is_admin = is_admin
        target_item.save()

        after = self._clean_membership(target_item)
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.MEMBER,
            entity_id=target_user_id,
            action=AuditActions.UPDATE,
            actor_user_id=admin_user_id,
            before=before,
            after=after,
        )

        self.logger.info(
            f"Updated role for user {target_user_id} in group {group_id} to admin={is_admin} by {admin_user_id}."
        )
        return after

    @staticmethod
    def _clean_membership(item: GroupMembershipModel) -> dict:
        return {
            "family_id": item.family_id,
            "group_id": item.group_id,
            "user_id": item.user_id,
            "status": item.status,
            "is_admin": item.is_admin,
            "request_date": item.request_date,
        }
