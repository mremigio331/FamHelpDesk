"""
User Deletion Lambda

Deletes one or more users and all their associated data from the system.

Example invocation payloads:

Single user:
{
    "user_id": "user-123",
    "send_confirmation_email": true
}

Multiple users:
{
    "user_ids": ["user-123", "user-456", "user-789"],
    "send_confirmation_email": false
}
"""

import os
import boto3
import json
from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext
from helpers.user_profile_helper import UserProfileHelper
from helpers.notification_settings_helper import NotificationSettingsHelper
from exceptions.user_exceptions import UserNotFound
from helpers.family_helper import FamilyMembershipHelper
from helpers.group_helper import GroupMembershipHelper
from helpers.notification_helper import NotificationHelper
from typing import Dict, Any
from models.user_profile import UserProfile
from helpers.audit_helper import AuditHelper


logger = Logger(service="FamHelpDesk-Cognito-User-Delete")


def lambda_handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    logger.info(f"User deletion event: {event}")

    # Check if we have a list of users or a single user
    user_ids = event.get("user_ids")
    user_id = event.get("user_id")

    if user_ids:
        # Process multiple users
        if not isinstance(user_ids, list):
            logger.error("'user_ids' must be a list")
            raise ValueError("'user_ids' must be a list")
        logger.info(f"Processing deletion for {len(user_ids)} users")
    elif user_id:
        # Convert single user to list for uniform processing
        user_ids = [user_id]
        logger.info(f"Processing deletion for single user_id: {user_id}")
    else:
        logger.error("Missing 'user_id' or 'user_ids' in event payload")
        raise ValueError("Missing required field: user_id or user_ids")

    send_confirmation_email = event.get("send_confirmation_email", True)

    # Retrieve and validate environment variables
    logger.info("Validating environment variables...")
    stage = os.getenv("STAGE")
    region = os.getenv("COGNITO_REGION")
    user_pool_id = os.getenv("COGNITO_USER_POOL_ID")
    sender_email = os.getenv("SENDER_EMAIL")

    if not all([stage, region, user_pool_id, sender_email]):
        missing_vars = [
            var_name
            for var_name, value in {
                "STAGE": stage,
                "COGNITO_REGION": region,
                "COGNITO_USER_POOL_ID": user_pool_id,
                "SENDER_EMAIL": sender_email,
            }.items()
            if not value
        ]
        error_msg = f"Missing required environment variables: {', '.join(missing_vars)}"
        logger.error(error_msg)
        raise EnvironmentError(error_msg)

    request_id = event.get("request_id", context.aws_request_id)
    logger.info(f"Lambda request ID: {request_id}")

    # Track results for all users
    results = {
        "successful_deletions": [],
        "failed_deletions": [],
        "total_users": len(user_ids),
    }

    # Process each user
    for user_id in user_ids:
        logger.info(f"Starting deletion process for user_id: {user_id}")
        try:
            delete_single_user(
                user_id=user_id,
                request_id=request_id,
                stage=stage,
                region=region,
                user_pool_id=user_pool_id,
                sender_email=sender_email,
                send_confirmation_email=send_confirmation_email,
            )
            results["successful_deletions"].append(user_id)
            logger.info(f"Successfully completed deletion for user_id: {user_id}")
        except Exception as e:
            logger.error(f"Failed to delete user_id {user_id}: {e}", exc_info=True)
            results["failed_deletions"].append({"user_id": user_id, "error": str(e)})

    # Log final results
    logger.info(
        f"Deletion process completed. "
        f"Successful: {len(results['successful_deletions'])}, "
        f"Failed: {len(results['failed_deletions'])}"
    )

    return {
        "statusCode": 200,
        "message": f"Processed {results['total_users']} user(s)",
        "results": results,
    }


