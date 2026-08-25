import os

from channels.routing import ProtocolTypeRouter, URLRouter
from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

# get_asgi_application() must be called before importing anything that
# touches Django models/apps (like routing/middleware modules) — this
# populates Django's app registry first, same ordering requirement as
# wsgi.py.
django_asgi_app = get_asgi_application()

from apps.notifications import routing as notifications_routing  # noqa: E402
from apps.notifications.middleware import JWTAuthMiddleware  # noqa: E402

application = ProtocolTypeRouter({
    'http': django_asgi_app,
    'websocket': JWTAuthMiddleware(
        URLRouter(
            notifications_routing.websocket_urlpatterns
        )
    ),
})