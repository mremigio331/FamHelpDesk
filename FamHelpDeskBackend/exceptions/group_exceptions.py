class GroupNotFound(Exception):
    """Exception raised when a group is not found in the database."""

    def __init__(self, message: str = "Group not found."):
        self.message = message
        super().__init__(self.message)


class GroupAlreadyExists(Exception):
    """Exception raised when attempting to create a group that already exists."""

    def __init__(self, message: str = "Group already exists."):
        self.message = message
        super().__init__(self.message)


class InvalidGroupData(Exception):
    """Exception raised when group data is invalid."""

    def __init__(self, message: str = "Invalid group data provided."):
        self.message = message
        super().__init__(self.message)


class GroupFamilyMismatch(Exception):
    """Exception raised when group does not belong to the specified family."""

    def __init__(self, message: str = "Group does not belong to the specified family."):
        self.message = message
        super().__init__(self.message)


class GroupPermissionDenied(Exception):
    """Exception raised when user lacks permission to perform group operation."""

    def __init__(self, message: str = "Permission denied for group operation."):
        self.message = message
        super().__init__(self.message)


class GroupHasActiveQueues(Exception):
    """Exception raised when attempting to delete a group that has active queues."""

    def __init__(self, message: str = "Cannot delete group with active queues."):
        self.message = message
        super().__init__(self.message)


class GroupNameTooLong(Exception):
    """Exception raised when group name exceeds maximum length."""

    def __init__(self, max_length: int = 100):
        self.message = f"Group name must be at most {max_length} characters."
        super().__init__(self.message)


class GroupDescriptionTooLong(Exception):
    """Exception raised when group description exceeds maximum length."""

    def __init__(self, max_length: int = 500):
        self.message = f"Group description must be at most {max_length} characters."
        super().__init__(self.message)


class FamilyNotFound(Exception):
    """Exception raised when a family is not found in the database."""

    def __init__(self, message: str = "Family not found."):
        self.message = message
        super().__init__(self.message)
