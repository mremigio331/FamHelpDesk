"""
Family Deletion Lambda

Deletes one or more families and all their associated data from the system.

Example invocation payloads:

Single family:
{
    "stage": "dev",
    "family_id": "family-123"
}

Multiple families:
{
    "stage": "dev",
    "family_ids": ["family-123", "family-456", "family-789"]
}
"""

from typing import Any, Dict

from test.delete_family import run_cleanup


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    return run_cleanup(event)
