
from django.contrib import admin
from django.urls import path,include
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
)
from apps.accounts.accounts_urls import user_urlpatterns

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('apps.accounts.accounts_urls')),
    path('api/tweets/', include('apps.tweets.urls')),
    path('api/users/', include((user_urlpatterns, 'accounts'), namespace='users')),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path(
        "api/docs/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",),

]
