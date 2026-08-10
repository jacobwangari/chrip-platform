from django.conf import settings
from django.db import models


class Notification(models.Model):
    class NotificationType(models.TextChoices):
        LIKE = 'LIKE', 'Like'
        RETWEET = 'RETWEET', 'Retweet'
        FOLLOW = 'FOLLOW', 'Follow'
        REPLY = 'REPLY', 'Reply'
        MENTION = 'MENTION', 'Mention'  # not yet created anywhere — Mention model doesn't exist yet

    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications',
    )
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='+',  # no reverse accessor needed from the actor's side
    )
    type = models.CharField(max_length=20, choices=NotificationType.choices)
    target_tweet = models.ForeignKey(
        'tweets.Tweet',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
    )
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['recipient', 'is_read'], name='ix_notification_inbox'),
            models.Index(fields=['recipient', 'created_at'], name='ix_notification_recent'),
        ]

    def __str__(self):
        return f'{self.actor} {self.type} -> {self.recipient}'