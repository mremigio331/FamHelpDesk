from typing import Optional
from aws_lambda_powertools import Logger

from exceptions.group_exceptions import (
    InvalidGroupData,
    GroupNameTooLong,
    GroupDescriptionTooLong,
    FamilyNotFound,
    GroupFamilyMismatch,
)
from helpers.family_helper import FamilyHelper
from helpers.group_helper import GroupHelper


class GroupValidationHelper:
    """Helper class for validating group operations and data."""

    def __init__(self, request_id: str = None):
        self.logger = Logger()
        if request_id:
            self.logger.append_keys(request_id=request_id)
        self.request_id = request_id
        self.family_helper = FamilyHelper(request_id=request_id)
        self.group_helper = GroupHelper(request_id=request_id)

    def validate_group_name(self, group_name: str, max_length: int = 100) -> None:
        """Validate group name format and length."""
        if not group_name or not group_name.strip():
            raise InvalidGroupData("Group name is required and cannot be empty.")

        if len(group_name) > max_length:
            raise GroupNameTooLong(max_length)

        # Check for invalid characters
        if any(char in group_name for char in ["<", ">", "&", '"', "'"]):
            raise InvalidGroupData("Group name contains invalid characters.")

    def validate_group_description(
        self, group_description: Optional[str], max_length: int = 500
    ) -> None:
        """Validate group description length."""
        if group_description is not None and len(group_description) > max_length:
            raise GroupDescriptionTooLong(max_length)

    def validate_family_exists(self, family_id: str) -> None:
        """Validate that the family exists."""
        if not family_id or not family_id.strip():
            raise InvalidGroupData("Family ID is required.")

        family = self.family_helper.get_family(family_id)
        if not family:
            raise FamilyNotFound(f"Family with ID {family_id} not found.")

    def validate_group_family_relationship(self, family_id: str, group_id: str) -> None:
        """Validate that the group belongs to the specified family."""
        group = self.group_helper.get_group(family_id, group_id)
        if not group:
            raise GroupFamilyMismatch(
                f"Group {group_id} does not exist in family {family_id}."
            )

        if group.family_id != family_id:
            raise GroupFamilyMismatch(
                f"Group {group_id} does not belong to family {family_id}."
            )

    def validate_create_group_data(
        self, family_id: str, group_name: str, group_description: Optional[str] = None
    ) -> None:
        """Validate all data required for creating a group."""
        self.validate_family_exists(family_id)
        self.validate_group_name(group_name)
        self.validate_group_description(group_description)

    def validate_update_group_data(
        self,
        family_id: str,
        group_id: str,
        group_name: Optional[str] = None,
        group_description: Optional[str] = None,
    ) -> None:
        """Validate all data required for updating a group."""
        self.validate_group_family_relationship(family_id, group_id)

        if group_name is not None:
            self.validate_group_name(group_name)

        if group_description is not None:
            self.validate_group_description(group_description)

    def validate_group_operation(self, family_id: str, group_id: str) -> None:
        """Validate that a group operation can be performed."""
        self.validate_group_family_relationship(family_id, group_id)
