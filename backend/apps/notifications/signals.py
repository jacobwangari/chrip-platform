from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.accounts.models import Follow
from apps.tweets.models import Like, Tweet

from .models import Notification


@receiver(post_save, sender=Like)
def notify_on_like(sender, instance, created, **kwargs):
    if not created:
        return
    tweet = instance.tweet
    if tweet.author_id == instance.user_id:
        return  # don't notify users about their own actions
    Notification.objects.create(
        recipient=tweet.author,
        actor=instance.user,
        type=Notification.NotificationType.LIKE,
        target_tweet=tweet,
    )


@receiver(post_save, sender=Follow)
def notify_on_follow(sender, instance, created, **kwargs):
    if not created:
        return
    # Follow already blocks self-follow at the model/view level, but
    # guard here too — cheap, and this handler shouldn't assume that
    # invariant holds forever.
    if instance.follower_id == instance.following_id:
        return
    Notification.objects.create(
        recipient=instance.following,
        actor=instance.follower,
        type=Notification.NotificationType.FOLLOW,
    )


@receiver(post_save, sender=Tweet)
def notify_on_reply_or_retweet(sender, instance, created, **kwargs):
    if not created:
        return

    if instance.parent_id:
        parent = instance.parent
        if parent.author_id != instance.author_id:
            Notification.objects.create(
                recipient=parent.author,
                actor=instance.author,
                type=Notification.NotificationType.REPLY,
                target_tweet=parent,
            )

    if instance.retweet_of_id:
        original = instance.retweet_of
        if original.author_id != instance.author_id:
            Notification.objects.create(
                recipient=original.author,
                actor=instance.author,
                type=Notification.NotificationType.RETWEET,
                target_tweet=original,
            )