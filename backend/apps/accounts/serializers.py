from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from .models import Follow, User

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    """
    Public-facing user representation — used for /me and nested in
    other responses (tweets, follower lists, etc).
 
    follower_count / following_count are computed at read time, same
    tradeoff as Tweet's reply_count/retweet_count — see docs/Decisions.md.
 
    is_following is only meaningful when the serializer is given the
    requesting user via context; it's None (omitted as false) otherwise,
    e.g. when serializing the user's own profile.
    """
 
    follower_count = serializers.SerializerMethodField()
    following_count = serializers.SerializerMethodField()
    is_following = serializers.SerializerMethodField()
 
    class Meta:
        model = User
        fields = (
            'id',
            'username',
            'display_name',
            'email',
            'bio',
            'avatar_url',
            'banner_url',
            'location',
            'website',
            'is_verified',
            'follower_count',
            'following_count',
            'is_following',
            'created_at',
        )
        read_only_fields = ('id', 'is_verified', 'created_at')
 
    def get_follower_count(self, obj):
        return obj.followers.count()
 
    def get_following_count(self, obj):
        return obj.following.count()
 
    def get_is_following(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        if request.user.id == obj.id:
            return False
        return Follow.objects.filter(follower=request.user, following=obj).exists()
 
 
class FollowUserSerializer(serializers.ModelSerializer):
    """Lightweight representation for follower/following list rows —
    avoids the count-query overhead of the full UserSerializer per row."""
 
    class Meta:
        model = User
        fields = ('id', 'username', 'display_name', 'avatar_url', 'bio')
 
class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])

    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'display_name')

    def validate_username(self, value):
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError('This username is already taken.')
        return value

    def validate_email(self, value):
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError('An account with this email already exists.')
        return value

    def create(self, validated_data):
        password = validated_data.pop('password')
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user
 
class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()


class UpdateProfileSerializer(serializers.ModelSerializer):
    """Used for PATCH /me — deliberately excludes username/email (handle separately if needed)."""

    class Meta:
        model = User
        fields = (
            'display_name',
            'bio',
            'avatar_url',
            'banner_url',
            'location',
            'website',
        )