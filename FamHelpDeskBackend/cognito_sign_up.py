import os
import boto3
import json
from typing import Dict, Tuple
from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext
from helpers.user_profile_helper import UserProfileHelper
from helpers.notification_helper import NotificationHelper
from models.notification import NotificationType
from constants.services import COGNITO_SIGNUP_SERVICE

logger = Logger(service=COGNITO_SIGNUP_SERVICE)


class UserProfileCreationError(Exception):
    """Raised when user profile creation fails - this should fail the Lambda."""

    pass


def send_admin_notification(topic_arn: str, subject: str, message: str) -> None:
    """Send notification to admin SNS topic. Logs errors but doesn't raise."""
    try:
        sns = boto3.client("sns")
        sns.publish(TopicArn=topic_arn, Subject=subject, Message=message)
        logger.info("Published notification to admin SNS topic")
    except Exception as e:
        logger.error("Failed to publish to admin SNS topic", exc_info=e)


def send_welcome_notification(user_id: str, request_id: str, stage: str) -> None:
    """Send welcome notification to new user via notification queue. Logs errors but doesn't raise."""
    try:
        notification_queue_url = os.environ.get("NOTIFICATION_QUEUE_URL")
        if not notification_queue_url:
            logger.warning(
                "NOTIFICATION_QUEUE_URL not set, skipping welcome notification"
            )
            return

        notification_helper = NotificationHelper(
            request_id=request_id,
            stage=stage,
            table_name=os.environ.get("TABLE_NAME"),
            notification_queue_url=notification_queue_url,
        )
        notification_helper.create_notification_async(
            notification_type=NotificationType.WELCOME,
            user_id=user_id,
        )
        logger.info(f"Sent welcome notification to user {user_id}")
    except Exception as e:
        logger.error("Failed to send welcome notification", exc_info=e)


def create_user_profile(
    user_id: str,
    email: str,
    full_name: str,
    provider: str,
    request_id: str,
    stage: str,
) -> None:
    """
    Create user profile and send notifications.

    Raises:
        UserProfileCreationError: If user profile creation fails (critical error)

    Note: Notification failures are logged but don't raise exceptions.
    """
    try:
        user_profile_helper = UserProfileHelper(request_id=request_id)

        # Check if user profile already exists to prevent duplicates
        existing_profile = user_profile_helper.get_profile(user_id)
        if existing_profile:
            logger.info(f"User profile already exists for {user_id}, skipping creation")
            return

        # Create user profile - THIS IS THE CRITICAL OPERATION
        user_profile_helper.create_profile(
            user_id=user_id,
            display_name=full_name,
            provider=provider,
            email=email,
        )
        logger.info(f"Created user profile for {user_id}")

    except Exception as e:
        # User profile creation failed - this is critical, raise specific exception
        logger.error("CRITICAL: User profile creation failed", exc_info=e)
        raise UserProfileCreationError(
            f"Failed to create user profile for {user_id}: {e}"
        ) from e

    # User profile created successfully - now send notifications
    # These are non-critical, so we log errors but don't raise

    # Send welcome notification to user
    send_welcome_notification(user_id, request_id, stage)

    # Send admin notification
    topic_arn = os.environ.get("USER_ADDED_TOPIC_ARN")
    if topic_arn:
        send_admin_notification(
            topic_arn=topic_arn,
            subject=f"New FamHelpDesk {stage} User Signup",
            message=f"New user signed up:\nID: {user_id}\nEmail: {email}\nName: {full_name}\nProvider: {provider}",
        )


def extract_user_info(event: Dict) -> Tuple[str, str, str, str]:
    """
    Extract user information from Cognito event.

    Returns:
        Tuple of (user_id, email, full_name, provider)
    """
    user_attrs = event["request"]["userAttributes"]
    logger.info(f"User attributes: {user_attrs}")

    user_id = user_attrs["sub"]
    email = user_attrs.get("email")
    full_name = user_attrs.get("name") or user_attrs.get("given_name") or "unknown"

    # Determine provider (Cognito, Google, Apple, etc.)
    provider = "Cognito"
    identities = user_attrs.get("identities")
    if identities:
        try:
            identities_list = json.loads(identities)
            if identities_list:
                provider = identities_list[0].get("providerName", provider)
                logger.info(f"User signed up with federated provider: {provider}")
        except Exception as e:
            logger.warning(f"Failed to parse identities attribute", exc_info=e)

    if provider == "Cognito":
        # Fallback: usernames for federated users are often like 'Google_XXXXXXXX'
        uname = event.get("userName") or ""
        if "_" in uname:
            possible_provider = uname.split("_", 1)[0]
            if possible_provider and possible_provider.lower() != "cognito":
                provider = possible_provider
                logger.info(f"Derived provider from userName: {provider}")

    return user_id, email, full_name, provider


@logger.inject_lambda_context
def handler(event: dict, context: LambdaContext) -> dict:
    """Handle Cognito PostConfirmation trigger."""
    logger.info("POST_CONFIRMATION Lambda triggered")
    stage = os.getenv("STAGE")

    # Handle any PostConfirmation variant
    if not event.get("triggerSource", "").startswith("PostConfirmation_"):
        logger.warning(f"Unsupported triggerSource: {event.get('triggerSource')}")
        return event

    # Extract user information from event
    user_id, email, full_name, provider = extract_user_info(event)

    try:
        # Create user profile and send notifications
        create_user_profile(
            user_id=user_id,
            email=email,
            full_name=full_name,
            provider=provider,
            request_id=context.aws_request_id,
            stage=stage,
        )

        # Success! User profile created (notifications may have failed but that's ok)
        logger.info(f"User signup completed successfully for {user_id}")
        return event

    except UserProfileCreationError as e:
        # CRITICAL: User profile creation failed - this should fail the Lambda
        logger.error(
            "CRITICAL: User profile creation failed, failing Lambda", exc_info=e
        )

        # Send failure notification to admins
        topic_arn = os.environ.get("USER_ADDED_TOPIC_ARN")
        if topic_arn:
            send_admin_notification(
                topic_arn=topic_arn,
                subject="FamHelpDesk User Signup FAILED",
                message=f"User signup FAILED:\nID: {user_id}\nEmail: {email}\nName: {full_name}\nProvider: {provider}\nError: {e}",
            )

        # Re-raise to fail the Lambda and show error to user
        raise
