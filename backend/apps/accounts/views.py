from django.contrib.auth import get_user_model
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from drf_spectacular.utils import extend_schema

from .serializers import LogoutSerializer, RegisterSerializer, UpdateProfileSerializer, UserSerializer

User = get_user_model()


class RegisterView(generics.CreateAPIView):
    """
    POST /api/auth/register/
    Creates a user and returns the user object plus a token pair,
    so the client can log the user straight in after registering.
    """
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        refresh = RefreshToken.for_user(user)

        return Response(
            {
                'user': UserSerializer(user).data,
                'access': str(refresh.access_token),
                'refresh': str(refresh),
            },
            status=status.HTTP_201_CREATED,
        )


@extend_schema(description='Login with username and password. Returns access + refresh tokens.')
class LoginView(TokenObtainPairView):
    """
    POST /api/auth/login/
    Thin wrapper around SimpleJWT's TokenObtainPairView so it shows up
    cleanly in the OpenAPI schema alongside the rest of the auth flow.
    """
    permission_classes = [permissions.AllowAny]


@extend_schema(description='Exchange a valid refresh token for a new access token.')
class RefreshView(TokenRefreshView):
    """
    POST /api/auth/refresh/
    """
    permission_classes = [permissions.AllowAny]


class LogoutView(APIView):
    """
    POST /api/auth/logout/
    Blacklists the given refresh token so it can no longer be used to
    obtain new access tokens. The client is still responsible for
    discarding its locally stored access/refresh tokens.
    """
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=LogoutSerializer, responses={205: None})
    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            token = RefreshToken(serializer.validated_data['refresh'])
            token.blacklist()
        except TokenError:
            return Response(
                {'detail': 'Invalid or already blacklisted refresh token.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(status=status.HTTP_205_RESET_CONTENT)


class MeView(APIView):
    """
    GET  /api/auth/me/   -> current user's profile
    PATCH /api/auth/me/  -> update current user's profile
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def patch(self, request):
        serializer = UpdateProfileSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(UserSerializer(request.user).data)