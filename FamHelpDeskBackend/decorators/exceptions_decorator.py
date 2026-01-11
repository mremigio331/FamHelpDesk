from functools import wraps
from exceptions.user_exceptions import (
    UserNotFound,
    InvalidUserIdException,
    ProfileNotPublicOrDoesNotExist,
    UserNameTooLong,
)
from exceptions.jwt_exeptions import (
    InvalidJWTException,
    ExpiredJWTException,
    MissingJWTException,
    JWTSignatureException,
)
from exceptions.membership_exceptions import (
    MembershipNotFound,
    MembershipAlreadyExistsAsMember,
    MembershipRequestPendingExists,
    MembershipPendingRequired,
    MembershipActiveRequired,
    AdminPrivilegesRequired,
    MemberPrivilegesRequired,
)
from exceptions.group_exceptions import (
    GroupNotFound,
    GroupAlreadyExists,
    InvalidGroupData,
    GroupFamilyMismatch,
    GroupPermissionDenied,
    GroupHasActiveQueues,
    GroupNameTooLong,
    GroupDescriptionTooLong,
    FamilyNotFound,
)
from exceptions.queue_exceptions import (
    QueueNotFound,
    QueueAlreadyExists,
    InvalidQueueData,
    QueueNameTooLong,
    QueueDescriptionTooLong,
    QueueGroupMismatch,
    QueuePermissionDenied,
    QueueHasActiveTickets,
)

from fastapi.responses import JSONResponse
from botocore.exceptions import ClientError


