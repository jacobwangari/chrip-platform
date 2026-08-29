from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError
from django.db.models import Q
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.pagination import CreatedAtCursorPagination

from .models import Follow
from .serializers import FollowUserSerializer, UserSerializer

User = get_user_model()


class UserSearchView(generics.ListAPIView):
    """
    GET /api/users/search/?q=<query>
    Matches username or display_name (case-insensitive, substring).
    No pagination — capped at 20 results, since this is a "find
    people to follow as you type" search, not a browsable list. A
    ranked/paginated version would need Postgres full-text search
    with a stable rank-based ordering; plain icontains substring
    matching is sufficient at this table's size. See docs/Decisions.md.

    is_following on each result resolves automatically — ListAPIView
    passes {'request': self.request} into the serializer's context
    via get_serializer_context(), unlike the plain APIViews elsewhere
    in this app (FollowToggleView etc.) which have to do that manually.
    """
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        query = self.request.query_params.get('q', '').strip()
        if not query:
            return User.objects.none()

        return (
            User.objects.filter(
                Q(username__icontains=query) | Q(display_name__icontains=query)
            )
            .exclude(id=self.request.user.id)  # searching shouldn't surface yourself
            .order_by('username')[:20]
        )


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

        # get_or_create is genuinely idempotent — full_clean() was used
        # here previously, but its validate_unique() check queries the
        # DB and raises ValidationError on an existing row BEFORE
        # save() runs, which meant the intended "second follow = still
        # 201, no-op" behavior never worked; it 400'd instead. Caught
        # by test_follow_is_idempotent.
        Follow.objects.get_or_create(follower=request.user, following=target)

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