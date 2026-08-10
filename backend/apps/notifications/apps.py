from django.apps import AppConfig


class NotificationsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.notifications'

    def ready(self):
        # Imported here (not at module top) so signal handlers register
        # exactly once, after Django's app registry is fully loaded —
        # importing at module level can cause circular-import issues
        # since signals.py imports models from other apps.
        import apps.notifications.signals  # noqa: F401