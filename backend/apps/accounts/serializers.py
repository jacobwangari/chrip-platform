from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    """Public-facing user representation — used for /me and nested in other responses."""

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
            'created_at',
        )
        read_only_fields = ('id', 'is_verified', 'created_at')


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