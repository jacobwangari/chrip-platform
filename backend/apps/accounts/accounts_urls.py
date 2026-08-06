from django.urls import path

from .views import LoginView, LogoutView, MeView, RefreshView, RegisterView
from .views_follow import FollowersListView, FollowingListView, FollowToggleView, UserDetailView

urlpatterns = [
    path('register/', RegisterView.as_view(), name='auth-register'),
    path('login/', LoginView.as_view(), name='auth-login'),
    path('refresh/', RefreshView.as_view(), name='auth-refresh'),
    path('logout/', LogoutView.as_view(), name='auth-logout'),
    path('me/', MeView.as_view(), name='auth-me'),
]
# Registered separately under /api/users/ in config/urls.py — see below.
user_urlpatterns = [
    path('<str:username>/', UserDetailView.as_view(), name='user-detail'),
    path('<str:username>/follow/', FollowToggleView.as_view(), name='user-follow-toggle'),
    path('<str:username>/followers/', FollowersListView.as_view(), name='user-followers'),
    path('<str:username>/following/', FollowingListView.as_view(), name='user-following'),
]