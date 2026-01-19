from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from aws_lambda_powertools import Logger
from constants.services import API_SERVICE
from helpers.entity_ref import EntityRef, EntityRefHelper

# Set up structured logger
logger = Logger(service=API_SERVICE)

router = APIRouter()


@router.get(
    path="/",
    summary="Home Endpoint",
    response_description="Welcome message with user info",
)
async def home(request: Request):
    """
    Home Endpoint

    Returns:
        A welcome message for the FamHelpDesk API with user profile information.
    """
    logger.info("Called home endpoint.")

    # Get user ID from JWT token (set by JWTMiddleware)
    user_id = getattr(request.state, "user_token", None)

    if not user_id:
        logger.warning("No user token found in request state")
        return JSONResponse(
            content={"message": "Welcome to FamHelpDesk API"}, status_code=200
        )

    try:
        # Create EntityRef for the user and enrich it with name from entity_lookup_index
        user_entity_ref = EntityRef(id=user_id)
        enriched_user_data = EntityRefHelper.enrich_entity_refs(user_entity_ref)

        # Get the user's name from the entity lookup
        user_name = (
            enriched_user_data.get("name")
            if isinstance(enriched_user_data, dict)
            else None
        )

        if user_name:
            message = f"Welcome to FamHelpDesk API, {user_name}!"
        else:
            message = "Welcome to FamHelpDesk API!"
            logger.warning(f"No name found in entity lookup for user_id: {user_id}")

        return JSONResponse(
            content={"message": message, "user": {"uuid": user_id, "name": user_name}},
            status_code=200,
        )

    except Exception as e:
        logger.error(f"Error looking up user entity for {user_id}: {e}")
        return JSONResponse(
            content={"message": "Welcome to FamHelpDesk API"}, status_code=200
        )
