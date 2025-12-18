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

from fastapi.responses import JSONResponse
from botocore.exceptions import ClientError


def exceptions_decorator(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)

        # 4XX
        except UserNotFound as exc:
            return JSONResponse(
                content={"message": str(exc) or "User not found."}, status_code=404
            )
        except InvalidUserIdException as exc:
            return JSONResponse(
                content={"message": str(exc) or "Invalid user ID."}, status_code=400
            )
        except UserNameTooLong as exc:
            return JSONResponse(
                content={"message": str(exc) or "User name is too long."},
                status_code=400,
            )
        # Membership
        except MembershipNotFound as exc:
            return JSONResponse(
                content={"message": str(exc) or "Membership not found."},
                status_code=404,
            )
        except MembershipAlreadyExistsAsMember as exc:
            return JSONResponse(
                content={"message": str(exc) or "User already a member."},
                status_code=409,
            )
        except MembershipRequestPendingExists as exc:
            return JSONResponse(
                content={"message": str(exc) or "Pending request already exists."},
                status_code=409,
            )
        except MembershipPendingRequired as exc:
            return JSONResponse(
                content={"message": str(exc) or "Pending membership required."},
                status_code=400,
            )
        except MembershipActiveRequired as exc:
            return JSONResponse(
                content={"message": str(exc) or "Active membership required."},
                status_code=400,
            )
        except AdminPrivilegesRequired as exc:
            return JSONResponse(
                content={"message": str(exc) or "Admin privileges required."},
                status_code=403,
            )
        except MemberPrivilegesRequired as exc:
            return JSONResponse(
                content={"message": str(exc) or "Member privileges required."},
                status_code=403,
            )

        except (InvalidJWTException, JWTSignatureException) as exc:
            return JSONResponse(
                content={"message": str(exc) or "Invalid JWT."}, status_code=401
            )
        except ExpiredJWTException as exc:
            return JSONResponse(
                content={"message": str(exc) or "JWT expired."}, status_code=401
            )
        except MissingJWTException as exc:
            return JSONResponse(
                content={"message": str(exc) or "JWT missing."}, status_code=401
            )
        except ProfileNotPublicOrDoesNotExist as exc:
            return JSONResponse(
                status_code=403,
                content={
                    "message": str(exc) or "Access denied: insufficient permissions."
                },
            )

        ### 5XX
        except ClientError as exc:
            return JSONResponse(
                content={"message": str(exc) or "Internal server error."},
                status_code=500,
            )

    return wrapper
