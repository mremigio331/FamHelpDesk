from typing import List, Optional
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger

from models.family_membership import FamilyMembershipModel
from models.base import MembershipStatus
from helpers.audit_helper import AuditHelper
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


class FamilyMembershipHelper:
    def __init__(self, request_id: str = None):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.audit_helper = AuditHelper(request_id=request_id)

    # Core getters
    def get_membership(self, family_id: str, user_id: str) -> Optional[dict]:
        try:
            item = FamilyMembershipModel.get(
                FamilyMembershipModel.create_pk(family_id),
                FamilyMembershipModel.create_sk(user_id),
            )
            return self._clean_membership(item)
        except DoesNotExist:
            self.logger.info(
                f"No membership for family {family_id} and user {user_id}."
            )
            return None

    # Create a membership request (awaiting approval)
    def create_membership_request(self, family_id: str, user_id: str) -> dict:
        existing = self.get_membership(family_id, user_id)
        if existing:
            if existing["status"] == MembershipStatus.MEMBER.value:
                raise MembershipAlreadyExistsAsMember()
            if existing["status"] == MembershipStatus.AWAITING.value:
                raise MembershipRequestPendingExists()

        item = FamilyMembershipModel(
            pk=FamilyMembershipModel.create_pk(family_id),
            sk=FamilyMembershipModel.create_sk(user_id),
            family_id=family_id,
            user_id=user_id,
            status=MembershipStatus.AWAITING.value,
            is_admin=False,
            request_date=FamilyMembershipModel.now_epoch(),
        )
        item.save()
        self.logger.info(
            f"Created membership request for user {user_id} in family {family_id}."
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

    # Create a membership (immediate member), e.g., when creating a family
    def create_membership(
        self, family_id: str, user_id: str, is_admin: bool = True
    ) -> dict:
        existing = self.get_membership(family_id, user_id)
        if existing and existing["status"] == MembershipStatus.MEMBER.value:
            raise MembershipAlreadyExistsAsMember()

        item = FamilyMembershipModel(
            pk=FamilyMembershipModel.create_pk(family_id),
            sk=FamilyMembershipModel.create_sk(user_id),
            family_id=family_id,
            user_id=user_id,
            status=MembershipStatus.MEMBER.value,
            is_admin=is_admin,
            request_date=FamilyMembershipModel.now_epoch(),
        )
        item.save()
        self.logger.info(
            f"Created membership for user {user_id} in family {family_id} (admin={is_admin})."
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

    # List all memberships by user across families
    def get_all_memberships_by_user(self, user_id: str) -> List[dict]:
        items: List[dict] = []
        for item in FamilyMembershipModel.scan(
            FamilyMembershipModel.user_id == user_id
        ):
            # Safety: ensure this is a membership record
            if str(item.pk).startswith("FAMILY#") and str(item.sk).startswith(
                "MEMBER#"
            ):
                items.append(self._clean_membership(item))
        self.logger.info(f"Fetched {len(items)} memberships for user {user_id}.")
        return items

    # Delete a pending membership request
    def delete_membership_request(
        self, family_id: str, user_id: str, actor_user_id: str
    ) -> dict:
        try:
            item = FamilyMembershipModel.get(
                FamilyMembershipModel.create_pk(family_id),
                FamilyMembershipModel.create_sk(user_id),
            )
        except DoesNotExist:
            raise MembershipNotFound()

        if item.status != MembershipStatus.AWAITING.value:
            raise MembershipPendingRequired()

        before = self._clean_membership(item)
        item.delete()
        self.logger.info(
            f"Deleted membership request for user {user_id} in family {family_id}."
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

    # Delete an active membership (remove user from family)
    def delete_membership(
        self, family_id: str, user_id: str, actor_user_id: str
    ) -> dict:
        try:
            item = FamilyMembershipModel.get(
                FamilyMembershipModel.create_pk(family_id),
                FamilyMembershipModel.create_sk(user_id),
            )
        except DoesNotExist:
            raise MembershipNotFound()

        if item.status != MembershipStatus.MEMBER.value:
            raise MembershipActiveRequired()

        before = self._clean_membership(item)
        item.delete()
        self.logger.info(f"Removed user {user_id} from family {family_id}.")

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
        admin_user_id: str,
        target_user_id: str,
        approve: bool,
    ) -> dict:
        # Verify admin privileges
        try:
            admin_item = FamilyMembershipModel.get(
                FamilyMembershipModel.create_pk(family_id),
                FamilyMembershipModel.create_sk(admin_user_id),
            )
        except DoesNotExist:
            raise MemberPrivilegesRequired()

        if (
            admin_item.status != MembershipStatus.MEMBER.value
            or not admin_item.is_admin
        ):
            raise AdminPrivilegesRequired()

        try:
            item = FamilyMembershipModel.get(
                FamilyMembershipModel.create_pk(family_id),
                FamilyMembershipModel.create_sk(target_user_id),
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
            f"{'Approved' if approve else 'Declined'} membership request for user {target_user_id} in family {family_id}."
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

        return after

    def grant_access(
        self,
        family_id: str,
        granter_user_id: str,
        target_user_id: str,
        make_admin: bool = False,
    ) -> dict:
        """
        Grant membership access to target_user_id.
        - Any current MEMBER can grant non-admin access.
        - Only an ADMIN can grant admin access.
        Returns cleaned membership dict for the target user.
        """
        # Verify granter is a member
        try:
            granter = FamilyMembershipModel.get(
                FamilyMembershipModel.create_pk(family_id),
                FamilyMembershipModel.create_sk(granter_user_id),
            )
        except DoesNotExist:
            raise MemberPrivilegesRequired()

        if granter.status != MembershipStatus.MEMBER.value:
            raise MemberPrivilegesRequired()
        if make_admin and not granter.is_admin:
            raise AdminPrivilegesRequired()

        # Load or create target membership
        try:
            target = FamilyMembershipModel.get(
                FamilyMembershipModel.create_pk(family_id),
                FamilyMembershipModel.create_sk(target_user_id),
            )
            is_new = False
        except DoesNotExist:
            target = None
            is_new = True

        if is_new:
            target = FamilyMembershipModel(
                pk=FamilyMembershipModel.create_pk(family_id),
                sk=FamilyMembershipModel.create_sk(target_user_id),
                family_id=family_id,
                user_id=target_user_id,
                status=MembershipStatus.MEMBER.value,
                is_admin=bool(make_admin),
                request_date=FamilyMembershipModel.now_epoch(),
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
                f"Granted {'admin ' if make_admin else ''}access to user {target_user_id} in family {family_id} by {granter_user_id}."
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
            f"Updated access for user {target_user_id} in family {family_id} by {granter_user_id} (admin_grant={make_admin})."
        )
        return after

    @staticmethod
    def _clean_membership(item: FamilyMembershipModel) -> dict:
        return FamilyMembershipModel.clean_returned_membership(item)
