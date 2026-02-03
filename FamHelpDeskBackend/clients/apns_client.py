import json
import os
import time
from typing import Optional, Dict, Any

import boto3
import httpx
import jwt
from aws_lambda_powertools import Logger
from cryptography.hazmat.primitives import serialization

from models.apns_response import APNsResponse


class APNsClient:
    """Client for sending push notifications via Apple Push Notification Service"""

    def __init__(self, environment: str, stage: str = None, request_id: str = None):
        """
        Initialize APNs client

        Args:
            environment: "sandbox" or "production" - determines which APNs server to use
            stage: Optional stage name (e.g., "Testing", "Production").
                   If not provided, uses STAGE environment variable or defaults to "Testing"
            request_id: Optional request ID for logging correlation
        """
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)

        self.environment = environment
        self.stage = stage or os.getenv("STAGE", "Testing")
        self.apns_host = self._get_apns_host()
        self.credentials = self._load_credentials()

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
        Load APNs credentials from AWS Secrets Manager

        Returns:
            Dictionary containing APNs credentials (key_id, team_id, private_key)
        """
        secrets_client = boto3.client("secretsmanager")

        # Retrieve the secret
        secret_name = "AppleKeys"

        try:
            response = secrets_client.get_secret_value(SecretId=secret_name)

            # Parse the secret JSON
            secret_data = json.loads(response["SecretString"])

            # Get the appropriate key based on environment
            if self.environment == "production":
                credentials_key = "notifications-prod"
            else:
                credentials_key = "notifications-testing"

            credentials = secret_data.get(credentials_key)
            if not credentials:
                self.logger.error(
                    f"Credentials not found for key: {credentials_key}",
                    extra={
                        "credentials_key": credentials_key,
                        "secret_name": secret_name,
                    },
                )
                raise ValueError(f"Credentials not found for key: {credentials_key}")

            self.logger.info(
                f"Successfully loaded APNs credentials for {self.environment}",
                extra={
                    "environment": self.environment,
                    "credentials_key": credentials_key,
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
        # Generate fresh JWT token for this request
        jwt_token = self._generate_jwt_token()

        # Construct APNs payload
        aps_payload = {"alert": {"title": title, "body": body}, "sound": "default"}

        if badge is not None:
            aps_payload["badge"] = badge

        payload = {"aps": aps_payload}

        # Add custom data if provided
        if data:
            payload.update(data)

        # Prepare request headers
        headers = {
            "authorization": f"bearer {jwt_token}",
            "apns-topic": self.credentials.get("bundle_id", "com.famhelpdesk.app"),
            "apns-push-type": "alert",
        }

        # Send HTTP/2 POST request to APNs
        url = f"{self.apns_host}/3/device/{device_token}"

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
            return APNsResponse(
                success=False,
                status_code=0,
                error_reason="ConnectionError",
                error_description=str(e),
            )
