import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shared/widgets/inline_error_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../domain/tweet_controller.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _contentController = TextEditingController();
  final _tweets = Get.find<TweetController>();

  static const _maxLength = 280;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await _tweets.postTweet(_contentController.text);
    if (success && mounted) {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Obx(() => InlineErrorText(message: _tweets.errorMessage.value)),
            const SizedBox(height: 8),
            Obx(() => PrimaryButton(
                  label: 'Chirp',
                  isLoading: _tweets.isPosting.value,
                  onPressed: _contentController.text.trim().isEmpty ? null : _submit,
                )),
          ],
        ),
      ),
    );
  }
}
