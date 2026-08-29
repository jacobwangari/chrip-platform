from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

User = get_user_model()


class RegisterTests(APITestCase):
    url = '/api/auth/register/'

    def test_register_creates_user_and_returns_tokens(self):
        response = self.client.post(self.url, {
            'username': 'jane',
            'email': 'jane@example.com',
            'password': 'a-strong-password-123',
            'display_name': 'Jane Doe',
        })

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        self.assertEqual(response.data['user']['username'], 'jane')
        self.assertTrue(User.objects.filter(username='jane').exists())

    def test_register_rejects_duplicate_username_case_insensitively(self):
        User.objects.create_user(username='jane', email='a@example.com', password='x', display_name='Jane')

        response = self.client.post(self.url, {
            'username': 'JANE',
            'email': 'b@example.com',
            'password': 'a-strong-password-123',
            'display_name': 'Someone Else',
        })

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_register_rejects_duplicate_email(self):
        User.objects.create_user(username='jane', email='dupe@example.com', password='x', display_name='Jane')

        response = self.client.post(self.url, {
            'username': 'someoneelse',
            'email': 'dupe@example.com',
            'password': 'a-strong-password-123',
            'display_name': 'Someone Else',
        })

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_register_rejects_weak_password(self):
        response = self.client.post(self.url, {
            'username': 'jane',
            'email': 'jane@example.com',
            'password': '123',
            'display_name': 'Jane Doe',
        })

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class LoginRefreshLogoutTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='jane', email='jane@example.com', password='a-strong-password-123', display_name='Jane'
        )

    def test_login_returns_tokens(self):
        response = self.client.post('/api/auth/login/', {
            'username': 'jane',
            'password': 'a-strong-password-123',
        })

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)

    def test_login_rejects_wrong_password(self):
        response = self.client.post('/api/auth/login/', {
            'username': 'jane',
            'password': 'wrong-password',
        })
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_refresh_issues_new_access_token(self):
        login = self.client.post('/api/auth/login/', {
            'username': 'jane', 'password': 'a-strong-password-123',
        })
        refresh_token = login.data['refresh']

        response = self.client.post('/api/auth/refresh/', {'refresh': refresh_token})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)

    def test_logout_blacklists_refresh_token(self):
        login = self.client.post('/api/auth/login/', {
            'username': 'jane', 'password': 'a-strong-password-123',
        })
        access, refresh_token = login.data['access'], login.data['refresh']

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {access}')
        logout_response = self.client.post('/api/auth/logout/', {'refresh': refresh_token})
        self.assertEqual(logout_response.status_code, status.HTTP_205_RESET_CONTENT)

        # The now-blacklisted refresh token must no longer work.
        refresh_response = self.client.post('/api/auth/refresh/', {'refresh': refresh_token})
        self.assertEqual(refresh_response.status_code, status.HTTP_401_UNAUTHORIZED)


class MeEndpointTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='jane', email='jane@example.com', password='x', display_name='Jane'
        )
        self.client.force_authenticate(user=self.user)

    def test_get_me_returns_current_user(self):
        response = self.client.get('/api/auth/me/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['username'], 'jane')

    def test_patch_me_updates_allowed_fields_only(self):
        response = self.client.patch('/api/auth/me/', {
            'display_name': 'Jane Updated',
            'bio': 'new bio',
            'username': 'attempted-change',  # not in UpdateProfileSerializer — must be ignored
        })

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertEqual(self.user.display_name, 'Jane Updated')
        self.assertEqual(self.user.bio, 'new bio')
        self.assertEqual(self.user.username, 'jane')  # unchanged

    def test_me_requires_authentication(self):
        self.client.force_authenticate(user=None)
        response = self.client.get('/api/auth/me/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)