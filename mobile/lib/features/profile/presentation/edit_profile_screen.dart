import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/inline_error_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../authentication/domain/auth_controller.dart';
import '../../dashboard/data/media_repository.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = Get.find<AuthController>();
  final _mediaRepository = MediaRepository();
  final _imagePicker = ImagePicker();

  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  late final TextEditingController _websiteController;

  File? _pickedAvatar;
  bool _isUploadingAvatar = false;
  String? _avatarError;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser.value;
    _displayNameController = TextEditingController(text: user?.displayName ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _locationController = TextEditingController(text: user?.location ?? '');
    _websiteController = TextEditingController(text: user?.website ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    if (MediaRepository.contentTypeForPath(picked.path) == null) {
      setState(() => _avatarError = 'Unsupported image type — use JPG, PNG, or WebP.');
      return;
    }

    setState(() {
      _pickedAvatar = File(picked.path);
      _avatarError = null;
    });
  }

  Future<void> _submit() async {
    String? newAvatarUrl;

    if (_pickedAvatar != null) {
      final contentType = MediaRepository.contentTypeForPath(_pickedAvatar!.path)!;
      setState(() {
        _isUploadingAvatar = true;
        _avatarError = null;
      });

      try {
        final uploaded = await _mediaRepository.uploadImage(_pickedAvatar!, contentType);
        newAvatarUrl = uploaded.objectUrl;
      } on MediaException catch (e) {
        setState(() {
          _isUploadingAvatar = false;
          _avatarError = e.message;
        });
        return; // don't save the rest of the form if the avatar upload failed
      }

      setState(() => _isUploadingAvatar = false);
    }

    final success = await _auth.updateProfile({
      'display_name': _displayNameController.text.trim(),
      'bio': _bioController.text.trim(),
      'location': _locationController.text.trim(),
      'website': _websiteController.text.trim(),
      if (newAvatarUrl != null) 'avatar_url': newAvatarUrl,
    });

    if (success && mounted) {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: _pickedAvatar != null
                          ? FileImage(_pickedAvatar!) as ImageProvider
                          : (user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null),
                      child: (_pickedAvatar == null && user?.avatarUrl == null)
                          ? Text(
                              user != null && user.displayName.isNotEmpty
                                  ? user.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontSize: 28),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _isUploadingAvatar ? null : _pickAvatar,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: _isUploadingAvatar
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_avatarError != null) InlineErrorText(message: _avatarError!),
              const SizedBox(height: 24),
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLength: 160,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _websiteController,
                decoration: const InputDecoration(labelText: 'Website'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              Obx(() => InlineErrorText(message: _auth.errorMessage.value)),
              const SizedBox(height: 16),
              Obx(() => PrimaryButton(
                    label: 'Save',
                    isLoading: _auth.isLoading.value || _isUploadingAvatar,
                    onPressed: _submit,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}