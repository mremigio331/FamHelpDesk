import os
import boto3
import json
from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext
from helpers.user_profile_helper import UserProfileHelper

logger = Logger(service="FamHelpDesk-Cognito-User-Creator")


@logger.inject_lambda_context
def handler(event: dict, context: LambdaContext) -> dict:
    logger.info("POST_CONFIRMATION Lambda triggered.")

    if event["triggerSource"] == "PostConfirmation_ConfirmSignUp":
        user_attrs = event["request"]["userAttributes"]
        logger.info(f"User attributes: {user_attrs}")

        user_id = user_attrs["sub"]

        email = user_attrs.get("email")
        full_name = user_attrs.get("name", "unknown")
        nickname = user_attrs.get("nickname", full_name)

        # Determine provider (Cognito or Google)
        identities = user_attrs.get("identities")
        if identities:
            identities_list = json.loads(identities)
            provider = (
                identities_list[0].get("providerName", "Unknown")
                if identities_list
                else "Unknown"
            )
            logger.info(f"User signed up with federated provider: {provider}")
        else:
            provider = "Cognito"
            logger.info("User signed up with Cognito native provider.")

        try:
            user_profile_helper = UserProfileHelper(request_id=context.aws_request_id)
            user_profile_helper.create_profile(
                user_id=user_id,
                display_name=full_name,
                nick_name=nickname,
                provider=provider,
                email=email,
            )
            # Publish to SNS topic if ARN is set (success handled below)
        except Exception as e:
            logger.error(f"Failed to create user profile: {e}")
            # Publish error to SNS topic if possible
            topic_arn = os.environ.get("USER_ADDED_TOPIC_ARN")
            if topic_arn:
                sns = boto3.client("sns")
                error_message = f"User signup FAILED:\nID: {user_id}\nEmail: {email}\nName: {full_name}\nProvider: {provider}\nError: {e}"
                try:
                    response = sns.publish(
                        TopicArn=topic_arn,
                        Subject="FamHelpDesk User Signup FAILED",
                        Message=error_message,
                    )
                    logger.info(
                        f"Published signup failure to SNS topic: {topic_arn} with response: {response}"
                    )
                except Exception as sns_e:
                    logger.error(
                        f"Failed to publish signup failure to SNS topic: {sns_e}"
                    )
            raise

        try:
            topic_arn = os.environ.get("USER_ADDED_TOPIC_ARN")
            if topic_arn:
                sns = boto3.client("sns")
                response = sns.publish(
                    TopicArn=topic_arn,
                    Subject="New FamHelpDesk User Signup",
                    Message=f"New user signed up:\nID: {user_id}\nEmail: {email}\nName: {full_name}\nProvider: {provider}",
                )
                logger.info(
                    f"Published user signup to SNS topic: {topic_arn} with response: {response}"
                )
            else:
                logger.warning("USER_ADDED_TOPIC_ARN not set, skipping SNS publish.")
        except Exception as e:
            logger.error(f"Failed to publish to SNS topic: {e}")

    else:
        logger.warning(f"Unsupported triggerSource: {event['triggerSource']}")

    return event
