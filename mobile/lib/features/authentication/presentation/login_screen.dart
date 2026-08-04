import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../shared/widgets/inline_error_text.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../domain/auth_controller.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    // Clear any leftover error from a previous screen/attempt — see
    // AuthController.clearError for why this is needed.
    _auth.clearError();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await _auth.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
    // Navigation on success is handled by the root widget (AuthGate)
    // listening to AuthController.status — no explicit push needed here.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Chirp', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your username' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
                const SizedBox(height: 8),
                Obx(() => InlineErrorText(message: _auth.errorMessage.value)),
                const SizedBox(height: 16),
                Obx(() => PrimaryButton(
                      label: 'Log in',
                      isLoading: _auth.isLoading.value,
                      onPressed: _submit,
                    )),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Get.to(() => const RegisterScreen()),
                  child: const Text("Don't have an account? Sign up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}