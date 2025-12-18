from api.endpoints.fam_help_deks import home
from constants.api import HOME
from fastapi import FastAPI


def get_all_routes(app: FastAPI) -> FastAPI:
    """
    Registers all API routes with the FastAPI application.

    Args:
        app (FastAPI): The FastAPI application instance.

    Returns:
        FastAPI: The updated FastAPI application instance with all routes registered.
    """
    app.include_router(home.router, prefix="/home", tags=[HOME])

    return app
