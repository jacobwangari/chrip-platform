import uuid

import boto3
from botocore.client import Config
from django.conf import settings
from rest_framework import permissions, status
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

# Content types accepted for upload, mapped to Media.MediaType — kept
# deliberately restrictive rather than accepting anything the client claims.
ALLOWED_CONTENT_TYPES = {
    'image/jpeg': 'IMAGE',
    'image/png': 'IMAGE',
    'image/webp': 'IMAGE',
    'image/gif': 'GIF',
    'video/mp4': 'VIDEO',
}


def _r2_client():
    return boto3.client(
        's3',
        endpoint_url=settings.R2_ENDPOINT_URL,
        aws_access_key_id=settings.R2_ACCESS_KEY_ID,
        aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
        config=Config(signature_version='s3v4'),
        region_name='auto',
    )


class PresignedUploadView(APIView):
    """
    POST /api/media/presigned-upload/
    Body: {"content_type": "image/jpeg"}

    Returns a short-lived presigned PUT URL the client uploads directly
    to (bytes never pass through Django), plus the final public
    object_url and the inferred media_type — both needed by the client
    when it later creates the tweet with this media attached.

    No Media row is created here — that only happens once the tweet
    itself is created (see TweetCreateSerializer), so an upload the
    user abandons mid-flow never leaves an orphaned DB row.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        content_type = request.data.get('content_type')
        media_type = ALLOWED_CONTENT_TYPES.get(content_type)

        if media_type is None:
            raise ValidationError({
                'content_type': f'Unsupported content type. Allowed: {", ".join(ALLOWED_CONTENT_TYPES)}'
            })

        extension = content_type.split('/')[-1]
        object_key = f'media/{request.user.id}/{uuid.uuid4()}.{extension}'

        client = _r2_client()
        upload_url = client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': settings.R2_BUCKET_NAME,
                'Key': object_key,
                'ContentType': content_type,
            },
            ExpiresIn=settings.R2_PRESIGNED_URL_EXPIRY_SECONDS,
        )

        object_url = f'{settings.R2_PUBLIC_BASE_URL.rstrip("/")}/{object_key}'

        return Response({
            'upload_url': upload_url,
            'object_url': object_url,
            'media_type': media_type,
            'expires_in': settings.R2_PRESIGNED_URL_EXPIRY_SECONDS,
        }, status=status.HTTP_200_OK)