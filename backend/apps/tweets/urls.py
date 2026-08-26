from django.urls import path

from .views import DiscoverTweetListView, LikeToggleView, TweetDetailView, TweetListCreateView, TweetReplyListView

urlpatterns = [
    path('', TweetListCreateView.as_view(), name='tweet-list-create'),
    path('discover/', DiscoverTweetListView.as_view(), name='tweet-discover'),
    path('<int:pk>/', TweetDetailView.as_view(), name='tweet-detail'),
    path('<int:pk>/replies/', TweetReplyListView.as_view(), name='tweet-replies'),
    path('<int:pk>/like/', LikeToggleView.as_view(), name='tweet-like-toggle'),
]