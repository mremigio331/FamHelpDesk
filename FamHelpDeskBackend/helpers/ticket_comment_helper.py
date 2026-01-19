from typing import Optional, List
from pynamodb.exceptions import DoesNotExist
from aws_lambda_powertools import Logger
import uuid
import time

from models.ticket_comment import TicketCommentModel
from helpers.ticket_helper import TicketHelper
from helpers.audit_helper import AuditHelper
from models.audit import AuditActions, AuditEntityTypes
from exceptions.ticket_exceptions import (
    CommentNotFoundException,
    CommentEditWindowExpiredException,
    UnauthorizedCommentModificationException,
)


class TicketCommentHelper:
    def __init__(self, request_id: str = None):
        """
        Initialize TicketCommentHelper with logger and audit support.

        Args:
            request_id: Optional request ID for logging correlation
        """
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.request_id = request_id
        self.audit_helper = AuditHelper(request_id=request_id)
        self.ticket_helper = TicketHelper(request_id=request_id)

    def create_comment(
        self,
        family_id: str,
        ticket_id: str,
        comment_user: str,
        comment_body: str,
        group_id: str = None,
        queue_id: str = None,
    ) -> TicketCommentModel:
        """
        Create a new comment for a ticket.

        Args:
            family_id: The family ID
            ticket_id: The ticket ID
            comment_user: The user creating the comment
            comment_body: The comment content
            group_id: The group ID (optional, for backward compatibility)
            queue_id: The queue ID (optional, for backward compatibility)

        Returns:
            TicketCommentModel: The created comment
        """
        self.logger.info(
            "Creating comment for ticket",
            extra={
                "family_id": family_id,
                "ticket_id": ticket_id,
                "comment_user": comment_user,
            },
        )

        # Generate comment_id using UUID
        comment_id = TicketCommentModel.generate_uuid()

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
        comment.save()

        # Update the ticket's last_update timestamp when a comment is created
        self.ticket_helper.update_last_update(family_id, ticket_id)

        # Create audit record with action CREATE
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.TICKET_COMMENT,
            entity_id=comment_id,
            action=AuditActions.CREATE,
            actor_user_id=comment_user,
            after=TicketCommentModel.clean_returned_comment(comment),
        )

        self.logger.info(
            "Comment created successfully",
            extra={
                "comment_id": comment_id,
                "family_id": family_id,
                "ticket_id": ticket_id,
            },
        )

        return comment

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
        family_id: str,
        ticket_id: str,
        comment_id: str,
        requesting_user: str,
        comment_body: str,
        group_id: str = None,
        queue_id: str = None,
    ) -> TicketCommentModel:
        """
        Update an existing comment's body.

        Args:
            family_id: The family ID
            ticket_id: The ticket ID
            comment_id: The comment ID to update
            requesting_user: The user requesting the update
            comment_body: The new comment content
            group_id: The group ID (optional, for backward compatibility)
            queue_id: The queue ID (optional, for backward compatibility)

        Returns:
            TicketCommentModel: The updated comment

        Raises:
            CommentNotFoundException: If the comment doesn't exist
            UnauthorizedCommentModificationException: If user is not the comment author
            CommentEditWindowExpiredException: If the 4-hour edit window has expired
        """
        self.logger.info(
            "Updating comment",
            extra={
                "family_id": family_id,
                "ticket_id": ticket_id,
                "comment_id": comment_id,
                "requesting_user": requesting_user,
            },
        )

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
        before_state = TicketCommentModel.clean_returned_comment(comment)

        # Update comment_body
        comment.comment_body = comment_body

        # Set last_update to current epoch
        comment.last_update = TicketCommentModel.now_epoch()

        # Save updated comment
        comment.save()

        # Create audit record with before and after states
        after_state = TicketCommentModel.clean_returned_comment(comment)
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.TICKET_COMMENT,
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

        return comment

    def delete_comment(
        self,
        family_id: str,
        ticket_id: str,
        comment_id: str,
        requesting_user: str,
        group_id: str = None,
        queue_id: str = None,
    ) -> bool:
        """
        Delete an existing comment.

        Args:
            family_id: The family ID
            ticket_id: The ticket ID
            comment_id: The comment ID to delete
            requesting_user: The user requesting the deletion
            group_id: The group ID (optional, for backward compatibility)
            queue_id: The queue ID (optional, for backward compatibility)

        Returns:
            bool: True if deletion was successful

        Raises:
            CommentNotFoundException: If the comment doesn't exist
            UnauthorizedCommentModificationException: If user is not the comment author
            CommentEditWindowExpiredException: If the 4-hour edit window has expired
        """
        self.logger.info(
            "Deleting comment",
            extra={
                "family_id": family_id,
                "ticket_id": ticket_id,
                "comment_id": comment_id,
                "requesting_user": requesting_user,
            },
        )

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
        before_state = TicketCommentModel.clean_returned_comment(comment)

        # Delete comment from DynamoDB
        comment.delete()

        # Create audit record with action DELETE
        self.audit_helper.create_family_audit_record(
            family_id=family_id,
            entity_type=AuditEntityTypes.TICKET_COMMENT,
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

    def get_comments_for_ticket(
        self, family_id: str, ticket_id: str, group_id: str = None, queue_id: str = None
    ) -> List[TicketCommentModel]:
        """
        Query all comments for a specific ticket, ordered by comment_date ascending.

        Args:
            family_id: The family ID
            ticket_id: The ticket ID to retrieve comments for
            group_id: The group ID (optional, for backward compatibility)
            queue_id: The queue ID (optional, for backward compatibility)

        Returns:
            List[TicketCommentModel]: List of comments ordered by comment_date ascending
        """
        self.logger.info(
            "Retrieving comments for ticket",
            extra={
                "family_id": family_id,
                "ticket_id": ticket_id,
            },
        )

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

        self.logger.info(
            "Retrieved comments for ticket",
            extra={
                "family_id": family_id,
                "ticket_id": ticket_id,
                "comment_count": len(comments),
            },
        )

        return comments
