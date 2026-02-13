import argparse
import json
import os
import random
import re
import sys
import uuid
from typing import Any, Dict, List

import boto3
from aws_lambda_powertools import Logger
from openai import OpenAI

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

from exceptions.membership_exceptions import MembershipAlreadyExistsAsMember
from helpers.family_helper import FamilyHelper
from helpers.family_membership_helper import FamilyMembershipHelper
from helpers.group_helper import GroupHelper
from helpers.group_membership_helper import GroupMembershipHelper
from helpers.queue_helper import QueueHelper
from helpers.ticket_comment_helper import TicketCommentHelper
from helpers.ticket_helper import TicketHelper
from helpers.user_profile_helper import UserProfileHelper

DEFAULT_REGION = "us-west-2"
SEVERITIES = [1.0, 2.0, 2.5, 3.0, 4.0, 5.0]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Populate fake accounts, groups, queues, and tickets for integration testing."
    )
    parser.add_argument(
        "--stage",
        required=True,
        choices=["Testing", "Prod"],
        help="Deployment stage to target.",
    )
    parser.add_argument(
        "--accounts_count",
        type=int,
        required=True,
        help="Number of fake accounts to create.",
    )
    parser.add_argument(
        "--ticket_count",
        type=int,
        required=True,
        help="Number of tickets to create.",
    )
    return parser.parse_args()


def get_user_pool_id(stage: str, region: str = DEFAULT_REGION) -> str:
    name = f"FamHelpDesk-UserPool-{stage}"
    pools = boto3.client("cognito-idp", region_name=region).list_user_pools(
        MaxResults=60
    )["UserPools"]
    return next(p["Id"] for p in pools if p["Name"] == name)


def get_cloudformation_resource(resource: str, region: str = DEFAULT_REGION) -> str:
    client = boto3.client("cloudformation", region_name=region)
    response = client.list_exports()

    for export in response.get("Exports", []):
        if export["Name"] == resource:
            return export["Value"]

    raise ValueError(f"Export '{resource}' not found in CloudFormation")


def get_open_ai_api_key() -> str:
    secrets_client = boto3.client("secretsmanager", region_name=DEFAULT_REGION)
    response = secrets_client.get_secret_value(SecretId="OpenAI")
    secret_data = json.loads(response["SecretString"])
    return secret_data["api_key"]


def create_super_hero_accounts(
    count: int, model: str = "gpt-4-turbo", api_key: str = ""
) -> List[Dict[str, str]]:
    if count <= 0:
        return []

    client = OpenAI(api_key=api_key)

    prompt = (
        f"Generate exactly {count} fake superhero user accounts.\n\n"
        "Requirements:\n"
        "- Use Marvel or Marvel-inspired superhero names\n"
        "- Each object must include:\n"
        "  - display_name (full hero name)\n"
        "  - provider (either 'Google' or 'Cognito' or 'AppleUser')\n"
        "  - email (must match the hero name, lowercase, simple domain like example.com or fantastic4.com)\n"
        "- Mix providers across users\n"
        "- Emails should be unique\n"
        "- Do NOT include real people\n\n"
        "Return ONLY valid JSON in the following format:\n"
        "[\n"
        "  {\n"
        '    "display_name": "Reed Richards",\n'
        '    "provider": "Google",\n'
        '    "email": "reed@fantastic4.com"\n'
        "  }\n"
        "]\n"
        "Do not include markdown, explanations, or extra text."
    )

    response = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "system",
                "content": (
                    "You generate realistic fake user account data "
                    "for a Marvel-style internal system."
                ),
            },
            {"role": "user", "content": prompt},
        ],
        temperature=0.7,
    )

    content = response.choices[0].message.content

    try:
        json_str = re.search(r"\[.*\]", content, re.DOTALL).group(0)
        return json.loads(json_str)
    except Exception:
        return []


