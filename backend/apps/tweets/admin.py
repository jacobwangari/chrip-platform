from django.contrib import admin

from .models import Tweet


@admin.register(Tweet)
class TweetAdmin(admin.ModelAdmin):
    list_display = ('id', 'author', 'content', 'visibility', 'parent', 'retweet_of', 'created_at', 'deleted_at')
    list_filter = ('visibility', 'created_at')
    search_fields = ('content', 'author__username')