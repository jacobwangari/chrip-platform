from rest_framework import generics, permissions
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response

from .models import Tweet
from .serializers import TweetCreateSerializer, TweetSerializer


class TweetListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/tweets/   -> all non-deleted, top-level tweets (no replies),
                            newest first, cursor-paginated
    POST /api/tweets/   -> create a tweet, reply, or retweet
    """
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            Tweet.objects.filter(deleted_at__isnull=True, parent__isnull=True)
            .select_related('author')
        )

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return TweetCreateSerializer
        return TweetSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        tweet = serializer.save()
        # Respond with the full read representation, not the write one,
        # so the client immediately has author/counts without a refetch.
        return Response(TweetSerializer(tweet).data, status=201)


class TweetDetailView(generics.RetrieveDestroyAPIView):
    """
    GET    /api/tweets/{id}/  -> a single tweet
    DELETE /api/tweets/{id}/  -> soft-delete (author only)
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = TweetSerializer

    def get_queryset(self):
        return Tweet.objects.filter(deleted_at__isnull=True).select_related('author')

    def perform_destroy(self, instance):
        if instance.author_id != self.request.user.id:
            raise PermissionDenied("You can only delete your own tweets.")
        instance.soft_delete()


class TweetReplyListView(generics.ListAPIView):
    """
    GET /api/tweets/{id}/replies/  -> replies to a tweet, oldest first
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = TweetSerializer

    def get_queryset(self):
        return (
            Tweet.objects.filter(
                parent_id=self.kwargs['pk'],
                deleted_at__isnull=True,
            )
            .select_related('author')
            .order_by('created_at')
        )