def generate_marvel_ticket_gpt(
    model: str = "gpt-4-turbo", api_key: str = ""
) -> Dict[str, Any]:
    client = OpenAI(api_key=api_key)

    prompt = (
        "Create a fake Marvel-universe support ticket.\n\n"
        "Requirements:\n"
        "- Theme it like Avengers, Fantastic Four, or cosmic Marvel operations\n"
        "- The issue should sound operational or incident-based\n"
        "- Tone should be semi-serious, like an internal ticketing system\n"
        "- Comments represent internal updates or replies\n"
        "- Do not add the super hero's name who made the comment\n"
        "- Number of comments must be between 0 and 5\n\n"
        "Return ONLY valid JSON in the following format:\n"
        "{\n"
        '  "title": "string",\n'
        '  "description": "string",\n'
        '  "comments": ["string", "string"]\n'
        "}\n"
        "Do not include markdown, explanations, or extra text."
    )

    response = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "system",
                "content": (
                    "You generate realistic internal ticket data "
                    "for a Marvel-style operations system."
                ),
            },
            {"role": "user", "content": prompt},
        ],
        temperature=0.8,
    )

    content = response.choices[0].message.content

    try:
        json_str = re.search(r"\{.*\}", content, re.DOTALL).group(0)
        return json.loads(json_str)
    except Exception:
        return {}


def create_cognito_user(user_pool_id: str, user: Dict[str, str]) -> str:
    client = boto3.client("cognito-idp", region_name=DEFAULT_REGION)
    email = user.get("email")
    if not email:
        raise ValueError("User is missing email")
    username = email
    attributes = [
        {"Name": "email", "Value": email},
        {"Name": "email_verified", "Value": "true"},
    ]
    display_name = user.get("display_name")
    if display_name:
        attributes.append({"Name": "name", "Value": display_name})
    try:
        client.admin_create_user(
            UserPoolId=user_pool_id,
            Username=username,
            UserAttributes=attributes,
            MessageAction="SUPPRESS",
        )
        temp_password = "TestUser123"
        client.admin_set_user_password(
            UserPoolId=user_pool_id,
            Username=username,
            Password=temp_password,
            Permanent=True,
        )
    except client.exceptions.UsernameExistsException:
        pass
    return username


def build_helpers(
    stage: str, table_name: str, notification_queue_url: str
) -> Dict[str, Any]:
    return {
        "user_helper": UserProfileHelper(
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        ),
        "family_helper": FamilyHelper(
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        ),
        "family_membership_helper": FamilyMembershipHelper(
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        ),
        "group_membership_helper": GroupMembershipHelper(
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        ),
        "group_helper": GroupHelper(
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        ),
        "queue_helper": QueueHelper(
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        ),
        "ticket_helper": TicketHelper(
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        ),
        "ticket_comment_helper": TicketCommentHelper(
            stage=stage,
            table_name=table_name,
            notification_queue_url=notification_queue_url,
        ),
    }


def create_users(
    helpers: Dict[str, Any],
    user_pool_id: str,
    accounts_count: int,
    api_key: str,
) -> Dict[str, Any]:
    accounts = create_super_hero_accounts(accounts_count, api_key=api_key)
    if len(accounts) < accounts_count:
        raise ValueError(
            "Failed to generate enough accounts from OpenAI. "
            f"Expected {accounts_count}, got {len(accounts)}."
        )
    accounts = accounts[:accounts_count]

    users_map: List[Dict[str, str]] = []
    for user in accounts:
        users_map.append({"user_id": str(uuid.uuid4()), **user})

    created_user_ids: List[str] = []
    created_user_emails: List[str] = []

    for user in users_map:
        create_cognito_user(user_pool_id, user)
        helpers["user_helper"].create_profile(
            user_id=user["user_id"],
            display_name=user["display_name"],
            provider=user["provider"],
            email=user["email"],
        )
        created_user_ids.append(user["user_id"])
        created_user_emails.append(user["email"])

    return {
        "users_map": users_map,
        "created_user_ids": created_user_ids,
        "created_user_emails": created_user_emails,
    }


def create_family_and_memberships(
    helpers: Dict[str, Any],
    users_map: List[Dict[str, str]],
) -> Dict[str, Any]:
    family_name = f"Fantastic4-{uuid.uuid4().hex[:6]}"
    family_description = "The Fantastic 4 integration test family"
    family = helpers["family_helper"].create_family(
        family_name=family_name,
        created_by=users_map[0]["user_id"],
        family_description=family_description,
        private=False,
    )
    family_id = family.family_id

    for user in users_map[1:]:
        helpers["family_membership_helper"].create_membership_request(
            family_id=family_id, user_id=user["user_id"]
        )

    admins = helpers["family_membership_helper"].get_all_admins(family_id=family_id)
    family_membership_requests = helpers[
        "family_membership_helper"
    ].get_pending_membership_requests(family_id=family_id)

    for request in family_membership_requests:
        helpers["family_membership_helper"].review_membership_request(
            family_id=family_id,
            admin_user_id=admins[0],
            target_user_id=request["user_id"],
            approve=True,
        )

    members = helpers["family_membership_helper"].get_all_members(family_id=family_id)

    return {
        "family_id": family_id,
        "members": members,
    }


