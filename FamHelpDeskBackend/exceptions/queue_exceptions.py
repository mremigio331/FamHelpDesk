"""Queue-specific exceptions for the FamHelpDesk API."""


class QueueException(Exception):
    """Base exception for queue-related errors."""

    def __init__(self, message: str = "Queue operation failed"):
        self.message = message
        super().__init__(self.message)


class QueueNotFound(QueueException):
    """Exception raised when a queue is not found."""

    def __init__(self, message: str = "Queue not found"):
        super().__init__(message)


class QueueAlreadyExists(QueueException):
    """Exception raised when attempting to create a queue that already exists."""

    def __init__(self, message: str = "Queue already exists"):
        super().__init__(message)


class InvalidQueueData(QueueException):
    """Exception raised when queue data is invalid."""

    def __init__(self, message: str = "Invalid queue data provided"):
        super().__init__(message)


class QueueNameTooLong(QueueException):
    """Exception raised when queue name exceeds maximum length."""

    def __init__(self, max_length: int = 100):
        super().__init__(f"Queue name cannot exceed {max_length} characters")


class QueueDescriptionTooLong(QueueException):
    """Exception raised when queue description exceeds maximum length."""

    def __init__(self, max_length: int = 500):
        super().__init__(f"Queue description cannot exceed {max_length} characters")


class QueueGroupMismatch(QueueException):
    """Exception raised when queue doesn't belong to the specified group."""

    def __init__(self, message: str = "Queue does not belong to the specified group"):
        super().__init__(message)


class QueuePermissionDenied(QueueException):
    """Exception raised when user lacks permission to perform queue operation."""

    def __init__(self, message: str = "Permission denied for queue operation"):
        super().__init__(message)


class QueueHasActiveTickets(QueueException):
    """Exception raised when attempting to delete a queue with active tickets."""

    def __init__(self, message: str = "Cannot delete queue with active tickets"):
        super().__init__(message)
