"""
APNs Response model for handling Apple Push Notification Service responses.
"""

from dataclasses import dataclass
from typing import Optional


@dataclass
class APNsResponse:
    """Response from APNs after sending a notification"""

    success: bool
    status_code: int
    apns_id: Optional[str] = None
    error_reason: Optional[str] = None
    error_description: Optional[str] = None

    def is_invalid_token(self) -> bool:
        """Check if error indicates invalid token"""
        return self.error_reason in ["BadDeviceToken", "Unregistered"]

    def is_rate_limited(self) -> bool:
        """Check if error indicates rate limiting"""
        return self.status_code == 429

    def is_temporary_error(self) -> bool:
        """Check if error is temporary and retryable"""
        return self.status_code in [500, 503]
