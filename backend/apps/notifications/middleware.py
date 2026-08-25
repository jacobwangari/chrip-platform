from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import AccessToken

User = get_user_model()


@database_sync_to_async
def get_user_from_token(token_str):
    """
    Validates the access token's signature and expiry, then looks up
    the user. Runs off the event loop (database_sync_to_async) since
    both token validation's DB checks (blacklist lookups) and the
    user query are synchronous ORM calls.
    """
    try:
        access_token = AccessToken(token_str)
        user_id = access_token['user_id']
        return User.objects.get(id=user_id)
    except (InvalidToken, TokenError, User.DoesNotExist, KeyError):
        return AnonymousUser()


class JWTAuthMiddleware(BaseMiddleware):
    """
    Authenticates WebSocket connections using the same JWT access
    tokens issued by SimpleJWT for REST requests — but since a
    WebSocket handshake can't carry a custom Authorization header the
    way a normal HTTP request does (browsers' native WebSocket API
    doesn't support setting headers), the token is passed as a query
    parameter instead: ws://host/ws/notifications/?token=<access>

    On success, scope['user'] is a real User instance. On failure
    (missing/invalid/expired token), scope['user'] is AnonymousUser —
    the consumer itself decides what to do with that (reject the
    connection), this middleware only resolves identity.
    """

    async def __call__(self, scope, receive, send):
        query_string = scope.get('query_string', b'').decode()
        query_params = parse_qs(query_string)
        token_str = query_params.get('token', [None])[0]

        if token_str:
            scope['user'] = await get_user_from_token(token_str)
        else:
            scope['user'] = AnonymousUser()

        return await super().__call__(scope, receive, send)