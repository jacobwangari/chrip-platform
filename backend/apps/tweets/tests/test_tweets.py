from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import Follow
from apps.tweets.models import Like, Tweet

User = get_user_model()


def make_user(username):
    return User.objects.create_user(
        username=username, email=f'{username}@example.com', password='x', display_name=username,
    )


class TweetCreateTests(APITestCase):
    def setUp(self):
        self.alice = make_user('alice')
        self.client.force_authenticate(user=self.alice)

    def test_create_tweet(self):
        response = self.client.post('/api/tweets/', {'content': 'hello chirp'})
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['content'], 'hello chirp')
        self.assertEqual(response.data['author']['username'], 'alice')
        self.assertFalse(response.data['is_retweet'])

    def test_cannot_create_empty_tweet(self):
        response = self.client.post('/api/tweets/', {'content': ''})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_create_requires_authentication(self):
        self.client.force_authenticate(user=None)
        response = self.client.post('/api/tweets/', {'content': 'hello'})
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class TweetDeleteTests(APITestCase):
    def setUp(self):
        self.alice = make_user('alice')
        self.bob = make_user('bob')
        self.tweet = Tweet.objects.create(author=self.alice, content='mine')

    def test_author_can_delete_own_tweet(self):
        self.client.force_authenticate(user=self.alice)
        response = self.client.delete(f'/api/tweets/{self.tweet.id}/')

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.tweet.refresh_from_db()
        self.assertIsNotNone(self.tweet.deleted_at)  # soft delete, not gone from DB

    def test_other_user_cannot_delete_tweet(self):
        self.client.force_authenticate(user=self.bob)
        response = self.client.delete(f'/api/tweets/{self.tweet.id}/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_deleted_tweet_returns_404_on_detail(self):
        self.client.force_authenticate(user=self.alice)
        self.client.delete(f'/api/tweets/{self.tweet.id}/')

        response = self.client.get(f'/api/tweets/{self.tweet.id}/')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


class TweetTimelineTests(APITestCase):
    """Regression coverage for the following-based timeline filter."""

    def setUp(self):
        self.alice = make_user('alice')
        self.bob = make_user('bob')
        self.carol = make_user('carol')
        self.client.force_authenticate(user=self.alice)

        self.own_tweet = Tweet.objects.create(author=self.alice, content='mine')
        self.bob_tweet = Tweet.objects.create(author=self.bob, content='from bob')
        self.carol_tweet = Tweet.objects.create(author=self.carol, content='from carol')

    def test_timeline_excludes_unfollowed_users(self):
        response = self.client.get('/api/tweets/')
        ids = {t['id'] for t in response.data['results']}
        self.assertIn(self.own_tweet.id, ids)
        self.assertNotIn(self.bob_tweet.id, ids)
        self.assertNotIn(self.carol_tweet.id, ids)

    def test_timeline_includes_followed_users_after_following(self):
        Follow.objects.create(follower=self.alice, following=self.bob)

        response = self.client.get('/api/tweets/')
        ids = {t['id'] for t in response.data['results']}
        self.assertIn(self.bob_tweet.id, ids)
        self.assertNotIn(self.carol_tweet.id, ids)

    def test_discover_endpoint_ignores_following(self):
        response = self.client.get('/api/tweets/discover/')
        ids = {t['id'] for t in response.data['results']}
        self.assertEqual(ids, {self.own_tweet.id, self.bob_tweet.id, self.carol_tweet.id})

    def test_timeline_excludes_replies(self):
        Tweet.objects.create(author=self.alice, content='a reply', parent=self.own_tweet)
        response = self.client.get('/api/tweets/')
        ids = {t['id'] for t in response.data['results']}
        self.assertEqual(len(ids), 1)  # only the top-level own_tweet, not the reply


class TweetPaginationRegressionTests(APITestCase):
    """
    This exact bug — DRF's CursorPagination defaulting to ordering by
    '-created' instead of '-created_at' — has broken GET /api/tweets/
    three separate times during development (each time from a
    settings.py edit silently reverting DEFAULT_PAGINATION_CLASS back
    to the built-in default). This test exists specifically so that
    regression is caught immediately by the test suite instead of
    manual discovery again.
    """

    def setUp(self):
        self.alice = make_user('alice')
        self.client.force_authenticate(user=self.alice)
        for i in range(3):
            Tweet.objects.create(author=self.alice, content=f'tweet {i}')

    def test_tweet_list_endpoint_does_not_500(self):
        response = self.client.get('/api/tweets/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_tweet_list_is_ordered_newest_first(self):
        response = self.client.get('/api/tweets/')
        contents = [t['content'] for t in response.data['results']]
        self.assertEqual(contents, ['tweet 2', 'tweet 1', 'tweet 0'])

    def test_discover_endpoint_does_not_500(self):
        response = self.client.get('/api/tweets/discover/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_replies_endpoint_does_not_500(self):
        parent = Tweet.objects.first()
        response = self.client.get(f'/api/tweets/{parent.id}/replies/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)


class ReplyTests(APITestCase):
    def setUp(self):
        self.alice = make_user('alice')
        self.bob = make_user('bob')
        self.parent = Tweet.objects.create(author=self.alice, content='original')
        self.client.force_authenticate(user=self.bob)

    def test_create_reply(self):
        response = self.client.post('/api/tweets/', {'content': 'a reply', 'parent': self.parent.id})
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_reply_appears_in_parents_reply_list(self):
        self.client.post('/api/tweets/', {'content': 'a reply', 'parent': self.parent.id})
        response = self.client.get(f'/api/tweets/{self.parent.id}/replies/')
        self.assertEqual(len(response.data['results']), 1)

    def test_reply_count_reflects_replies(self):
        self.client.post('/api/tweets/', {'content': 'a reply', 'parent': self.parent.id})
        response = self.client.get(f'/api/tweets/{self.parent.id}/')
        self.assertEqual(response.data['reply_count'], 1)

    def test_cannot_reply_to_deleted_tweet(self):
        self.parent.soft_delete()
        response = self.client.post('/api/tweets/', {'content': 'too late', 'parent': self.parent.id})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class RetweetTests(APITestCase):
    def setUp(self):
        self.alice = make_user('alice')
        self.bob = make_user('bob')
        self.original = Tweet.objects.create(author=self.alice, content='original')
        self.client.force_authenticate(user=self.bob)

    def test_create_retweet(self):
        response = self.client.post('/api/tweets/', {'content': '', 'retweet_of': self.original.id})
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(response.data['is_retweet'])
        self.assertEqual(response.data['original_tweet']['id'], self.original.id)

    def test_retweet_cannot_have_its_own_content(self):
        response = self.client.post('/api/tweets/', {
            'content': 'quote tweet attempt', 'retweet_of': self.original.id,
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_cannot_retweet_a_retweet(self):
        retweet = Tweet.objects.create(author=self.bob, retweet_of=self.original)
        self.client.force_authenticate(user=self.alice)

        response = self.client.post('/api/tweets/', {'content': '', 'retweet_of': retweet.id})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_retweet_count_increments(self):
        self.client.post('/api/tweets/', {'content': '', 'retweet_of': self.original.id})
        response = self.client.get(f'/api/tweets/{self.original.id}/')
        self.assertEqual(response.data['retweet_count'], 1)


class LikeTests(APITestCase):
    def setUp(self):
        self.alice = make_user('alice')
        self.bob = make_user('bob')
        self.tweet = Tweet.objects.create(author=self.alice, content='like me')
        self.client.force_authenticate(user=self.bob)

    def test_like_creates_like_and_is_idempotent(self):
        first = self.client.post(f'/api/tweets/{self.tweet.id}/like/')
        second = self.client.post(f'/api/tweets/{self.tweet.id}/like/')

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Like.objects.filter(user=self.bob, tweet=self.tweet).count(), 1)

    def test_unlike_removes_like(self):
        self.client.post(f'/api/tweets/{self.tweet.id}/like/')
        response = self.client.delete(f'/api/tweets/{self.tweet.id}/like/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data['is_liked'])
        self.assertEqual(response.data['like_count'], 0)

    def test_is_liked_reflects_requesting_user_only(self):
        self.client.post(f'/api/tweets/{self.tweet.id}/like/')

        self.client.force_authenticate(user=self.alice)
        response = self.client.get(f'/api/tweets/{self.tweet.id}/')
        self.assertFalse(response.data['is_liked'])  # alice hasn't liked it, bob has
        self.assertEqual(response.data['like_count'], 1)