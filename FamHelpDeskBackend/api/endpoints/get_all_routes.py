from api.endpoints.fam_help_deks import home
from api.endpoints.user import get_requester, get_user_profile
from api.endpoints.family import create_family, get_all_families, get_my_families
from constants.api import (
    HOME_TAG,
    HOME_PATH,
    USER_PATH,
    USER_TAG,
    FAMILY_TAG,
    FAMILY_PATH,
)
from fastapi import FastAPI


def get_all_routes(app: FastAPI) -> FastAPI:
    """
    Registers all API routes with the FastAPI application.

    Args:
        app (FastAPI): The FastAPI application instance.

    Returns:
        FastAPI: The updated FastAPI application instance with all routes registered.
    """
    app.include_router(home.router, prefix=HOME_PATH, tags=[HOME_TAG])

    app.include_router(get_requester.router, prefix=USER_PATH, tags=[USER_TAG])
    app.include_router(get_user_profile.router, prefix=USER_PATH, tags=[USER_TAG])

    app.include_router(create_family.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])
    app.include_router(get_all_families.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])
    app.include_router(get_my_families.router, prefix=FAMILY_PATH, tags=[FAMILY_TAG])

    return app