def exceptions_decorator(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)

        # 4XX
        # User exceptions
        except UserNotFound as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "USER_NOT_FOUND",
                        "message": str(exc) or "User not found.",
                    }
                },
                status_code=404,
            )
        except InvalidUserIdException as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "INVALID_USER_ID",
                        "message": str(exc) or "Invalid user ID.",
                    }
                },
                status_code=400,
            )
        except UserNameTooLong as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "USER_NAME_TOO_LONG",
                        "message": str(exc) or "User name is too long.",
                    }
                },
                status_code=400,
            )
        except ProfileNotPublicOrDoesNotExist as exc:
            return JSONResponse(
                status_code=403,
                content={
                    "error": {
                        "code": "ACCESS_DENIED",
                        "message": str(exc)
                        or "Access denied: insufficient permissions.",
                    }
                },
            )

        # Group exceptions
        except GroupNotFound as exc:
            return JSONResponse(
                content={"error": {"code": "GROUP_NOT_FOUND", "message": str(exc)}},
                status_code=404,
            )
        except GroupAlreadyExists as exc:
            return JSONResponse(
                content={
                    "error": {"code": "GROUP_ALREADY_EXISTS", "message": str(exc)}
                },
                status_code=409,
            )
        except InvalidGroupData as exc:
            return JSONResponse(
                content={"error": {"code": "INVALID_GROUP_DATA", "message": str(exc)}},
                status_code=400,
            )
        except GroupFamilyMismatch as exc:
            return JSONResponse(
                content={
                    "error": {"code": "GROUP_FAMILY_MISMATCH", "message": str(exc)}
                },
                status_code=400,
            )
        except GroupPermissionDenied as exc:
            return JSONResponse(
                content={
                    "error": {"code": "GROUP_PERMISSION_DENIED", "message": str(exc)}
                },
                status_code=403,
            )
        except GroupHasActiveQueues as exc:
            return JSONResponse(
                content={
                    "error": {"code": "GROUP_HAS_ACTIVE_QUEUES", "message": str(exc)}
                },
                status_code=409,
            )
        except (GroupNameTooLong, GroupDescriptionTooLong) as exc:
            return JSONResponse(
                content={
                    "error": {"code": "INVALID_INPUT_LENGTH", "message": str(exc)}
                },
                status_code=400,
            )
        except FamilyNotFound as exc:
            return JSONResponse(
                content={"error": {"code": "FAMILY_NOT_FOUND", "message": str(exc)}},
                status_code=404,
            )

        # Queue exceptions
        except QueueNotFound as exc:
            return JSONResponse(
                content={"error": {"code": "QUEUE_NOT_FOUND", "message": str(exc)}},
                status_code=404,
            )
        except QueueAlreadyExists as exc:
            return JSONResponse(
                content={
                    "error": {"code": "QUEUE_ALREADY_EXISTS", "message": str(exc)}
                },
                status_code=409,
            )
        except InvalidQueueData as exc:
            return JSONResponse(
                content={"error": {"code": "INVALID_QUEUE_DATA", "message": str(exc)}},
                status_code=400,
            )
        except QueueGroupMismatch as exc:
            return JSONResponse(
                content={
                    "error": {"code": "QUEUE_GROUP_MISMATCH", "message": str(exc)}
                },
                status_code=400,
            )
        except QueuePermissionDenied as exc:
            return JSONResponse(
                content={
                    "error": {"code": "QUEUE_PERMISSION_DENIED", "message": str(exc)}
                },
                status_code=403,
            )
        except QueueHasActiveTickets as exc:
            return JSONResponse(
                content={
                    "error": {"code": "QUEUE_HAS_ACTIVE_TICKETS", "message": str(exc)}
                },
                status_code=409,
            )
        except (QueueNameTooLong, QueueDescriptionTooLong) as exc:
            return JSONResponse(
                content={
                    "error": {"code": "INVALID_INPUT_LENGTH", "message": str(exc)}
                },
                status_code=400,
            )

        # Membership exceptions
        except MembershipNotFound as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "MEMBERSHIP_NOT_FOUND",
                        "message": str(exc) or "Membership not found.",
                    }
                },
                status_code=404,
            )
        except MembershipAlreadyExistsAsMember as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "MEMBERSHIP_ALREADY_EXISTS",
                        "message": str(exc) or "User already a member.",
                    }
                },
                status_code=409,
            )
        except MembershipRequestPendingExists as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "MEMBERSHIP_REQUEST_PENDING",
                        "message": str(exc) or "Pending request already exists.",
                    }
                },
                status_code=409,
            )
        except MembershipPendingRequired as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "MEMBERSHIP_PENDING_REQUIRED",
                        "message": str(exc) or "Pending membership required.",
                    }
                },
                status_code=400,
            )
        except MembershipActiveRequired as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "MEMBERSHIP_ACTIVE_REQUIRED",
                        "message": str(exc) or "Active membership required.",
                    }
                },
                status_code=400,
            )
        except AdminPrivilegesRequired as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "ADMIN_PRIVILEGES_REQUIRED",
                        "message": str(exc) or "Admin privileges required.",
                    }
                },
                status_code=403,
            )
        except MemberPrivilegesRequired as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "MEMBER_PRIVILEGES_REQUIRED",
                        "message": str(exc) or "Member privileges required.",
                    }
                },
                status_code=403,
            )

        # JWT exceptions
        except (InvalidJWTException, JWTSignatureException) as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "INVALID_JWT",
                        "message": str(exc) or "Invalid JWT.",
                    }
                },
                status_code=401,
            )
        except ExpiredJWTException as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "EXPIRED_JWT",
                        "message": str(exc) or "JWT expired.",
                    }
                },
                status_code=401,
            )
        except MissingJWTException as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "MISSING_JWT",
                        "message": str(exc) or "JWT missing.",
                    }
                },
                status_code=401,
            )

        ### 5XX
        except ClientError as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "INTERNAL_SERVER_ERROR",
                        "message": str(exc) or "Internal server error.",
                    }
                },
                status_code=500,
            )
        except Exception as exc:
            return JSONResponse(
                content={
                    "error": {
                        "code": "UNEXPECTED_ERROR",
                        "message": "An unexpected error occurred.",
                    }
                },
                status_code=500,
            )

    return wrapper
