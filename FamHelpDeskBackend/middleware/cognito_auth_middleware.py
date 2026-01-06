from starlette.responses import RedirectResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from urllib.parse import urlencode
import os
import httpx
from aws_lambda_powertools import Logger
from helpers.jwt import decode_jwt
from constants.services import API_SERVICE

logger = Logger(service=API_SERVICE)

COGNITO_DOMAIN = os.getenv("COGNITO_DOMAIN", "")
COGNITO_CLIENT_ID = os.getenv("COGNITO_CLIENT_ID", "")
COGNITO_API_REDIRECT_URI = os.getenv("COGNITO_API_REDIRECT_URI")
COGNITO_AUTH_URL = f"{COGNITO_DOMAIN}/login?" + urlencode(
    {
        "client_id": COGNITO_CLIENT_ID,
        "response_type": "code",
        "scope": "openid email profile",
        "redirect_uri": COGNITO_API_REDIRECT_URI,
    }
)


class JWTMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        logger.debug(f"JWTMiddleware: Path={request.url.path} Method={request.method}")
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
            if request.url.path == "/docs":
                logger.debug(
                    "Passing /docs request to next middleware for Cognito redirect."
                )
                return await call_next(request)
            return RedirectResponse(COGNITO_AUTH_URL)
        return await call_next(request)


class CognitoAuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        logger.debug(f"Processing authentication request: {request.url.path}")
        if request.url.path in ["/docs", "/"]:
            id_token = request.cookies.get("id_token")
            code = request.query_params.get("code")
            logger.debug(
                f"Authentication tokens - id_token: {bool(id_token)}, code: {bool(code)}"
            )
            if not id_token and code:
                logger.info("Attempting token exchange with authorization code")
                async with httpx.AsyncClient() as client:
                    token_resp = await client.post(
                        f"{COGNITO_DOMAIN}/oauth2/token",
                        data={
                            "grant_type": "authorization_code",
                            "client_id": COGNITO_CLIENT_ID,
                            "code": code,
                            "redirect_uri": COGNITO_API_REDIRECT_URI,
                        },
                        headers={"Content-Type": "application/x-www-form-urlencoded"},
                    )
                logger.debug(
                    f"Token exchange response status: {token_resp.status_code}"
                )
                if token_resp.status_code == 200:
                    tokens = token_resp.json()
                    id_token = tokens.get("id_token")
                    logger.info(
                        f"Token exchange successful, id_token received: {bool(id_token)}"
                    )
                    if id_token:
                        response = RedirectResponse(url="/docs")
                        response.set_cookie("id_token", id_token, httponly=True)
                        return response
                else:
                    logger.error(
                        f"Token exchange failed with status {token_resp.status_code}: {token_resp.text}"
                    )
                logger.info(
                    "Redirecting to Cognito login due to token exchange failure"
                )
                return RedirectResponse(COGNITO_AUTH_URL)
            if request.url.path == "/docs" and not id_token:
                logger.info(
                    "No id_token found for /docs endpoint, redirecting to Cognito login"
                )
                return RedirectResponse(COGNITO_AUTH_URL)
        return await call_next(request)