def create_groups_and_queues(
    helpers: Dict[str, Any],
    family_id: str,
    members: List[Dict[str, str]],
) -> Dict[str, Any]:
    groups_queues_map = [
        {
            "group": "Avengers",
            "queues": [
                "Global Threat Assessment",
                "Avengers Tower Operations",
                "Rapid Response Team",
                "Interagency Coordination",
            ],
        },
        {
            "group": "Illuminati",
            "queues": [
                "Confidential Briefings",
                "Multiversal Risk Review",
                "Artifact Containment",
                "Strategic Decisions",
            ],
        },
        {
            "group": "Future Foundation",
            "queues": [
                "Research & Development",
                "Youth Outreach Programs",
                "Experimental Technology",
                "Educational Initiatives",
            ],
        },
        {
            "group": "Defenders",
            "queues": [
                "Mystic Incidents",
                "Urban Crisis Support",
                "Unaligned Threats",
                "Emergency Consultations",
            ],
        },
        {
            "group": "Fantastic Force",
            "queues": [
                "Field Operations",
                "Special Assignments",
                "Containment Support",
                "Reconnaissance",
            ],
        },
        {
            "group": "Guardians of the Galaxy",
            "queues": [
                "Deep Space Missions",
                "Interstellar Diplomacy",
                "Ship Maintenance",
                "Cosmic Threat Reports",
            ],
        },
        {
            "group": "Alpha Flight",
            "queues": [
                "Northern Region Operations",
                "National Defense Requests",
                "Weather Anomalies",
                "Border Incident Response",
            ],
        },
        {
            "group": "S.W.O.R.D.",
            "queues": [
                "Orbital Surveillance",
                "Extraterrestrial Contact",
                "Space Station Operations",
                "Cosmic Intelligence Analysis",
            ],
        },
    ]

    group_created_map: List[Dict[str, Any]] = []
    created_group_ids: List[str] = []
    created_queue_ids: List[str] = []

    for highlighted_group in groups_queues_map:
        group_creator = random.choice(members)
        group = helpers["group_helper"].create_group(
            family_id=family_id,
            group_name=highlighted_group["group"],
            created_by=group_creator["user_id"],
        )

        num_to_pick = random.randint(1, min(3, len(members)))
        members_in_group = random.sample(members, num_to_pick)

        for user in members_in_group:
            try:
                helpers["group_membership_helper"].create_membership_request(
                    family_id=family_id,
                    group_id=group.group_id,
                    user_id=user["user_id"],
                )
            except MembershipAlreadyExistsAsMember:
                pass

        group_membership_requests = helpers[
            "group_membership_helper"
        ].get_pending_membership_requests(family_id=family_id, group_id=group.group_id)
        for request in group_membership_requests:
            helpers["group_membership_helper"].review_membership_request(
                family_id=family_id,
                group_id=group.group_id,
                admin_user_id=group_creator["user_id"],
                target_user_id=request["user_id"],
                approve=True,
            )

        created_queues = []
        for queue in highlighted_group["queues"]:
            created_queue = helpers["queue_helper"].create_queue(
                family_id=family_id,
                group_id=group.group_id,
                queue_name=queue,
                created_by=group_creator["user_id"],
            )
            created_queues.append(created_queue.queue_id)
            created_queue_ids.append(created_queue.queue_id)

        created_group_ids.append(group.group_id)
        group_created_map.append({"id": group.group_id, "queues": created_queues})

    return {
        "group_created_map": group_created_map,
        "created_group_ids": created_group_ids,
        "created_queue_ids": created_queue_ids,
    }


