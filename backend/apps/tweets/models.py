from django.conf import settings
from django.db import models


class Tweet(models.Model):
    class Visibility(models.TextChoices):
        PUBLIC = 'PUBLIC', 'Public'
        FOLLOWERS = 'FOLLOWERS', 'Followers'

    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='tweets',
    )
    content = models.CharField(max_length=280, blank=True)
    visibility = models.CharField(
        max_length=20,
        choices=Visibility.choices,
        default=Visibility.PUBLIC,
    )
    parent = models.ForeignKey(
        'self',
        on_delete=models.CASCADE,
        related_name='replies',
        null=True,
        blank=True,
    )
    retweet_of = models.ForeignKey(
        'self',
        on_delete=models.CASCADE,
        related_name='retweets',
        null=True,
        blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['author', 'created_at'], name='ix_tweet_author_timeline'),
            models.Index(fields=['parent'], name='ix_tweet_parent'),
            models.Index(fields=['retweet_of'], name='ix_tweet_retweet_of'),
        ]

    def __str__(self):
        if self.retweet_of_id:
            return f'Retweet by {self.author} of #{self.retweet_of_id}'
        return f'Tweet #{self.id} by {self.author}'

    @property
    def is_deleted(self):
        return self.deleted_at is not None

    def soft_delete(self):
        from django.utils import timezone
        self.deleted_at = timezone.now()
        self.save(update_fields=['deleted_at'])

class Media(models.Model):
    class MediaType(models.TextChoices):
        IMAGE = 'IMAGE', 'Image'
        GIF = 'GIF', 'Gif'
        VIDEO = 'VIDEO', 'Video'

    tweet = models.ForeignKey(
        Tweet,
        on_delete=models.CASCADE,
        related_name='media',
    )
    url = models.URLField(max_length=500)
    media_type = models.CharField(max_length=20, choices=MediaType.choices)
    position = models.SmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['position']
        indexes = [
            models.Index(fields=['tweet'], name='ix_media_tweet'),
        ]

    def __str__(self):
        return f'{self.media_type} on tweet #{self.tweet_id}'

class Like(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='likes',
    )
    tweet = models.ForeignKey(
        'tweets.Tweet',
        on_delete=models.CASCADE,
        related_name='likes',
    )
    created_at = models.DateTimeField(auto_now_add=True)
 
    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['user', 'tweet'], name='uq_like_pair'),
        ]
        indexes = [
            models.Index(fields=['tweet'], name='ix_like_tweet'),
        ]
 
    def __str__(self):
        return f'{self.user} likes #{self.tweet_id}'