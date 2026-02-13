import json
import os
import time
from typing import Optional, Dict, Any

import boto3
import httpx
import jwt
from aws_lambda_powertools import Logger
from aws_lambda_powertools.metrics import Metrics, MetricUnit
from cryptography.hazmat.primitives import serialization

from constants.metrics import (
    API_METRICS_NAMESPACE,
    APNS_SEND_NOTIFICATION,
    APNS_SUCCESS,
    APNS_EXCEPTION,
    ENVIRONMENT_DIMENSION,
)
from constants.services import APNS_SERVICE
from models.apns_response import APNsResponse


class APNsClient:
    """Client for sending push notifications via Apple Push Notification Service"""

    def __init__(
        self,
        environment: str,
        stage: str = None,
        request_id: str = None,
        service: str = None,
    ):
        """
        Initialize APNs client

        Args:
            environment: "sandbox" or "production" - determines which APNs server to use
            stage: Optional stage name (e.g., "Testing", "Production").
                   If not provided, uses STAGE environment variable or defaults to "Testing"
            request_id: Optional request ID for logging correlation
            service: Optional service name for metrics/logging.
                     If not provided, uses APNS_SERVICE constant
        """
        self.service = service or APNS_SERVICE
        self.logger = Logger(service=self.service)
        if request_id:
            self.logger.append_keys(request_id=request_id)

        self.environment = environment
        self.stage = stage or os.getenv("STAGE", "Testing")
        self.apns_host = self._get_apns_host()
        self.credentials = self._load_credentials()

        self.metrics = Metrics(
            namespace=API_METRICS_NAMESPACE,
            service=self.service,
        )

        self.logger.info(
            f"APNsClient initialized for {environment} environment",
            extra={
                "environment": environment,
                "stage": self.stage,
                "apns_host": self.apns_host,
            },
        )

    def _get_apns_host(self) -> str:
        """Get APNs server URL based on environment"""
        if self.environment == "production":
            return "https://api.push.apple.com"
        return "https://api.sandbox.push.apple.com"

    def _load_credentials(self) -> Dict[str, Any]:
        """
        Load APNs credentials from AWS Secrets Manager and environment variables

        The secret "AppleKeys" contains key/value pairs where:
        - Keys: notifications-prod, notifications-testing
        - Values: Private key strings (PEM format)

        Credentials come from environment variables:
        - APNS_KEY_ID
        - APNS_TEAM_ID
        - APNS_BUNDLE_ID
        - APNS_CREDENTIALS_KEY (secret key name, e.g., "notifications-testing")

        Returns:
            Dictionary containing APNs credentials (key_id, team_id, private_key, bundle_id)
        """
        secrets_client = boto3.client("secretsmanager")
        secret_name = "AppleKeys"

        try:
            # Get required fields from environment variables
            key_id = os.getenv("APNS_KEY_ID")
            team_id = os.getenv("APNS_TEAM_ID")
            bundle_id = os.getenv("APNS_BUNDLE_ID", "com.cnuggies.famhelpdesk")
            credentials_key = os.getenv("APNS_CREDENTIALS_KEY")

            if not key_id or not team_id or not credentials_key:
                self.logger.error(
                    "Missing required environment variables for APNs",
                    extra={
                        "has_key_id": bool(key_id),
                        "has_team_id": bool(team_id),
                        "has_credentials_key": bool(credentials_key),
                    },
                )
                raise ValueError(
                    "APNS_KEY_ID, APNS_TEAM_ID, and APNS_CREDENTIALS_KEY environment variables are required"
                )

            # Retrieve the secret containing private keys
            response = secrets_client.get_secret_value(SecretId=secret_name)
            secret_data = json.loads(response["SecretString"])

            # Get the private key using the credentials_key from environment
            private_key = secret_data.get(credentials_key)
            if not private_key:
                self.logger.error(
                    f"Private key not found for key: {credentials_key}",
                    extra={
                        "credentials_key": credentials_key,
                        "secret_name": secret_name,
                        "available_keys": list(secret_data.keys()),
                    },
                )
                raise ValueError(f"Private key not found for key: {credentials_key}")

            if not private_key.strip():
                self.logger.error(
                    f"Private key is empty for key: {credentials_key}",
                    extra={
                        "credentials_key": credentials_key,
                        "secret_name": secret_name,
                    },
                )
                raise ValueError(
                    f"Private key is empty for key: {credentials_key}. Secret not properly configured in AWS Secrets Manager."
                )

            # Handle escaped newlines in the private key
            # If stored in Secrets Manager as a JSON string, \n might be escaped
            # Replace literal \n with actual newlines for PEM parsing

            self.logger.info(
                "Private key format check",
                extra={
                    "has_escaped_newlines": "\\n" in private_key,
                    "has_begin_marker": "-----BEGIN" in private_key,
                    "has_actual_newlines": "\n" in private_key,
                    "first_50_chars": (
                        repr(private_key[:50])
                        if len(private_key) > 50
                        else repr(private_key)
                    ),
                    "last_50_chars": (
                        repr(private_key[-50:]) if len(private_key) > 50 else ""
                    ),
                },
            )

            # Handle different newline formats
            if "\\n" in private_key:
                # Escaped newlines - convert to actual newlines
                private_key = private_key.replace("\\n", "\n")
                self.logger.info(
                    "Converted escaped newlines to actual newlines in private key"
                )
            elif "\n" not in private_key and "-----BEGIN" in private_key:
                # No newlines at all - key is one continuous string
                # This shouldn't happen with proper PEM format, but handle it
                self.logger.warning(
                    "Private key has no newlines - attempting to add them"
                )
                # Try to reconstruct proper PEM format
                # Split on BEGIN/END markers and add newlines to base64 content
                if (
                    "-----BEGIN PRIVATE KEY-----" in private_key
                    and "-----END PRIVATE KEY-----" in private_key
                ):
                    parts = private_key.split("-----BEGIN PRIVATE KEY-----")
                    if len(parts) == 2:
                        rest = parts[1].split("-----END PRIVATE KEY-----")
                        if len(rest) == 2:
                            base64_content = rest[0].strip()
                            # Add newlines every 64 characters
                            formatted_lines = [
                                base64_content[i : i + 64]
                                for i in range(0, len(base64_content), 64)
                            ]
                            private_key = (
                                "-----BEGIN PRIVATE KEY-----\n"
                                + "\n".join(formatted_lines)
                                + "\n-----END PRIVATE KEY-----"
                            )
                            self.logger.info(
                                "Reconstructed PEM format with proper newlines"
                            )

            # Build credentials dictionary
            credentials = {
                "key_id": key_id,
                "team_id": team_id,
                "private_key": private_key,
                "bundle_id": bundle_id,
            }

            self.logger.info(
                f"Successfully loaded APNs credentials for {self.environment}",
                extra={
                    "environment": self.environment,
                    "credentials_key": credentials_key,
                    "key_id": key_id,
                    "team_id": team_id,
                    "bundle_id": bundle_id,
                    "private_key_length": len(private_key),
                },
            )

            return credentials

        except Exception as e:
            self.logger.error(
                f"Failed to load APNs credentials: {str(e)}",
                extra={"secret_name": secret_name, "error": str(e)},
            )
            raise

    def _generate_jwt_token(self) -> str:
        """
        Generate fresh JWT token for APNs authentication

        Returns:
            JWT token string
        """
        # Extract credentials
        key_id = self.credentials["key_id"]
        team_id = self.credentials["team_id"]
        private_key_pem = self.credentials["private_key"]

        # Load the private key
        private_key = serialization.load_pem_private_key(
            private_key_pem.encode("utf-8"), password=None
        )

        # Create JWT header
        headers = {"alg": "ES256", "kid": key_id}

        # Create JWT payload
        payload = {"iss": team_id, "iat": int(time.time())}

        # Generate and sign the token
        token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)

        return token

    def send_notification(
        self,
        device_token: str,
        title: str,
        body: str,
        badge: Optional[int] = None,
        data: Optional[Dict[str, Any]] = None,
    ) -> APNsResponse:
        """
        Send push notification to device

        Args:
            device_token: APNs device token
            title: Notification title
            body: Notification body
            badge: Badge count (optional)
            data: Custom data payload (optional)

        Returns:
            APNsResponse with status and error details
        """
        # Add metrics dimensions and count
        self.metrics.add_dimension(name=ENVIRONMENT_DIMENSION, value=self.environment)
        self.metrics.add_metric(
            name=APNS_SEND_NOTIFICATION, unit=MetricUnit.Count, value=1
        )

        # Generate fresh JWT token for this request
        jwt_token = self._generate_jwt_token()

        # Construct APNs payload
        self.logger.info(
            f"Constructing APS payload",
            extra={
                "title_type": type(title).__name__,
                "body_type": type(body).__name__,
                "badge_type": type(badge).__name__ if badge else "None",
            },
        )
        aps_payload = {"alert": {"title": title, "body": body}, "sound": "default"}

        if badge is not None:
            aps_payload["badge"] = badge

        payload = {"aps": aps_payload}

        self.logger.info(
            f"Payload created successfully",
            extra={
                "payload_type": type(payload).__name__,
                "payload_keys": list(payload.keys()),
            },
        )

        # Add custom data if provided
        if data:
            self.logger.info(
                f"Adding custom data to payload",
                extra={
                    "data_type": type(data).__name__,
                    "data_is_dict": isinstance(data, dict),
                    "data_is_string": isinstance(data, str),
                    "data_keys": list(data.keys()) if isinstance(data, dict) else "N/A",
                    "data_repr": repr(data)[:100],
                },
            )
            payload.update(data)

        # Prepare request headers
        self.logger.info(
            f"Preparing headers",
            extra={
                "credentials_type": type(self.credentials).__name__,
                "jwt_token_type": type(jwt_token).__name__,
            },
        )
        headers = {
            "authorization": f"bearer {jwt_token}",
            "apns-topic": self.credentials.get("bundle_id", "com.famhelpdesk.app"),
            "apns-push-type": "alert",
        }

        # Send HTTP/2 POST request to APNs
        url = f"{self.apns_host}/3/device/{device_token}"

        self.logger.info(
            f"About to send HTTP request to APNs",
            extra={
                "url": url,
                "payload_type": type(payload).__name__,
                "headers_type": type(headers).__name__,
            },
        )

        try:
            with httpx.Client(http2=True) as client:
                response = client.post(url, json=payload, headers=headers, timeout=10.0)

            # Parse response
            if response.status_code == 200:
                self.logger.info(
                    "Push notification sent successfully",
                    extra={
                        "device_token_prefix": device_token[:8],
                        "status_code": response.status_code,
                        "apns_id": response.headers.get("apns-id"),
                    },
                )
                self.metrics.add_metric(
                    name=APNS_SUCCESS, unit=MetricUnit.Count, value=1
                )
                self.metrics.flush_metrics()
                return APNsResponse(
                    success=True,
                    status_code=response.status_code,
                    apns_id=response.headers.get("apns-id"),
                )
            else:
                # Parse error response
                error_data = response.json() if response.content else {}
                self.logger.warning(
                    f"Push notification failed with status {response.status_code}",
                    extra={
                        "device_token_prefix": device_token[:8],
                        "status_code": response.status_code,
                        "error_reason": error_data.get("reason"),
                        "apns_id": response.headers.get("apns-id"),
                    },
                )
                self.metrics.add_metric(
                    name=APNS_EXCEPTION, unit=MetricUnit.Count, value=1
                )
                self.metrics.flush_metrics()
                return APNsResponse(
                    success=False,
                    status_code=response.status_code,
                    apns_id=response.headers.get("apns-id"),
                    error_reason=error_data.get("reason"),
                    error_description=str(error_data),
                )

        except Exception as e:
            # Handle connection errors
            self.logger.error(
                f"Failed to send push notification: {str(e)}",
                extra={"device_token_prefix": device_token[:8], "error": str(e)},
            )
            self.metrics.add_metric(name=APNS_EXCEPTION, unit=MetricUnit.Count, value=1)
            self.metrics.flush_metrics()
            return APNsResponse(
                success=False,
                status_code=0,
                error_reason="ConnectionError",
                error_description=str(e),
            )
