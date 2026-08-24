import json

from channels.generic.websocket import AsyncWebsocketConsumer


class EchoConsumer(AsyncWebsocketConsumer):
    """
    TEMPORARY — bare-bones consumer with no auth and no notification
    logic. Purpose: prove Channels + Daphne + Redis are wired
    correctly end-to-end before building anything real on top.

    Connect: ws://<host>/ws/echo/
    Sends back whatever text it receives, prefixed with 'echo: '.

    Will be replaced by NotificationConsumer (JWT-authenticated,
    joins a per-user group, pushes real Notification payloads) once
    this bare-bones version is confirmed working.
    """

    async def connect(self):
        await self.accept()
        await self.send(text_data=json.dumps({'message': 'connected'}))

    async def disconnect(self, close_code):
        pass

    async def receive(self, text_data):
        await self.send(text_data=json.dumps({'message': f'echo: {text_data}'}))