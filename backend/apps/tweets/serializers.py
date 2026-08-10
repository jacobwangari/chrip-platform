from rest_framework import serializers

from apps.accounts.serializers import UserSerializer

from .models import Like, Tweet


class OriginalTweetSerializer(serializers.ModelSerializer):
    """
    Lightweight, non-recursive representation of the tweet being
    retweeted — no counts, no further nesting. Safe against recursion
    because TweetCreateSerializer already blocks retweeting a retweet,
    so retweet_of always points to a true original.
    """

    author = UserSerializer(read_only=True)

    class Meta:
        model = Tweet
        fields = ('id', 'author', 'content', 'created_at')


class TweetSerializer(serializers.ModelSerializer):
    """Read representation — nests a lightweight author so the client
    doesn't need a second call per tweet to render a feed.

    is_liked requires context={'request': request} to be accurate —
    same pattern as UserSerializer.is_following. Without it, is_liked
    silently returns False rather than erroring.
    """

    author = UserSerializer(read_only=True)
    reply_count = serializers.SerializerMethodField()
    retweet_count = serializers.SerializerMethodField()
    like_count = serializers.SerializerMethodField()
    is_retweet = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()
    original_tweet = serializers.SerializerMethodField()

    class Meta:
        model = Tweet
        fields = (
            'id',
            'author',
            'content',
            'visibility',
            'parent',
            'retweet_of',
            'is_retweet',
            'original_tweet',
            'reply_count',
            'retweet_count',
            'like_count',
            'is_liked',
            'created_at',
            'updated_at',
        )
        read_only_fields = fields

    def get_reply_count(self, obj):
        # Computed at read time rather than denormalized — see
        # docs/Decisions.md for the tradeoff. Excludes soft-deleted replies.
        return obj.replies.filter(deleted_at__isnull=True).count()

    def get_retweet_count(self, obj):
        return obj.retweets.filter(deleted_at__isnull=True).count()

    def get_like_count(self, obj):
        return obj.likes.count()

    def get_is_retweet(self, obj):
        return obj.retweet_of_id is not None

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        return obj.likes.filter(user=request.user).exists()

    def get_original_tweet(self, obj):
        if obj.retweet_of_id is None:
            return None
        return OriginalTweetSerializer(obj.retweet_of).data


class TweetCreateSerializer(serializers.ModelSerializer):
    """Write representation — accepts either original content, a reply
    (via parent), or a retweet (via retweet_of), not several at once."""

    class Meta:
        model = Tweet
        fields = ('content', 'visibility', 'parent', 'retweet_of')

    def validate(self, attrs):
        content = attrs.get('content', '').strip()
        retweet_of = attrs.get('retweet_of')

        if retweet_of and content:
            raise serializers.ValidationError(
                'A retweet cannot also have its own content — use quote tweets for that (not supported yet).'
            )

        if not retweet_of and not content:
            raise serializers.ValidationError('Tweet content cannot be empty.')

        if retweet_of and retweet_of.deleted_at is not None:
            raise serializers.ValidationError('Cannot retweet a deleted tweet.')

        if retweet_of and retweet_of.retweet_of_id is not None:
            raise serializers.ValidationError(
                'Cannot retweet a retweet — retweet the original tweet instead.'
            )

        parent = attrs.get('parent')
        if parent and parent.deleted_at is not None:
            raise serializers.ValidationError('Cannot reply to a deleted tweet.')

        return attrs

    def create(self, validated_data):
        validated_data['author'] = self.context['request'].user
        return super().create(validated_data)