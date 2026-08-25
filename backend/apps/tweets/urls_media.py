from django.urls import path

from .views_media import PresignedUploadView

urlpatterns = [
    path('presigned-upload/', PresignedUploadView.as_view(), name='media-presigned-upload'),
]