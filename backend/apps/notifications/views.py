from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.pagination import CreatedAtCursorPagination

from .models import Notification
from .serializers import NotificationSerializer


class NotificationListView(generics.ListAPIView):
    """
    GET /api/notifications/
    The requesting user's notifications, newest first, cursor-paginated.
    """
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = CreatedAtCursorPagination

    def get_queryset(self):
        return (
            Notification.objects.filter(recipient=self.request.user)
            .select_related('actor', 'target_tweet')
        )


class NotificationMarkReadView(APIView):
    """
    PATCH /api/notifications/{id}/read/
    Marks a single notification as read. Scoped to the requesting
    user — a 404 (not 403) is returned for another user's
    notification, so existence of other users' notifications isn't
    leaked.
    """
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, pk):
        notification = get_object_or_404(Notification, pk=pk, recipient=request.user)
        notification.is_read = True
        notification.save(update_fields=['is_read'])
        return Response(NotificationSerializer(notification).data, status=status.HTTP_200_OK)


class NotificationMarkAllReadView(APIView):
    """
    POST /api/notifications/read-all/
    Marks every unread notification for the requesting user as read —
    the usual "clear all" action for a notifications bell.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        updated = Notification.objects.filter(
            recipient=request.user, is_read=False
        ).update(is_read=True)
        return Response({'marked_read': updated}, status=status.HTTP_200_OK)