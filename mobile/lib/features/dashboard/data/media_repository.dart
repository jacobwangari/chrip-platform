import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

class MediaException implements Exception {
  final String message;
  MediaException(this.message);
  @override
  String toString() => message;
}

class PresignedUpload {
  final String uploadUrl;
  final String objectUrl;
  final String mediaType;

  PresignedUpload({required this.uploadUrl, required this.objectUrl, required this.mediaType});
}

class MediaRepository {
  // Deliberately a bare Dio() instance, NOT DioClient().dio — the
  // presigned upload URL must never carry our API's Authorization
  // header or go through the 401-refresh interceptor. It's a direct
  // PUT to storage (R2/MinIO/S3), an entirely different service that
  // authenticates via the signature baked into the URL itself.
  final Dio _storageDio = Dio();

  Future<PresignedUpload> requestPresignedUpload(String contentType) async {
    try {
      final response = await DioClient().dio.post('/media/presigned-upload/', data: {
        'content_type': contentType,
      });
      return PresignedUpload(
        uploadUrl: response.data['upload_url'] as String,
        objectUrl: response.data['object_url'] as String,
        mediaType: response.data['media_type'] as String,
      );
    } on DioException catch (e) {
      throw MediaException(_extractError(e));
    }
  }

  Future<void> uploadToStorage({
    required String uploadUrl,
    required File file,
    required String contentType,
  }) async {
    try {
      final Uint8List bytes = await file.readAsBytes();
      await _storageDio.put(
        uploadUrl,
        data: bytes,
        options: Options(headers: {'Content-Type': contentType}),
      );
    } on DioException {
      throw MediaException('Upload failed — check your connection and try again.');
    }
  }

  /// Convenience wrapper: presign, then upload, returning what the
  /// tweet-creation call needs to attach this media.
  Future<PresignedUpload> uploadImage(File file, String contentType) async {
    final presigned = await requestPresignedUpload(contentType);
    await uploadToStorage(uploadUrl: presigned.uploadUrl, file: file, contentType: contentType);
    return presigned;
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data.isNotEmpty) {
      final firstKey = data.keys.first;
      final firstValue = data[firstKey];
      if (firstValue is List && firstValue.isNotEmpty) {
        return firstValue.first.toString();
      }
      return firstValue.toString();
    }
    return 'Something went wrong. Please try again.';
  }
}