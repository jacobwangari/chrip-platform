import 'package:flutter/material.dart';

/// Shared inline error message — small, but used identically across
/// every form in the app (auth, and later tweet composer, profile edit).
class InlineErrorText extends StatelessWidget {
  final String message;

  const InlineErrorText({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }
}
