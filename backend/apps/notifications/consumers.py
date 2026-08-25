import json

from channels.generic.websocket import AsyncWebsocketConsumer


def group_name_for_user(user_id):
    """Single source of truth for the group naming scheme, so the
    consumer (joining) and the signal-triggered push (sending) can
    never drift out of sync on the naming convention."""
    return f'notifications_{user_id}'


class EchoConsumer(AsyncWebsocketConsumer):
    """
    TEMPORARY — bare-bones consumer with no auth, used only to prove
    Channels + Daphne + Redis were wired correctly before adding real
    auth and notification logic. Safe to delete once NotificationConsumer
    below is confirmed working end-to-end.

    Connect: ws://<host>/ws/echo/
    """

    async def connect(self):
        await self.accept()
        await self.send(text_data=json.dumps({'message': 'connected'}))

    async def disconnect(self, close_code):
        pass

    async def receive(self, text_data):
        await self.send(text_data=json.dumps({'message': f'echo: {text_data}'}))


class NotificationConsumer(AsyncWebsocketConsumer):
    """
    Connect: ws://<host>/ws/notifications/?token=<access_token>

    Requires JWTAuthMiddleware (see middleware.py) to have already run
    and set scope['user']. Rejects the connection (close code 4001)
    if the user isn't authenticated, rather than silently accepting
    an anonymous socket.

    Each connected user joins a group scoped to their own id, so a
    notification created for them (see realtime.py) can be pushed
    only to their own open connection(s) — not broadcast to everyone.
    """

    async def connect(self):
        user = self.scope['user']

        if not user or not user.is_authenticated:
            await self.close(code=4001)
            return

        self.group_name = group_name_for_user(user.id)
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data):
        # Clients don't need to send anything for this feature — the
        # server only pushes. Ignoring inbound messages rather than
        # erroring keeps a stray client-side ping from killing the
        # connection.
        pass

    async def notification_message(self, event):
        """
        Handler name must match the 'type' key used in
        channel_layer.group_send() (Channels converts dots to
        underscores: 'notification.message' -> this method). Called
        whenever realtime.py pushes a new notification to this
        user's group.
        """
        await self.send(text_data=json.dumps(event['payload']))