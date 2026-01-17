"""Ticket and ticket comment-specific exceptions for the FamHelpDesk API."""


class TicketException(Exception):
    """Base exception for ticket-related errors."""

    def __init__(self, message: str = "Ticket operation failed"):
        self.message = message
        super().__init__(self.message)


class TicketNotFoundException(TicketException):
    """Exception raised when a ticket is not found."""

    def __init__(self, message: str = "Ticket not found"):
        super().__init__(message)


class InvalidTicketStatusTransitionException(TicketException):
    """Exception raised when an invalid ticket status transition is attempted."""

    def __init__(self, message: str = "Invalid ticket status transition"):
        super().__init__(message)


class TicketReopenWindowExpiredException(TicketException):
    """Exception raised when attempting to reopen a ticket outside the 30-day window."""

    def __init__(self, message: str = "Ticket reopen window has expired"):
        super().__init__(message)


class InvalidTicketStatusException(TicketException):
    """Exception raised when an invalid ticket status value is provided."""

    def __init__(self, message: str = "Invalid ticket status"):
        super().__init__(message)


class InvalidTicketSeverityException(TicketException):
    """Exception raised when an invalid ticket severity value is provided."""

    def __init__(self, message: str = "Invalid ticket severity"):
        super().__init__(message)


class CommentException(Exception):
    """Base exception for comment-related errors."""

    def __init__(self, message: str = "Comment operation failed"):
        self.message = message
        super().__init__(self.message)


class CommentNotFoundException(CommentException):
    """Exception raised when a comment is not found."""

    def __init__(self, message: str = "Comment not found"):
        super().__init__(message)


class CommentEditWindowExpiredException(CommentException):
    """Exception raised when attempting to modify a comment after the 4-hour window."""

    def __init__(self, message: str = "Comment edit window has expired"):
        super().__init__(message)


class UnauthorizedCommentModificationException(CommentException):
    """Exception raised when a user attempts to modify another user's comment."""

    def __init__(self, message: str = "Unauthorized comment modification"):
        super().__init__(message)
