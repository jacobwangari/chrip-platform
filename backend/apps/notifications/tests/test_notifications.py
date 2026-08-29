from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import Follow
from apps.notifications.models import Notification
from apps.tweets.models import Like, Tweet

User = get_user_model()


def make_user(username):
    return User.objects.create_user(
        username=username, email=f'{username}@example.com', password='x', display_name=username,
    )


class NotificationCreationTests(APITestCase):
    """
    Notifications are created via signals (see apps/notifications/signals.py),
    not inline in the tweets/accounts views — these tests exercise the
    real REST endpoints so the signal wiring is verified end-to-end,
    not just the signal handler function in isolation.
    """

    def setUp(self):
        self.alice = make_user('alice')
        self.bob = make_user('bob')

    def test_like_creates_notification_for_tweet_author(self):
        tweet = Tweet.objects.create(author=self.alice, content='hi')
        self.client.force_authenticate(user=self.bob)

        self.client.post(f'/api/tweets/{tweet.id}/like/')

        notification = Notification.objects.get(recipient=self.alice, type=Notification.NotificationType.LIKE)
        self.assertEqual(notification.actor, self.bob)
        self.assertEqual(notification.target_tweet, tweet)

    def test_liking_own_tweet_creates_no_notification(self):
        tweet = Tweet.objects.create(author=self.alice, content='hi')
        self.client.force_authenticate(user=self.alice)

        self.client.post(f'/api/tweets/{tweet.id}/like/')

        self.assertFalse(Notification.objects.filter(recipient=self.alice).exists())

    def test_follow_creates_notification(self):
        self.client.force_authenticate(user=self.bob)
        self.client.post(f'/api/users/{self.alice.username}/follow/')

        notification = Notification.objects.get(
            recipient=self.alice, type=Notification.NotificationType.FOLLOW,
        )
        self.assertEqual(notification.actor, self.bob)

    def test_reply_creates_notification_for_parent_author(self):
        parent = Tweet.objects.create(author=self.alice, content='original')
        self.client.force_authenticate(user=self.bob)

        self.client.post('/api/tweets/', {'content': 'a reply', 'parent': parent.id})

        notification = Notification.objects.get(
            recipient=self.alice, type=Notification.NotificationType.REPLY,
        )
        self.assertEqual(notification.target_tweet, parent)

    def test_retweet_creates_notification_for_original_author(self):
        original = Tweet.objects.create(author=self.alice, content='original')
        self.client.force_authenticate(user=self.bob)

        self.client.post('/api/tweets/', {'content': '', 'retweet_of': original.id})

        notification = Notification.objects.get(
            recipient=self.alice, type=Notification.NotificationType.RETWEET,
        )
        self.assertEqual(notification.target_tweet, original)

    def test_replying_to_own_tweet_creates_no_notification(self):
        parent = Tweet.objects.create(author=self.alice, content='original')
        self.client.force_authenticate(user=self.alice)

        self.client.post('/api/tweets/', {'content': 'replying to myself', 'parent': parent.id})

        self.assertFalse(Notification.objects.filter(recipient=self.alice).exists())


class NotificationEndpointTests(APITestCase):
    def setUp(self):
        self.alice = make_user('alice')
        self.bob = make_user('bob')
        self.client.force_authenticate(user=self.alice)

        self.notification = Notification.objects.create(
            recipient=self.alice, actor=self.bob, type=Notification.NotificationType.FOLLOW,
        )

    def test_list_only_shows_own_notifications(self):
        other_recipient = make_user('carol')
        Notification.objects.create(
            recipient=other_recipient, actor=self.bob, type=Notification.NotificationType.FOLLOW,
        )

        response = self.client.get('/api/notifications/')
        ids = {n['id'] for n in response.data['results']}
        self.assertEqual(ids, {self.notification.id})

    def test_mark_read(self):
        response = self.client.patch(f'/api/notifications/{self.notification.id}/read/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.notification.refresh_from_db()
        self.assertTrue(self.notification.is_read)

    def test_cannot_mark_another_users_notification_as_read(self):
        self.client.force_authenticate(user=self.bob)
        response = self.client.patch(f'/api/notifications/{self.notification.id}/read/')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_mark_all_read(self):
        Notification.objects.create(
            recipient=self.alice, actor=self.bob, type=Notification.NotificationType.LIKE,
        )

        response = self.client.post('/api/notifications/read-all/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['marked_read'], 2)
        self.assertFalse(Notification.objects.filter(recipient=self.alice, is_read=False).exists())