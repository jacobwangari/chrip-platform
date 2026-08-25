from rest_framework import serializers

from apps.accounts.serializers import UserSerializer

from .models import Like, Media, Tweet


class MediaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Media
        fields = ('id', 'url', 'media_type', 'position')


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
    media = MediaSerializer(many=True, read_only=True)

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
            'media',
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


class MediaInputSerializer(serializers.Serializer):
    """Write-only shape for attaching media at tweet-creation time —
    just enough info to create a Media row from what the presigned
    upload endpoint already returned to the client."""
    url = serializers.URLField(max_length=500)
    media_type = serializers.ChoiceField(choices=Media.MediaType.choices)


class TweetCreateSerializer(serializers.ModelSerializer):
    """Write representation — accepts either original content, a reply
    (via parent), or a retweet (via retweet_of), not several at once."""

    media = MediaInputSerializer(many=True, required=False, write_only=True)

    class Meta:
        model = Tweet
        fields = ('content', 'visibility', 'parent', 'retweet_of', 'media')

    def validate(self, attrs):
        content = attrs.get('content', '').strip()
        retweet_of = attrs.get('retweet_of')
        media = attrs.get('media', [])

        if retweet_of and (content or media):
            raise serializers.ValidationError(
                'A retweet cannot have its own content or media — use quote tweets for that (not supported yet).'
            )

        if not retweet_of and not content and not media:
            raise serializers.ValidationError('A tweet needs content or media.')

        if len(media) > 4:
            raise serializers.ValidationError('A tweet can have at most 4 media items.')

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
        media_items = validated_data.pop('media', [])
        validated_data['author'] = self.context['request'].user
        tweet = super().create(validated_data)

        # Created alongside the tweet in one call, not as a second
        # round-trip the client has to make — a tweet with media
        # either has all of it attached or, if this somehow failed,
        # none of it; there's no in-between state visible to the client.
        Media.objects.bulk_create([
            Media(
                tweet=tweet,
                url=item['url'],
                media_type=item['media_type'],
                position=index,
            )
            for index, item in enumerate(media_items)
        ])

        return tweet