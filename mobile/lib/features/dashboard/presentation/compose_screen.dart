import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/inline_error_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/media_repository.dart';
import '../domain/tweet_controller.dart';

class ComposeScreen extends StatefulWidget {
  /// When set, this screen composes a reply instead of a new top-level
  /// tweet — the parent's id is sent as `parent`, and the result never
  /// gets inserted into a feed list (replies aren't shown there).
  final int? parentId;

  /// Shown in a "Replying to @username" banner when replying.
  final String? replyingToUsername;

  /// Called once the reply/tweet posts successfully, before popping —
  /// used by the caller to bump the parent's visible reply count
  /// locally rather than waiting on a full feed refresh.
  final VoidCallback? onPosted;

  const ComposeScreen({super.key, this.parentId, this.replyingToUsername, this.onPosted});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _contentController = TextEditingController();
  // A posted top-level tweet always belongs to the 'following' feed
  // (it's your own content, which that feed always includes) —
  // 'discover' will pick it up naturally on its next refresh. Replies
  // never touch either list, so which tagged instance handles
  // postReply doesn't matter — it's stateless beyond isPosting/error.
  final _tweets = Get.find<TweetController>(tag: 'following');
  final _mediaRepository = MediaRepository();
  final _imagePicker = ImagePicker();

  static const _maxLength = 280;

  File? _pickedImage;
  bool _isUploadingImage = false;
  String? _mediaError;

  bool get _isReply => widget.parentId != null;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

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
        return; // don't post if the image failed to upload
      }

      setState(() => _isUploadingImage = false);
    }

    final success = _isReply
        ? await _tweets.postReply(content, widget.parentId!, media: media)
        : await _tweets.postTweet(content, media: media);

    if (success && mounted) {
      widget.onPosted?.call();
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isUploadingImage;

    return Scaffold(
      appBar: AppBar(title: Text(_isReply ? 'Reply' : 'New tweet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isReply && widget.replyingToUsername != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Replying to @${widget.replyingToUsername}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            TextField(
              controller: _contentController,
              maxLength: _maxLength,
              maxLines: 6,
              autofocus: true,
              decoration: InputDecoration(
                hintText: _isReply ? 'Post your reply' : "What's happening?",
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
                  label: _isReply ? 'Reply' : 'Chirp',
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