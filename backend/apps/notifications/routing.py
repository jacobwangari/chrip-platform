from django.urls import re_path

from . import consumers

websocket_urlpatterns = [
    re_path(r'ws/notifications/$', consumers.NotificationConsumer.as_asgi()),
    # TEMPORARY — remove once NotificationConsumer is confirmed working.
    re_path(r'ws/echo/$', consumers.EchoConsumer.as_asgi()),
]