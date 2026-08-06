from django.contrib.auth.admin import UserAdmin
from django.contrib import admin

from .models import Follow, User

admin.site.register(User, UserAdmin)


@admin.register(Follow)
class FollowAdmin(admin.ModelAdmin):
    list_display = ('id', 'follower', 'following', 'created_at')
    search_fields = ('follower__username', 'following__username')