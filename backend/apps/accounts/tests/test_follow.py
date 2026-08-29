from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from apps.accounts.models import Follow

User = get_user_model()


def make_user(username, display_name=None):
    return User.objects.create_user(
        username=username,
        email=f'{username}@example.com',
        password='x',
        display_name=display_name or username,
    )


class FollowToggleTests(APITestCase):
    def setUp(self):
        self.alice = make_user('alice')
        self.bob = make_user('bob')
        self.client.force_authenticate(user=self.alice)

    def test_follow_creates_relationship(self):
        response = self.client.post(f'/api/users/{self.bob.username}/follow/')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(Follow.objects.filter(follower=self.alice, following=self.bob).exists())
        self.assertTrue(response.data['is_following'])

    def test_follow_is_idempotent(self):
        self.client.post(f'/api/users/{self.bob.username}/follow/')
        response = self.client.post(f'/api/users/{self.bob.username}/follow/')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Follow.objects.filter(follower=self.alice, following=self.bob).count(), 1)

    def test_cannot_follow_self(self):
        response = self.client.post(f'/api/users/{self.alice.username}/follow/')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(Follow.objects.filter(follower=self.alice, following=self.alice).exists())

    def test_unfollow_removes_relationship(self):
        self.client.post(f'/api/users/{self.bob.username}/follow/')

        response = self.client.delete(f'/api/users/{self.bob.username}/follow/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data['is_following'])
        self.assertFalse(Follow.objects.filter(follower=self.alice, following=self.bob).exists())

    def test_unfollow_when_not_following_is_a_safe_noop(self):
        response = self.client.delete(f'/api/users/{self.bob.username}/follow/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_follower_and_following_counts_update(self):
        self.client.post(f'/api/users/{self.bob.username}/follow/')

        bob_profile = self.client.get(f'/api/users/{self.bob.username}/')
        self.assertEqual(bob_profile.data['follower_count'], 1)

        # Alice followed Bob, so Alice's own following_count is 1 —
        # viewed here from Bob's session to also confirm the count is
        # visible correctly to someone other than Alice herself.
        self.client.force_authenticate(user=self.bob)
        alice_seen_by_bob = self.client.get(f'/api/users/{self.alice.username}/')
        self.assertEqual(alice_seen_by_bob.data['following_count'], 1)


class FollowersFollowingListTests(APITestCase):
    def setUp(self):
        self.alice = make_user('alice')
        self.bob = make_user('bob')
        self.carol = make_user('carol')
        Follow.objects.create(follower=self.bob, following=self.alice)
        Follow.objects.create(follower=self.carol, following=self.alice)
        self.client.force_authenticate(user=self.alice)

    def test_followers_list_contains_expected_users(self):
        response = self.client.get(f'/api/users/{self.alice.username}/followers/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        usernames = {u['username'] for u in response.data['results']}
        self.assertEqual(usernames, {'bob', 'carol'})

    def test_following_list_for_a_user_who_follows_nobody_is_empty(self):
        response = self.client.get(f'/api/users/{self.alice.username}/following/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['results'], [])


class UserSearchTests(APITestCase):
    def setUp(self):
        self.alice = make_user('alice', display_name='Alice Wonderland')
        self.bob = make_user('bob_smith', display_name='Bob Smith')
        self.client.force_authenticate(user=self.alice)

    def test_search_matches_username_substring(self):
        response = self.client.get('/api/users/search/', {'q': 'bob'})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        usernames = {u['username'] for u in response.data}
        self.assertIn('bob_smith', usernames)

    def test_search_matches_display_name_substring(self):
        # Search as Bob for Alice — UserSearchView excludes the
        # requesting user from their own results, so Alice searching
        # for her own display name would never find herself.
        self.client.force_authenticate(user=self.bob)
        response = self.client.get('/api/users/search/', {'q': 'Wonderland'})
        usernames = {u['username'] for u in response.data}
        self.assertIn('alice', usernames)

    def test_search_excludes_the_requesting_user(self):
        response = self.client.get('/api/users/search/', {'q': 'alice'})
        usernames = {u['username'] for u in response.data}
        self.assertNotIn('alice', usernames)

    def test_search_with_no_query_returns_empty(self):
        response = self.client.get('/api/users/search/')
        self.assertEqual(response.data, [])

    def test_search_response_is_not_paginated(self):
        # This endpoint deliberately has pagination_class = None —
        # a plain list, not the usual {results, next} envelope.
        response = self.client.get('/api/users/search/', {'q': 'bob'})
        self.assertIsInstance(response.data, list)