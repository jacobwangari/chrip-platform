import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/inline_error_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/media_repository.dart';
import '../domain/tweet_controller.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _contentController = TextEditingController();
  // A posted tweet always belongs to the 'following' feed (it's your
  // own content, which that feed always includes) — 'discover' will
  // pick it up naturally on its next refresh, no explicit insert needed.
  final _tweets = Get.find<TweetController>(tag: 'following');
  final _mediaRepository = MediaRepository();
  final _imagePicker = ImagePicker();

  static const _maxLength = 280;

  File? _pickedImage;
  bool _isUploadingImage = false;
  String? _mediaError;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// Maps a picked file's extension to the content type the backend's
  /// presigned-upload endpoint accepts.
  String? _contentTypeFor(String path) => MediaRepository.contentTypeForPath(path);

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    if (_contentTypeFor(picked.path) == null) {
      setState(() => _mediaError = 'Unsupported image type — use JPG, PNG, or WebP.');
      return;
    }

    setState(() {
      _pickedImage = File(picked.path);
      _mediaError = null;
    });
  }

  void _removeImage() {
    setState(() => _pickedImage = null);
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _pickedImage == null) return;

    List<Map<String, String>>? media;

    if (_pickedImage != null) {
      final contentType = _contentTypeFor(_pickedImage!.path)!;
      setState(() {
        _isUploadingImage = true;
        _mediaError = null;
      });

      try {
        final uploaded = await _mediaRepository.uploadImage(_pickedImage!, contentType);
        media = [
          {'url': uploaded.objectUrl, 'media_type': uploaded.mediaType},
        ];
      } on MediaException catch (e) {
        setState(() {
          _isUploadingImage = false;
          _mediaError = e.message;
        });
        return; // don't post the tweet if the image failed to upload
      }

      setState(() => _isUploadingImage = false);
    }

    final success = await _tweets.postTweet(content, media: media);
    if (success && mounted) {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isUploadingImage;

    return Scaffold(
      appBar: AppBar(title: const Text('New tweet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _contentController,
              maxLength: _maxLength,
              maxLines: 6,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "What's happening?",
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_pickedImage != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_pickedImage!, height: 200, fit: BoxFit.cover, width: double.infinity),
                  ),
                  IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 14,
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                    onPressed: _isUploadingImage ? null : _removeImage,
                  ),
                ],
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  onPressed: (_pickedImage != null || isBusy) ? null : _pickImage,
                ),
                if (_isUploadingImage) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  const Text('Uploading...', style: TextStyle(fontSize: 13)),
                ],
              ],
            ),
            if (_mediaError != null) InlineErrorText(message: _mediaError!),
            Obx(() => InlineErrorText(message: _tweets.errorMessage.value)),
            const SizedBox(height: 8),
            Obx(() => PrimaryButton(
                  label: 'Chirp',
                  isLoading: _tweets.isPosting.value || _isUploadingImage,
                  onPressed: (_contentController.text.trim().isEmpty && _pickedImage == null)
                      ? null
                      : _submit,
                )),
          ],
        ),
      ),
    );
  }
}