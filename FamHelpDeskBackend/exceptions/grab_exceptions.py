"""Grab request-specific exceptions for the FamHelpDesk API."""


class GrabException(Exception):
    """Base exception for grab-related errors."""

    def __init__(self, message: str = "Grab operation failed"):
        self.message = message
        super().__init__(self.message)


class GrabRequestNotFoundException(GrabException):
    """Exception raised when a grab request is not found."""

    def __init__(self, message: str = "Grab request not found"):
        super().__init__(message)


class InvalidGrabStatusTransitionException(GrabException):
    """Exception raised when an invalid grab request status transition is attempted."""

    def __init__(self, message: str = "Invalid grab request status transition"):
        super().__init__(message)


class GrabUnauthorizedException(GrabException):
    """Exception raised when a user is not authorized to perform a grab action."""

    def __init__(self, message: str = "Unauthorized grab action"):
        super().__init__(message)


class CannotClaimOwnRequestException(GrabException):
    """Exception raised when a user attempts to claim their own grab request."""

    def __init__(self, message: str = "Cannot claim your own request"):
        super().__init__(message)


class InvalidTipAmountException(GrabException):
    """Exception raised when an invalid tip amount is provided."""

    def __init__(self, message: str = "Invalid tip amount"):
        super().__init__(message)


class NoPhotoAvailableException(GrabException):
    """Exception raised when no proof photo is available for a grab request."""

    def __init__(self, message: str = "No photo available"):
        super().__init__(message)


class InvalidStarRatingException(GrabException):
    """Exception raised when a star rating is not between 1 and 5 inclusive."""

    def __init__(self, message: str = "Star rating must be between 1 and 5"):
        super().__init__(message)


class CommentTooLongException(GrabException):
    """Exception raised when a review comment exceeds 500 characters."""

    def __init__(self, message: str = "Comment must not exceed 500 characters"):
        super().__init__(message)


class InvalidItemIdException(GrabException):
    """Exception raised when an item_id does not belong to the specified grab request."""

    def __init__(self, message: str = "Item ID not found in request"):
        super().__init__(message)


class ReviewWindowExpiredException(GrabException):
    """Exception raised when the 48-hour review window has expired."""

    def __init__(self, message: str = "Review window has expired"):
        super().__init__(message)


class InsufficientBalanceException(GrabException):
    """Exception raised when the requestor's Embolec balance is insufficient for confirmation."""

    def __init__(self, message: str = "Insufficient Embolec balance"):
        super().__init__(message)


class ItemAlreadyClaimedException(GrabException):
    """Exception raised when an item already has a claimer."""

    def __init__(self, message: str = "Item is already claimed by another user"):
        super().__init__(message)


class AllItemsConfirmedException(GrabException):
    """Exception raised when all items are already confirmed and request-level cancel is attempted."""

    def __init__(self, message: str = "All items are already confirmed"):
        super().__init__(message)
