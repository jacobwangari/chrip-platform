from django.contrib.auth import get_user_model
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from drf_spectacular.utils import extend_schema

from .serializers import RegisterSerializer, UpdateProfileSerializer, UserSerializer

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