from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from .consumers import group_name_for_user


def push_notification(notification):
    """
    Pushes a just-created Notification to its recipient's WebSocket
    group, if they have one open. If they're not connected, this is a
    no-op — group_send to an empty group simply does nothing, no error.

    Called from signals.py right after each Notification.objects.create()
    call. Kept as its own function (not inlined in the signal handlers)
    so the payload shape is defined in exactly one place.

    async_to_sync is required because signal handlers run synchronously
    (they're triggered by ORM .save() calls), but the channel layer's
    group_send is an async method.
    """
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return  # CHANNEL_LAYERS misconfigured — fail silently rather than crash the request

    payload = {
        'id': notification.id,
        'type': notification.type,
        'actor': {
            'id': notification.actor.id,
            'username': notification.actor.username,
            'display_name': notification.actor.display_name,
            'avatar_url': notification.actor.avatar_url,
        },
        'target_tweet_id': notification.target_tweet_id,
        'target_tweet_content': (
            notification.target_tweet.content if notification.target_tweet_id else None
        ),
        'is_read': notification.is_read,
        'created_at': notification.created_at.isoformat(),
    }

    async_to_sync(channel_layer.group_send)(
        group_name_for_user(notification.recipient_id),
        {
            'type': 'notification.message',  # routes to NotificationConsumer.notification_message
            'payload': payload,
        },
    )