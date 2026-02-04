from typing import List, Optional
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger

from models.family_membership import FamilyMembershipModel
from models.base import MembershipStatus
from helpers.audit_helper import AuditHelper
from helpers.notification_helper import NotificationHelper
from models.family_notification_settings import FamliyNotificationType
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
    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
        notification_topic_arn: str = None,
    ):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        FamilyMembershipModel.set_stage_and_table(
            stage, table_name, notification_topic_arn
        )
        self.audit_helper = AuditHelper(
            request_id=request_id, stage=stage, table_name=table_name
        )
        self.notification_helper = NotificationHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_topic_arn=notification_topic_arn,
        )

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

    def get_all_admins(self, family_id: str) -> List[str]:
        """Get all admin user IDs for a family."""
        admin_ids = []
        pk = FamilyMembershipModel.create_pk(family_id)
        for item in FamilyMembershipModel.query(
            pk,
            FamilyMembershipModel.sk.startswith("MEMBER#"),
        ):
            if item.status == MembershipStatus.MEMBER.value and item.is_admin:
                admin_ids.append(item.user_id)
        self.logger.info(f"Found {len(admin_ids)} admins in family {family_id}.")
        return admin_ids

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

        self.notification_helper.create_notification_async(
            user_id=user_id,
            notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_REQUEST,
            family_id=family_id,
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

        if not is_admin:
            self.notification_helper.create_notification_async(
                user_id=user_id,
                notification_type=FamliyNotificationType.WELCOME_TO_FAMILY,
                family_id=family_id,
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

    def get_all_memberships_by_user_raw(self, user_id: str) -> List[dict]:
        items: List[dict] = []
        for item in FamilyMembershipModel.scan(
            FamilyMembershipModel.user_id == user_id
        ):
            # Safety: ensure this is a membership record
            if str(item.pk).startswith("FAMILY#") and str(item.sk).startswith(
                "MEMBER#"
            ):
                items.append(item)
        self.logger.info(f"Fetched {len(items)} memberships for user {user_id}.")
        return items

    # Get all pending membership requests for a family
    def get_pending_membership_requests(self, family_id: str) -> List[dict]:
        """Get all pending membership requests for a family."""
        items: List[dict] = []
        pk = FamilyMembershipModel.create_pk(family_id)
        for item in FamilyMembershipModel.query(
            pk,
            FamilyMembershipModel.sk.startswith("MEMBER#"),
        ):
            if item.status == MembershipStatus.AWAITING.value:
                items.append(self._clean_membership(item))
        self.logger.info(f"Found {len(items)} pending requests in family {family_id}.")
        return items

    # Get all active members for a family
    def get_all_members(self, family_id: str) -> List[dict]:
        """Get all active members for a family."""
        items: List[dict] = []
        pk = FamilyMembershipModel.create_pk(family_id)
        for item in FamilyMembershipModel.query(
            pk,
            FamilyMembershipModel.sk.startswith("MEMBER#"),
        ):
            if item.status == MembershipStatus.MEMBER.value:
                items.append(self._clean_membership(item))
        self.logger.info(f"Found {len(items)} active members in family {family_id}.")
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

        # Notify the target user about approval/denial
        if approve:
            self.notification_helper.create_notification_async(
                user_id=target_user_id,
                admin_user=admin_user_id,
                notification_type=FamliyNotificationType.MEMBERSHIP_APPROVED,
                family_id=family_id,
            )
        else:
            self.notification_helper.create_notification_async(
                user_id=target_user_id,
                admin_user=admin_user_id,
                notification_type=FamliyNotificationType.FAMILY_MEMBERSHIP_DENIED,
                family_id=family_id,
            )

        return after

    @staticmethod
    def _clean_membership(item: FamilyMembershipModel) -> dict:
        return FamilyMembershipModel.clean_returned_membership(item)
