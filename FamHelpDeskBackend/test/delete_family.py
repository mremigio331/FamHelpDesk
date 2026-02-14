import argparse
import json
import os
from typing import Any, Dict

import boto3
from aws_lambda_powertools import Logger
from boto3.dynamodb.conditions import Key

from models.base import FamHelpDeskBaseModel

DEFAULT_REGION = "us-west-2"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Cleanup resources created by populate_fake_tickets.py."
    )
    parser.add_argument(
        "--input",
        required=True,
        help="Path to the JSON output from populate_fake_tickets.py.",
    )
    return parser.parse_args()


def load_resources(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def get_cloudformation_resource(resource: str, region: str = DEFAULT_REGION) -> str:
    client = boto3.client("cloudformation", region_name=region)
    response = client.list_exports()

    for export in response.get("Exports", []):
        if export["Name"] == resource:
            return export["Value"]

    raise ValueError(f"Export '{resource}' not found in CloudFormation")


def configure_models(stage: str, table_name: str, notification_queue_url: str) -> None:
    FamHelpDeskBaseModel.set_stage_and_table(stage, table_name, notification_queue_url)


def delete_family_partition(table_name: str, family_id: str, aws_logger: Logger) -> int:
    dynamodb = boto3.resource("dynamodb", region_name=DEFAULT_REGION)
    table = dynamodb.Table(table_name)
    pk = f"FAMILY#{family_id}"
    deleted = 0
    last_key = None

    while True:
        query_kwargs = {
            "KeyConditionExpression": Key("pk").eq(pk),
        }
        if last_key:
            query_kwargs["ExclusiveStartKey"] = last_key

        response = table.query(**query_kwargs)
        items = response.get("Items", [])

        if items:
            with table.batch_writer() as batch:
                for item in items:
                    batch.delete_item(Key={"pk": item["pk"], "sk": item["sk"]})
                    deleted += 1

        last_key = response.get("LastEvaluatedKey")
        if not last_key:
            break

    aws_logger.info(
        "Deleted family partition items",
        extra={"family_id": family_id, "deleted": deleted},
    )
    return deleted


def run_cleanup(resources: Dict[str, Any]) -> Dict[str, Any]:
    stage = resources.get("stage")
    if not stage:
        raise ValueError("Input JSON missing 'stage'")

    # Check if we have a list of families or a single family
    family_ids = resources.get("family_ids")
    family_id = resources.get("family_id")

    if family_ids:
        # Process multiple families
        if not isinstance(family_ids, list):
            raise ValueError("'family_ids' must be a list")
    elif family_id:
        # Convert single family to list for uniform processing
        family_ids = [family_id]
    else:
        raise ValueError("Input JSON missing 'family_id' or 'family_ids'")

    os.environ["REGION"] = DEFAULT_REGION

    aws_logger = Logger(service="cleanup-fake-tickets", level="INFO")

    table_name = f"FamHelpDesk-{stage}"
    notification_queue_url = get_cloudformation_resource(
        f"FamHelpDesk-NotificationQueueUrl-{stage}"
    )

    configure_models(stage, table_name, notification_queue_url)

    aws_logger.info(
        "Starting cleanup",
        extra={"stage": stage, "family_count": len(family_ids)},
    )

    # Track results for all families
    results = {
        "successful_deletions": [],
        "failed_deletions": [],
        "total_families": len(family_ids),
        "total_deleted_items": 0,
    }

    # Process each family
    for fam_id in family_ids:
        aws_logger.info(f"Starting deletion process for family_id: {fam_id}")
        try:
            deleted_items = delete_family_partition(table_name, fam_id, aws_logger)
            results["successful_deletions"].append(
                {"family_id": fam_id, "deleted_items": deleted_items}
            )
            results["total_deleted_items"] += deleted_items
            aws_logger.info(
                f"Successfully deleted family_id: {fam_id} ({deleted_items} items)"
            )
        except Exception as e:
            aws_logger.error(f"Failed to delete family_id {fam_id}: {e}", exc_info=True)
            results["failed_deletions"].append({"family_id": fam_id, "error": str(e)})

    # Log final results
    aws_logger.info(
        "Deletion process completed",
        extra={
            "successful": len(results["successful_deletions"]),
            "failed": len(results["failed_deletions"]),
            "total_items_deleted": results["total_deleted_items"],
        },
    )

    return results


def main() -> None:
    args = parse_args()
    resources = load_resources(args.input)
    summary = run_cleanup(resources)

    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
