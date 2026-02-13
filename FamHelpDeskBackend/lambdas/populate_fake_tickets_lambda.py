from typing import Any, Dict

from test.populate_fake_tickets import run_populate


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    return run_populate(event)
