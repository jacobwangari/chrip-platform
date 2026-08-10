from rest_framework import serializers

from apps.accounts.serializers import UserSerializer

from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    actor = UserSerializer(read_only=True)
    # Lightweight — just enough for the client to link to the tweet
    # and show a content preview, without pulling in the full
    # TweetSerializer (which would need request context for
    # is_liked/is_following and adds unnecessary weight here).
    target_tweet_id = serializers.IntegerField(source='target_tweet.id', read_only=True, allow_null=True)
    target_tweet_content = serializers.CharField(
        source='target_tweet.content', read_only=True, allow_null=True, default=None
    )

    class Meta:
        model = Notification
        fields = (
            'id',
            'actor',
            'type',
            'target_tweet_id',
            'target_tweet_content',
            'is_read',
            'created_at',
        )
        read_only_fields = fields