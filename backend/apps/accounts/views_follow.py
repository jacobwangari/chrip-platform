from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.pagination import CreatedAtCursorPagination

from .models import Follow
from .serializers import FollowUserSerializer, UserSerializer

User = get_user_model()


class UserDetailView(generics.RetrieveAPIView):
    """
    GET /api/users/{username}/
    Public profile lookup by username — needed by the mobile profile
    screen and by the follow button to resolve who's being followed.
    """
    queryset = User.objects.all()
    serializer_class = UserSerializer
    lookup_field = 'username'
    permission_classes = [permissions.IsAuthenticated]


class FollowToggleView(APIView):
    """
    POST   /api/users/{username}/follow/    -> follow this user
    DELETE /api/users/{username}/follow/    -> unfollow this user
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, username):
        target = get_object_or_404(User, username=username)

        if target.id == request.user.id:
            raise ValidationError('You cannot follow yourself.')

        follow = Follow(follower=request.user, following=target)
        try:
            follow.full_clean()
            follow.save()
        except IntegrityError:
            # Already following — treat as idempotent success rather than an error.
            pass
        except DjangoValidationError as e:
            raise ValidationError(e.message_dict if hasattr(e, 'message_dict') else str(e))

        return Response(UserSerializer(target, context={'request': request}).data, status=status.HTTP_201_CREATED)

    def delete(self, request, username):
        target = get_object_or_404(User, username=username)
        Follow.objects.filter(follower=request.user, following=target).delete()
        return Response(UserSerializer(target, context={'request': request}).data, status=status.HTTP_200_OK)


class FollowersListView(generics.ListAPIView):
    """GET /api/users/{username}/followers/ — users who follow this user."""
    serializer_class = FollowUserSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = CreatedAtCursorPagination

    def get_queryset(self):
        target = get_object_or_404(User, username=self.kwargs['username'])
        follower_ids = Follow.objects.filter(following=target).values_list('follower_id', flat=True)
        return User.objects.filter(id__in=follower_ids)


class FollowingListView(generics.ListAPIView):
    """GET /api/users/{username}/following/ — users this user follows."""
    serializer_class = FollowUserSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = CreatedAtCursorPagination

    def get_queryset(self):
        target = get_object_or_404(User, username=self.kwargs['username'])
        following_ids = Follow.objects.filter(follower=target).values_list('following_id', flat=True)
        return User.objects.filter(id__in=following_ids)