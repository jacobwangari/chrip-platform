from django.contrib import admin

from .models import Like, Media, Tweet


@admin.register(Tweet)
class TweetAdmin(admin.ModelAdmin):
    list_display = ('id', 'author', 'content', 'visibility', 'parent', 'retweet_of', 'created_at', 'deleted_at')
    list_filter = ('visibility', 'created_at')
    search_fields = ('content', 'author__username')


@admin.register(Like)
class LikeAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'tweet', 'created_at')
    search_fields = ('user__username',)

@admin.register(Media)
class MediaAdmin(admin.ModelAdmin):
    list_display = ('id', 'tweet', 'media_type', 'position', 'created_at')