import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../authentication/domain/auth_controller.dart';

/// Placeholder dashboard screen — just enough to prove the authenticated
/// state (and /me/ data) round-trips correctly. Replace with the real
/// timeline once the Tweet endpoints exist.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chirp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: Center(
        child: Obx(() {
          final user = auth.currentUser.value;
          if (user == null) return const CircularProgressIndicator();

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Welcome, ${user.displayName}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('@${user.username}'),
            ],
          );
        }),
      ),
    );
  }
}
