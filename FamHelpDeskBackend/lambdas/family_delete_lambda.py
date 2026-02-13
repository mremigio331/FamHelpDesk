from typing import Any, Dict

from test.delete_family import run_cleanup


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    resources = event.get("resources", event)
    return run_cleanup(resources)
