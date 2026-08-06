from django.contrib.auth.models import AbstractUser
from django.db import models
from django.conf import settings
from django.core.exceptions import ValidationError

class User(AbstractUser):
    display_name = models.CharField(max_length=50)
    bio = models.CharField(max_length=160, blank=True)
    avatar_url = models.URLField(max_length=500, blank=True)
    banner_url = models.URLField(max_length=500, blank=True)
    location = models.CharField(max_length=100, blank=True)
    website = models.URLField(max_length=255, blank=True)
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.username

class Follow(models.Model):
    follower = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='following',  # user.following -> Follow rows where this user is the follower
    )
    following = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='followers',  # user.followers -> Follow rows where this user is followed
    )
    created_at = models.DateTimeField(auto_now_add=True)
 
    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['follower', 'following'], name='uq_follow_pair'),
            models.CheckConstraint(
                condition=~models.Q(follower=models.F('following')),
                name='ck_follow_no_self_follow',
            ),
        ]
        indexes = [
            models.Index(fields=['follower'], name='ix_follow_follower'),
            models.Index(fields=['following'], name='ix_follow_following'),
        ]
 
    def __str__(self):
        return f'{self.follower} -> {self.following}'
 
    def clean(self):
        if self.follower_id == self.following_id:
            raise ValidationError('A user cannot follow themselves.')
 