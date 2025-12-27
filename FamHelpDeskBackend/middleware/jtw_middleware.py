from fastapi import FastAPI, Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from helpers.jwt import decode_jwt
from aws_lambda_powertools import Logger
from constants.services import API_SERVICE

logger = Logger(service=API_SERVICE)


class JWTMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        logger.debug(f"JWTMiddleware: Path={request.url.path} Method={request.method}")

        # Allowlist unauthenticated paths: docs and OAuth callback
        if request.url.path in {"/docs", "/auth/callback"}:
            if request.url.path == "/auth/callback":
                # Log Hosted UI callback params (code/state or error)
                error = request.query_params.get("error")
                error_description = request.query_params.get("error_description")
                code = request.query_params.get("code")
                state = request.query_params.get("state")
                if error:
                    logger.warning(
                        f"OAuth callback error: {error} description: {error_description}"
                    )
                else:
                    logger.debug(
                        f"OAuth callback received. code={bool(code)} state_present={bool(state)}"
                    )
            logger.debug("Bypassing JWT check for allowed path.")
            return await call_next(request)

        auth_header = request.headers.get("authorization")
        token_user_id = None
        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header.split(" ")[1]
            logger.debug("Authorization header found, attempting to decode JWT.")
            try:
                claims = decode_jwt(token)
                token_user_id = claims.get("sub")
                logger.debug(f"JWT decoded successfully. sub: {token_user_id}")
            except Exception as e:
                logger.warning(f"JWT decode failed: {e}")
        else:
            logger.debug("No valid Authorization header found.")

        if not token_user_id:
            logger.warning(f"No valid user token for path {request.url.path}")
            # Optionally return 401 for protected routes; here we continue to let route decide

        request.state.user_token = token_user_id
        response = await call_next(request)
        logger.debug(
            f"Response status for {request.url.path}: {getattr(response, 'status_code', 'unknown')}"
        )
        return response
