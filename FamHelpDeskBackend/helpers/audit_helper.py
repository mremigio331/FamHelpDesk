from models.audit import AuditModel, AuditActions, AuditEntityTypes
from typing import List, Dict, Any, Optional, Tuple
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger
import time


class AuditHelper:
    def __init__(
        self, request_id: str = None, stage: str = None, table_name: str = None
    ):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        AuditModel.set_stage_and_table(stage, table_name, notification_topic_arn)

    # Family-based audit methods
    def create_family_audit_record(
        self,
        family_id: str,
        entity_type: AuditEntityTypes,
        entity_id: str,
        action: AuditActions,
        actor_user_id: str,
        before: Optional[Dict[str, Any]] = None,
        after: Optional[Dict[str, Any]] = None,
    ) -> AuditModel:
        """
        Create a new audit record for family-related entities.

        Args:
            family_id: The family ID this audit belongs to
            entity_type: Type of entity being audited
            entity_id: Unique identifier of the entity
            action: The action performed
            actor_user_id: User who performed the action
            before: Entity state before the action (optional)
            after: Entity state after the action (optional)

        Returns:
            AuditModel: The created audit record
        """
        timestamp = int(time.time())

        audit_record = AuditModel(
            pk=AuditModel.create_pk(family_id),
            sk=AuditModel.create_sk(
                entity_type.value, entity_id, timestamp, action.value
            ),
            family_id=family_id,
            entity_type=entity_type.value,
            entity_id=entity_id,
            action=action.value,
            actor_user_id=actor_user_id,
            time=timestamp,
        )

        if before:
            audit_record.before = before
        if after:
            audit_record.after = after

        audit_record.save()

        self.logger.info(
            f"Created family audit record for {entity_type.value} {entity_id} "
            f"action {action.value} by user {actor_user_id}"
        )

        return audit_record

    def get_family_audit_record(
        self,
        family_id: str,
        entity_type: AuditEntityTypes,
        entity_id: str,
        timestamp: int,
        action: AuditActions,
    ) -> Optional[AuditModel]:
        """
        Get a specific audit record by its identifiers.

        Args:
            family_id: The family ID
            entity_type: Type of entity
            entity_id: Unique identifier of the entity
            timestamp: The timestamp of the audit record
            action: The action that was performed

        Returns:
            AuditModel or None: The audit record if found
        """
        try:
            return AuditModel.get(
                AuditModel.create_pk(family_id),
                AuditModel.create_sk(
                    entity_type.value, entity_id, timestamp, action.value
                ),
            )
        except DoesNotExist:
            self.logger.info(
                f"No audit record found for {entity_type.value} {entity_id} "
                f"at timestamp {timestamp} with action {action.value}"
            )
            return None

    def get_all_family_audit_records(
        self, family_id: str, limit: int = 50, last_evaluated_key: Optional[Dict] = None
    ) -> Tuple[List[AuditModel], Optional[Dict]]:
        """
        Get all audit records for a family with pagination.

        Args:
            family_id: The family ID to get audit records for
            limit: Maximum number of records to return (default: 50)
            last_evaluated_key: Pagination key from previous query

        Returns:
            Tuple[List[AuditModel], Optional[Dict]]: Records and next pagination key
        """
        try:
            query_kwargs = {
                "scan_index_forward": False,  # Get most recent first
                "limit": limit,
            }

            if last_evaluated_key:
                query_kwargs["last_evaluated_key"] = last_evaluated_key

            response = AuditModel.query(AuditModel.create_pk(family_id), **query_kwargs)

            records = list(response)
            next_key = (
                response.last_evaluated_key
                if hasattr(response, "last_evaluated_key")
                else None
            )

            self.logger.info(
                f"Retrieved {len(records)} audit records for family {family_id}"
            )
            return records, next_key

        except DoesNotExist:
            self.logger.info(f"No audit records found for family {family_id}")
            return [], None

    # User profile audit methods
    def create_user_audit_record(
        self,
        user_id: str,
        action: AuditActions,
        before: Optional[Dict[str, Any]] = None,
        after: Optional[Dict[str, Any]] = None,
    ) -> AuditModel:
        """
        Create a new audit record for user profile changes.

        Args:
            user_id: The user ID whose profile changed
            action: The action performed
            before: Entity state before the action (optional)
            after: Entity state after the action (optional)

        Returns:
            AuditModel: The created audit record
        """
        timestamp = int(time.time())

        audit_record = AuditModel(
            pk=AuditModel.create_user_profile_pk(user_id),
            sk=AuditModel.create_sk(
                AuditEntityTypes.USER_PROFILE.value, user_id, timestamp, action.value
            ),
            entity_type=AuditEntityTypes.USER_PROFILE.value,
            entity_id=user_id,
            action=action.value,
            actor_user_id=user_id,
            time=timestamp,
        )

        if before:
            audit_record.before = before
        if after:
            audit_record.after = after

        audit_record.save()

        self.logger.info(
            f"Created user audit record for user {user_id} " f"action {action.value}"
        )

        return audit_record

    def get_user_audit_record(
        self, user_id: str, timestamp: int, action: AuditActions
    ) -> Optional[AuditModel]:
        """
        Get a specific user profile audit record by its identifiers.

        Args:
            user_id: The user ID
            timestamp: The timestamp of the audit record
            action: The action that was performed

        Returns:
            AuditModel or None: The audit record if found
        """
        try:
            return AuditModel.get(
                AuditModel.create_user_profile_pk(user_id),
                AuditModel.create_sk(
                    AuditEntityTypes.USER_PROFILE.value,
                    user_id,
                    timestamp,
                    action.value,
                ),
            )
        except DoesNotExist:
            self.logger.info(
                f"No user audit record found for user {user_id} "
                f"at timestamp {timestamp} with action {action.value}"
            )
            return None

    def get_all_user_audit_records(
        self, user_id: str, limit: int = 50, last_evaluated_key: Optional[Dict] = None
    ) -> Tuple[List[AuditModel], Optional[Dict]]:
        """
        Get all audit records for a user profile with pagination.

        Args:
            user_id: The user ID to get audit records for
            limit: Maximum number of records to return (default: 50)
            last_evaluated_key: Pagination key from previous query

        Returns:
            Tuple[List[AuditModel], Optional[Dict]]: Records and next pagination key
        """
        try:
            query_kwargs = {
                "scan_index_forward": False,  # Get most recent first
                "limit": limit,
            }

            if last_evaluated_key:
                query_kwargs["last_evaluated_key"] = last_evaluated_key

            response = AuditModel.query(
                AuditModel.create_user_profile_pk(user_id), **query_kwargs
            )

            records = list(response)
            next_key = (
                response.last_evaluated_key
                if hasattr(response, "last_evaluated_key")
                else None
            )

            self.logger.info(
                f"Retrieved {len(records)} user audit records for user {user_id}"
            )
            return records, next_key

        except DoesNotExist:
            self.logger.info(f"No user audit records found for user {user_id}")
            return [], None

    def get_all_user_audits(self, user_id: str) -> List[AuditModel]:
        """
        Get all audit records for a user profile without manual pagination handling.

        Args:
            user_id: The user ID to get audit records for

        Returns:
            List[AuditModel]: All audit records for the user
        """
        all_records = []
        last_evaluated_key = None

        while True:
            records, last_evaluated_key = self.get_all_user_audit_records(
                user_id, last_evaluated_key=last_evaluated_key
            )
            all_records.extend(records)

            if not last_evaluated_key:
                break

        self.logger.info(
            f"Retrieved all {len(all_records)} audit records for user {user_id}"
        )
        return all_records

    def get_users_from_ticket_audit(self, family_id: str, ticket_id: str) -> List[str]:
        """
        Get all unique user IDs who have interacted with a ticket based on audit records.
        Returns deduplicated list of user IDs.

        Args:
            family_id: The family ID
            ticket_id: The ticket ID to query audit records for

        Returns:
            List[str]: Deduplicated list of user IDs who have audit records for the ticket
        """
        pk = AuditModel.create_pk(family_id)
        sk_prefix = f"AUDIT#TICKET#{ticket_id}#"

        user_ids = set()

        try:
            for audit in AuditModel.query(pk, AuditModel.sk.startswith(sk_prefix)):
                user_ids.add(audit.actor_user_id)

            if not user_ids:
                self.logger.warning(
                    f"No audit records found for ticket {ticket_id} in family {family_id}"
                )
            else:
                self.logger.info(
                    f"Found {len(user_ids)} unique users with audit records for ticket {ticket_id}"
                )
        except Exception as e:
            self.logger.error(
                f"Error querying audit records for ticket {ticket_id} in family {family_id}: {str(e)}"
            )
            raise

        return list(user_ids)
