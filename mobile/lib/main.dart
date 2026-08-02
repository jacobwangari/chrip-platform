import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

import 'core/network/dio_client.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/domain/auth_controller.dart';
import 'features/authentication/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  Get.put(AuthController());
  DioClient().onAuthExpired = () => Get.find<AuthController>().handleForcedLogout();

  runApp(const ChirpApp());
}

class ChirpApp extends StatelessWidget {
  const ChirpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Chirp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}

/// Chooses which screen to show based on AuthController.status, so
/// individual screens never need to know about navigation logic.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

    return Obx(() {
      switch (auth.status.value) {
        case AuthStatus.unknown:
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        case AuthStatus.authenticated:
          return const DashboardScreen();
        case AuthStatus.unauthenticated:
          return const LoginScreen();
      }
    });
  }
}