def create_tickets(
    helpers: Dict[str, Any],
    family_id: str,
    members: List[Dict[str, str]],
    group_created_map: List[Dict[str, Any]],
    ticket_count: int,
    api_key: str,
    aws_logger: Logger,
) -> Dict[str, Any]:
    created_ticket_ids: List[str] = []
    created_comment_ids: List[str] = []

    if ticket_count > 0:
        aws_logger.info(
            "Creating tickets",
            extra={"ticket_count": ticket_count, "family_id": family_id},
        )

    for index in range(ticket_count):
        group_queue = random.choice(group_created_map)
        group_id = group_queue["id"]
        queue_id = random.choice(group_queue["queues"])
        assigned_to = random.choice(members + [None])

        generated_info = generate_marvel_ticket_gpt(api_key=api_key)
        title = generated_info.get("title") or f"Incident {index + 1}"
        description = (
            generated_info.get("description") or "Automated integration test ticket."
        )
        comments = generated_info.get("comments") or []

        ticket = helpers["ticket_helper"].create_ticket(
            family_id=family_id,
            group_id=group_id,
            queue_id=queue_id,
            title=title,
            severity=random.choice(SEVERITIES),
            created_by=random.choice(members)["user_id"],
            description=description,
            assigned_to=assigned_to["user_id"] if assigned_to else None,
        )
        created_ticket_ids.append(ticket.ticket_id)

        for comment in comments:
            comment_data = helpers["ticket_comment_helper"].create_comment(
                ticket_id=ticket.ticket_id,
                comment_user=random.choice(members)["user_id"],
                comment_body=comment,
            )
            comment_id = comment_data.get("comment_id")
            if comment_id:
                created_comment_ids.append(comment_id)

        if (index + 1) % 10 == 0 or index == ticket_count - 1:
            aws_logger.info(
                "Ticket progress",
                extra={"created": index + 1, "total": ticket_count},
            )

    return {
        "created_ticket_ids": created_ticket_ids,
        "created_comment_ids": created_comment_ids,
    }


def run_populate(payload: Dict[str, Any]) -> Dict[str, Any]:
    stage = payload.get("stage")
    accounts_count = payload.get("accounts_count")
    ticket_count = payload.get("ticket_count")

    if not stage:
        raise ValueError("Missing required field: stage")
    if accounts_count is None:
        raise ValueError("Missing required field: accounts_count")
    if ticket_count is None:
        raise ValueError("Missing required field: ticket_count")
    if accounts_count < 1:
        raise ValueError("accounts_count must be at least 1")
    if ticket_count < 0:
        raise ValueError("ticket_count must be 0 or greater")

    os.environ["REGION"] = DEFAULT_REGION

    aws_logger = Logger(service="populate-fake-tickets", level="INFO")

    table_name = f"FamHelpDesk-{stage}"
    notification_queue_url = get_cloudformation_resource(
        f"FamHelpDesk-NotificationQueueUrl-{stage}"
    )

    helpers = build_helpers(stage, table_name, notification_queue_url)

    user_pool_id = get_user_pool_id(stage)
    api_key = get_open_ai_api_key()

    aws_logger.info(
        "Starting fake data population",
        extra={
            "stage": stage,
            "accounts_count": accounts_count,
            "ticket_count": ticket_count,
        },
    )

    users_result = create_users(
        helpers=helpers,
        user_pool_id=user_pool_id,
        accounts_count=accounts_count,
        api_key=api_key,
    )

    family_result = create_family_and_memberships(
        helpers=helpers,
        users_map=users_result["users_map"],
    )

    group_result = create_groups_and_queues(
        helpers=helpers,
        family_id=family_result["family_id"],
        members=family_result["members"],
    )

    ticket_result = create_tickets(
        helpers=helpers,
        family_id=family_result["family_id"],
        members=family_result["members"],
        group_created_map=group_result["group_created_map"],
        ticket_count=ticket_count,
        api_key=api_key,
        aws_logger=aws_logger,
    )

    all_groups = helpers["group_helper"].get_all_groups(
        family_id=family_result["family_id"]
    )
    all_queues = helpers["queue_helper"].get_all_queues_by_family(
        family_id=family_result["family_id"]
    )

    resources = {
        "stage": stage,
        "region": DEFAULT_REGION,
        "user_pool_id": user_pool_id,
        "family_id": family_result["family_id"],
        "user_ids": users_result["created_user_ids"],
        "user_emails": users_result["created_user_emails"],
        "group_ids": [group.group_id for group in all_groups],
        "queue_ids": [queue.queue_id for queue in all_queues],
        "ticket_ids": ticket_result["created_ticket_ids"],
        "comment_ids": ticket_result["created_comment_ids"],
        "group_queue_map": group_result["group_created_map"],
        "accounts_count": accounts_count,
        "ticket_count": ticket_count,
    }

    return resources


def main() -> None:
    args = parse_args()
    resources = run_populate(
        {
            "stage": args.stage,
            "accounts_count": args.accounts_count,
            "ticket_count": args.ticket_count,
        }
    )

    print(json.dumps(resources, indent=2))


if __name__ == "__main__":
    main()