def delete_single_user(
    user_id: str,
    request_id: str,
    stage: str,
    region: str,
    user_pool_id: str,
    sender_email: str,
    send_confirmation_email: bool,
) -> None:
    """
    Delete a single user and all their associated data.

    Args:
        user_id: The user ID to delete
        request_id: Lambda request ID for logging
        stage: Environment stage
        region: AWS region
        user_pool_id: Cognito user pool ID
        sender_email: SES sender email
        send_confirmation_email: Whether to send confirmation email

    Raises:
        Exception: If any step of the deletion process fails
    """
    all_items = []

    try:
        user_profile_helper = UserProfileHelper(request_id=request_id)
        logger.info(f"Retrieving user profile for user_id: {user_id}")
        user_profile = user_profile_helper.get_profile(user_id)
        logger.info(f"Successfully retrieved user profile for user_id: {user_id}")
    except UserNotFound as e:
        logger.error(f"User with ID {user_id} not found: {e}")
        raise
    except Exception as e:
        logger.error(
            f"Unexpected error retrieving user profile for user_id {user_id}: {e}",
            exc_info=True,
        )
        raise

    all_items.append(user_profile)
    user_profile_clean = UserProfile.clean_returned_profile(user_profile)
    recipient_email = user_profile.email
    logger.info(f"User email: {recipient_email}")

    try:
        notification_settings_helper = NotificationSettingsHelper(request_id=request_id)
        logger.info(f"Retrieving notification settings for user_id: {user_id}")
        notification_settings = notification_settings_helper.get_settings(user_id)
        if notification_settings:
            all_items.append(notification_settings)
            logger.info(f"Found notification settings for user_id: {user_id}")
        else:
            logger.info(f"No notification settings found for user_id: {user_id}")
    except Exception as e:
        logger.warning(
            f"Error retrieving notification settings for user_id {user_id}: {e}"
        )

    try:
        family_membership_helper = FamilyMembershipHelper(request_id=request_id)
        logger.info(f"Retrieving family memberships for user_id: {user_id}")
        family_memberships = family_membership_helper.get_all_memberships_by_user_raw(
            user_id
        )
        all_items.extend(family_memberships)
        logger.info(
            f"Found {len(family_memberships)} family membership(s) for user_id: {user_id}"
        )
    except Exception as e:
        logger.error(
            f"Error retrieving family memberships for user_id {user_id}: {e}",
            exc_info=True,
        )
        raise

    try:
        group_membership_helper = GroupMembershipHelper(request_id=request_id)
        logger.info(f"Retrieving group memberships for user_id: {user_id}")
        group_memberships = group_membership_helper.get_all_memberships_by_user_raw(
            user_id
        )
        all_items.extend(group_memberships)
        logger.info(
            f"Found {len(group_memberships)} group membership(s) for user_id: {user_id}"
        )
    except Exception as e:
        logger.error(
            f"Error retrieving group memberships for user_id {user_id}: {e}",
            exc_info=True,
        )
        raise

    try:
        notification_helper = NotificationHelper(request_id=request_id)
        logger.info(f"Retrieving notifications for user_id: {user_id}")
        notifications = notification_helper.get_notifications(user_id=user_id, raw=True)
        notification_count = len(notifications.get("notifications", []))
        all_items.extend(notifications["notifications"])
        logger.info(
            f"Found {notification_count} notification(s) for user_id: {user_id}"
        )
    except Exception as e:
        logger.error(
            f"Error retrieving notifications for user_id {user_id}: {e}", exc_info=True
        )
        raise

    try:
        audit_helper = AuditHelper(request_id=request_id)
        logger.info(f"Retrieving audit logs for user_id: {user_id}")
        all_audits = audit_helper.get_all_user_audits(user_id)
        all_items.extend(all_audits)
        logger.info(f"Found {len(all_audits)} audit log(s) for user_id: {user_id}")
    except Exception as e:
        logger.error(
            f"Error retrieving audit logs for user_id {user_id}: {e}", exc_info=True
        )
        raise

    logger.info(f"Deleting {len(all_items)} item(s) for user_id: {user_id}")
    deleted_count = 0
    for idx, item in enumerate(all_items, 1):
        try:
            item.delete()
            deleted_count += 1
            logger.debug(f"Deleted item {idx}/{len(all_items)} for user_id: {user_id}")
        except Exception as e:
            logger.error(
                f"Error deleting item {idx}/{len(all_items)} for user_id {user_id}: {e}",
                exc_info=True,
            )
            raise
    logger.info(
        f"Successfully deleted {deleted_count}/{len(all_items)} items for user_id: {user_id}"
    )

    # Delete the Cognito user
    try:
        logger.info(
            f"Deleting Cognito user for user_id: {user_id} in user pool: {user_pool_id}"
        )
        cognito_client = boto3.client("cognito-idp", region_name=region)
        cognito_client.admin_delete_user(UserPoolId=user_pool_id, Username=user_id)
        logger.info(f"Cognito user {user_id} deletion completed")
    except Exception as e:
        logger.error(
            f"Failed to delete Cognito user {user_id}. Error: {e}", exc_info=True
        )
        raise

    if send_confirmation_email:
        try:
            logger.info(f"Sending confirmation email to {recipient_email}...")
            ses_client = boto3.client("ses", region_name=region)

            ses_client.send_email(
                Source=sender_email,
                Destination={"ToAddresses": [recipient_email]},
                Message={
                    "Subject": {"Data": "Account Deletion Confirmation"},
                    "Body": {
                        "Text": {
                            "Data": f"Hello {user_profile_clean['display_name']},\n\nYour account has been successfully deleted.\n\nThank you,\nFamHelpDesk Team"
                        }
                    },
                },
            )
            logger.info(f"Confirmation email successfully sent to {recipient_email}")
        except Exception as e:
            logger.error(
                f"Failed to send confirmation email to {recipient_email}. Error: {e}",
                exc_info=True,
            )
            raise

    logger.info(f"User deletion process completed successfully for user_id: {user_id}")
