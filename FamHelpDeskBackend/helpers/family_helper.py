from typing import Optional, List
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger

from models.family import FamilyModel
from helpers.audit_helper import AuditHelper
from helpers.family_membership_helper import FamilyMembershipHelper
from models.audit import AuditActions, AuditEntityTypes


class FamilyHelper:
    def __init__(self, request_id: str = None):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.request_id = request_id
        self.audit_helper = AuditHelper(request_id=request_id)

    def create_family(
        self,
        family_name: str,
        created_by: str,
        family_description: Optional[str] = None,
    ) -> FamilyModel:
        family_id = FamilyModel.generate_uuid()
        creation_date = FamilyModel.now_epoch()

        family = FamilyModel(
            pk=FamilyModel.create_pk(family_id),
            sk=FamilyModel.create_sk(),
            family_id=family_id,
            family_name=family_name,
            created_by=created_by,
            creation_date=creation_date,
        )

        if family_description is not None:
            family.family_description = family_description

        family.save()
        self.logger.info(f"Created family {family_id}")

        # Audit record for creation
        family_data = self._clean_family(family)
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.FAMILY,
            entity_id=family_id,
            action=AuditActions.CREATE,
            actor_user_id=created_by,
            after=family_data,
        )

        family_membership_helper = FamilyMembershipHelper(request_id=self.request_id)
        family_membership_helper.create_membership(
            family_id=family_id,
            user_id=created_by,
            is_admin=True,
        )

        return family

    def get_family(self, family_id: str) -> FamilyModel | None:
        try:
            family = FamilyModel.get(
                FamilyModel.create_pk(family_id),
                FamilyModel.create_sk(),
            )
            return family
        except DoesNotExist:
            self.logger.info(f"No family found for {family_id}.")
            return None

    def get_all_families(self) -> List[FamilyModel]:
        """Return all family META records."""
        items = []
        # Filter scan to META records and then ensure pk starts with FAMILY#
        for item in FamilyModel.scan(FamilyModel.sk == "META"):
            if str(item.pk).startswith("FAMILY#"):
                items.append(item)
        self.logger.info(f"Fetched {len(items)} families.")
        return items

    def update_family(
        self, family_id: str, actor_user_id: str, **kwargs
    ) -> FamilyModel:
        family = self.get_family(family_id)
        if not family:
            raise ValueError("Family does not exist")

        # Capture old state for auditing
        old_family_data = self._clean_family(family)

        # Only allow updates to specific fields
        allowed_fields = {"family_name", "family_description"}
        for key, value in kwargs.items():
            if key in allowed_fields and hasattr(family, key):
                setattr(family, key, value)

        family.save()
        self.logger.info(f"Updated family {family_id}")

        # Audit record for update
        new_family_data = self._clean_family(family)
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.FAMILY,
            entity_id=family_id,
            action=AuditActions.UPDATE,
            actor_user_id=actor_user_id,
            before=old_family_data,
            after=new_family_data,
        )

        return family

    @staticmethod
    def _clean_family(family: FamilyModel) -> dict:
        return FamilyModel.clean_returned_family(family)
