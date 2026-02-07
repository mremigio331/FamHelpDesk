from typing import Optional, List
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger
import uuid
import time

from models.ticket_comment import TicketCommentModel
from helpers.ticket_helper import TicketHelper
from helpers.audit_helper import AuditHelper
from helpers.entity_ref import EntityRefHelper
from models.audit import AuditActions, AuditEntityTypes
from exceptions.ticket_exceptions import (
    CommentNotFoundException,
    CommentEditWindowExpiredException,
    UnauthorizedCommentModificationException,
)


class TicketCommentHelper:
    def __init__(
        self,
        request_id: str = None,
        stage: str = None,
        table_name: str = None,
        notification_queue_url: str = None,
    ):
        """
        Initialize TicketCommentHelper with logger and audit support.

        Args:
            request_id: Optional request ID for logging correlation
            stage: Optional stage to override model configuration
            table_name: Optional table name to override model configuration
        """
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.request_id = request_id
        TicketCommentModel.set_stage_and_table(
            stage, table_name, notification_queue_url
        )
        self.audit_helper = AuditHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )
        self.ticket_helper = TicketHelper(
            request_id=request_id,
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        )

    def create_comment(
        self,
        ticket_id: str,
        comment_user: str,
        comment_body: str,
    ) -> dict:
        """
        Create a new comment for a ticket.

        Args:
            ticket_id: The ticket ID
            comment_user: The user creating the comment
            comment_body: The comment content

        Returns:
            dict: The created comment with enriched EntityRef data

        Raises:
            TicketNotFoundException: If the ticket doesn't exist
        """
        self.logger.info(
            "Creating comment for ticket",
            extra={
                "ticket_id": ticket_id,
                "comment_user": comment_user,
            },
        )

        # Get ticket details
        ticket = self.ticket_helper.get_ticket_by_id(ticket_id)
        family_id = ticket.family_id
        group_id = ticket.group_id
        queue_id = ticket.queue_id

        self.logger.info(
            "Retrieved ticket details for comment creation",
            extra={
                "ticket_id": ticket_id,
                "family_id": family_id,
                "group_id": group_id,
                "queue_id": queue_id,
            },
        )

        # Generate comment_id using UUID
        comment_id = TicketCommentModel.generate_random_id(prefix="C")

        # Set comment_date and last_update to current epoch
        current_time = TicketCommentModel.now_epoch()

        # Create comment with all required fields
        comment = TicketCommentModel(
            pk=TicketCommentModel.create_pk(family_id),
            sk=TicketCommentModel.create_sk(ticket_id, comment_id),
            family_id=family_id,
            group_id=group_id,
            queue_id=queue_id,
            ticket_id=ticket_id,
            comment_id=comment_id,
            comment_user=comment_user,
            comment_body=comment_body,
            comment_date=current_time,
            last_update=current_time,
        )

        # Save comment to DynamoDB
        try:
            comment.save()
            self.logger.info(f"Successfully saved comment {comment_id} to DynamoDB")
        except Exception as e:
            self.logger.error(
                f"Failed to save comment {comment_id} to DynamoDB: {str(e)}",
                exc_info=True,
            )
            raise

        # Update the ticket's last_update timestamp when a comment is created
        try:
            self.ticket_helper.update_last_update(family_id, ticket_id)
            self.logger.info(
                f"Successfully updated ticket {ticket_id} last_update timestamp"
            )
        except Exception as e:
            self.logger.error(
                f"Failed to update ticket {ticket_id} last_update timestamp: {str(e)}",
                exc_info=True,
            )
            raise

        # Create audit record with action CREATE
        try:
            self.audit_helper.create_family_audit_record(
                family_id=family_id,
                entity_type=AuditEntityTypes.COMMENT,
                entity_id=comment_id,
                action=AuditActions.CREATE,
                actor_user_id=comment_user,
                after=TicketCommentModel.clean_returned_comment_for_audit(comment),
            )
            self.logger.info(
                f"Successfully created audit record for comment {comment_id}"
            )
        except Exception as e:
            self.logger.error(
                f"Failed to create audit record for comment {comment_id}: {str(e)}",
                exc_info=True,
            )
            raise

        self.logger.info(
            "Comment created successfully",
            extra={
                "comment_id": comment_id,
                "family_id": family_id,
                "ticket_id": ticket_id,
            },
        )

        # Return enriched comment data
        comment_dict = TicketCommentModel.clean_returned_comment(comment)
        return EntityRefHelper.enrich_entity_refs(comment_dict)

    def can_modify_comment(
        self, comment: TicketCommentModel, requesting_user: str
    ) -> None:
        """
        Check if a user can modify (update or delete) a comment.
        Raises specific exceptions if modification is not allowed.

        Args:
            comment: The comment to check
            requesting_user: The user requesting the modification

        Raises:
            UnauthorizedCommentModificationException: If requesting user is not the comment author
            CommentEditWindowExpiredException: If the 4-hour edit window has expired
        """
        # Check if requesting_user matches comment_user
        if requesting_user != comment.comment_user:
            raise UnauthorizedCommentModificationException(
                f"User {requesting_user} is not authorized to modify comment {comment.comment_id} "
                f"created by {comment.comment_user}"
            )

        # Check if current time minus comment_date is less than 4 hours (14400 seconds)
        current_time = int(time.time())
        time_since_creation = current_time - comment.comment_date

        # Raise exception if outside 4-hour edit window
        if time_since_creation >= 14400:
            raise CommentEditWindowExpiredException(
                f"Comment {comment.comment_id} can no longer be modified. "
                f"Edit window expired {time_since_creation - 14400} seconds ago"
            )

    def update_comment(
        self,
        ticket_id: str,
        comment_id: str,
        requesting_user: str,
        comment_body: str,
    ) -> dict:
        """
        Update an existing comment's body.

        Args:
            ticket_id: The ticket ID
            comment_id: The comment ID to update
            requesting_user: The user requesting the update
            comment_body: The new comment content

        Returns:
            dict: The updated comment with enriched EntityRef data

        Raises:
            TicketNotFoundException: If the ticket doesn't exist
            CommentNotFoundException: If the comment doesn't exist
            UnauthorizedCommentModificationException: If user is not the comment author
            CommentEditWindowExpiredException: If the 4-hour edit window has expired
        """
        self.logger.info(
            "Updating comment",
            extra={
                "ticket_id": ticket_id,
                "comment_id": comment_id,
                "requesting_user": requesting_user,
            },
        )

        # Get ticket details
        ticket = self.ticket_helper.get_ticket_by_id(ticket_id)
        family_id = ticket.family_id

        # Retrieve existing comment
        try:
            comment = TicketCommentModel.get(
                hash_key=TicketCommentModel.create_pk(family_id),
                range_key=TicketCommentModel.create_sk(ticket_id, comment_id),
            )
        except DoesNotExist:
            raise CommentNotFoundException(
                f"Comment {comment_id} not found for ticket {ticket_id}"
            )

        # Verify authorization using can_modify_comment
        self.can_modify_comment(comment, requesting_user)

        # Capture before state for audit
        before_state = TicketCommentModel.clean_returned_comment_for_audit(comment)

        # Update comment_body
        comment.comment_body = comment_body

        # Set last_update to current epoch
        comment.last_update = TicketCommentModel.now_epoch()

        # Save updated comment
        comment.save()

        # Create audit record with before and after states
        after_state = TicketCommentModel.clean_returned_comment_for_audit(comment)
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.COMMENT,
            entity_id=comment_id,
            action=AuditActions.UPDATE,
            actor_user_id=requesting_user,
            before=before_state,
            after=after_state,
        )

        self.logger.info(
            "Comment updated successfully",
            extra={
                "comment_id": comment_id,
                "family_id": family_id,
                "ticket_id": ticket_id,
            },
        )

        # Return enriched comment data
        comment_dict = TicketCommentModel.clean_returned_comment(comment)
        return EntityRefHelper.enrich_entity_refs(comment_dict)

    def delete_comment(
        self,
        ticket_id: str,
        comment_id: str,
        requesting_user: str,
    ) -> bool:
        """
        Delete an existing comment.

        Args:
            ticket_id: The ticket ID
            comment_id: The comment ID to delete
            requesting_user: The user requesting the deletion

        Returns:
            bool: True if deletion was successful

        Raises:
            TicketNotFoundException: If the ticket doesn't exist
            CommentNotFoundException: If the comment doesn't exist
            UnauthorizedCommentModificationException: If user is not the comment author
            CommentEditWindowExpiredException: If the 4-hour edit window has expired
        """
        self.logger.info(
            "Deleting comment",
            extra={
                "ticket_id": ticket_id,
                "comment_id": comment_id,
                "requesting_user": requesting_user,
            },
        )

        # Get ticket details
        ticket = self.ticket_helper.get_ticket_by_id(ticket_id)
        family_id = ticket.family_id

        # Retrieve existing comment
        try:
            comment = TicketCommentModel.get(
                hash_key=TicketCommentModel.create_pk(family_id),
                range_key=TicketCommentModel.create_sk(ticket_id, comment_id),
            )
        except DoesNotExist:
            raise CommentNotFoundException(
                f"Comment {comment_id} not found for ticket {ticket_id}"
            )

        # Verify authorization using can_modify_comment
        self.can_modify_comment(comment, requesting_user)

        # Capture comment data for audit
        before_state = TicketCommentModel.clean_returned_comment_for_audit(comment)

        # Delete comment from DynamoDB
        comment.delete()

        # Create audit record with action DELETE
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.COMMENT,
            entity_id=comment_id,
            action=AuditActions.DELETE,
            actor_user_id=requesting_user,
            before=before_state,
        )

        self.logger.info(
            "Comment deleted successfully",
            extra={
                "comment_id": comment_id,
                "family_id": family_id,
                "ticket_id": ticket_id,
            },
        )

        # Return success boolean
        return True

    def get_comments_for_ticket(self, ticket_id: str) -> List[dict]:
        """
        Query all comments for a specific ticket, ordered by comment_date ascending.

        Args:
            ticket_id: The ticket ID to retrieve comments for

        Returns:
            List[dict]: List of enriched comment dictionaries ordered by comment_date ascending

        Raises:
            TicketNotFoundException: If the ticket doesn't exist
        """
        self.logger.info(
            "Retrieving comments for ticket",
            extra={
                "ticket_id": ticket_id,
            },
        )

        # Get ticket details
        ticket = self.ticket_helper.get_ticket_by_id(ticket_id)
        family_id = ticket.family_id

        comments: List[TicketCommentModel] = []
        sk_prefix = f"TICKET#{ticket_id}#COMMENT#"

        # Query all comments with SK prefix TICKET#{ticket_id}#COMMENT#
        for comment in TicketCommentModel.query(
            hash_key=TicketCommentModel.create_pk(family_id),
            range_key_condition=TicketCommentModel.sk.startswith(sk_prefix),
        ):
            comments.append(comment)

        # Sort results by comment_date ascending
        comments.sort(key=lambda c: c.comment_date)

        # Convert to clean dictionaries
        comment_dicts = [
            TicketCommentModel.clean_returned_comment(comment) for comment in comments
        ]

        # Enrich with EntityRef names
        enriched_comments = EntityRefHelper.enrich_entity_refs(comment_dicts)

        self.logger.info(
            "Retrieved comments for ticket",
            extra={
                "ticket_id": ticket_id,
                "comment_count": len(enriched_comments),
            },
        )

        return enriched_comments
