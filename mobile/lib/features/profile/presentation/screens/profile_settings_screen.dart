import "dart:io";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:image_cropper/image_cropper.dart";

import "../../../../core/network/image_upload_service.dart";
import "../../../../core/routing/app_routes.dart";
import "../../../../core/theme/theme_mode_controller.dart";
import "../../../../shared/widgets/remote_avatar.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../feed/presentation/controllers/feed_controller.dart";
import "../controllers/profile_controller.dart";

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _statusController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  final _telegramController = TextEditingController();
  final _vkController = TextEditingController();
  final _instagramController = TextEditingController();
  bool _initialized = false;
  bool _isUploadingAvatar = false;
  String _avatarUrl = "";
  String? _avatarCacheBuster;
  String? _avatarErrorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _statusController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _telegramController.dispose();
    _vkController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  void _initFromState(AuthState authState) {
    if (_initialized || authState.user == null) {
      return;
    }

    final user = authState.user!;
    _usernameController.text = user.username;
    _emailController.text = user.email;
    _nameController.text = user.name;
    _avatarUrl = user.avatarUrl;
    _avatarCacheBuster = user.avatarUrl.isEmpty
        ? null
        : DateTime.now().millisecondsSinceEpoch.toString();
    _statusController.text = user.statusText;
    _cityController.text = user.city;
    _bioController.text = user.bio;
    _telegramController.text = user.telegramUrl;
    _vkController.text = user.vkUrl;
    _instagramController.text = user.instagramUrl;
    _initialized = true;
  }

  String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return "";
    }
    if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
      return trimmed;
    }
    return "https://$trimmed";
  }

  void _invalidateProfileData({
    required int userId,
    Iterable<String> usernames = const [],
  }) {
    for (final lookup in AppRoutes.profileLookups(userId: userId)) {
      ref.invalidate(publicProfileProvider(lookup));
    }
    for (final username in usernames) {
      final normalizedUsername = username.trim();
      if (normalizedUsername.isEmpty) {
        continue;
      }
      ref.invalidate(
        publicProfileProvider(
          ProfileRouteTarget.byUsername(normalizedUsername),
        ),
      );
    }
    ref.invalidate(userPostsProvider(userId));
    ref.invalidate(feedControllerProvider);
    ref.invalidate(postsCollectionControllerProvider(favoritePostsQuery));
    ref.invalidate(postsCollectionControllerProvider(defaultEventsQuery));
  }

  Future<bool> _applyAvatarChange(String avatarUrl) async {
    final authNotifier = ref.read(authControllerProvider.notifier);
    final success = await authNotifier.updateAvatar(avatarUrl: avatarUrl);
    final updatedUser = ref.read(authControllerProvider).user;

    if (!mounted) {
      return success;
    }

    if (success && updatedUser != null) {
      _invalidateProfileData(
        userId: updatedUser.id,
        usernames: [updatedUser.username],
      );
      setState(() {
        _avatarUrl = updatedUser.avatarUrl;
        _avatarCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
        _avatarErrorMessage = null;
      });
      return true;
    }

    setState(() {
      _avatarErrorMessage =
          ref.read(authControllerProvider).errorMessage ??
          "Не удалось обновить фото профиля";
    });
    return false;
  }

  // ignore: unused_element
  Future<void> _pickAndUploadAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        if (mounted) {
          setState(() {
            _avatarErrorMessage = "Не удалось получить файл изображения";
          });
        }
        return;
      }

      final croppedPath = await _cropAvatar(path);
      if (croppedPath == null || croppedPath.isEmpty) {
        return;
      }

      setState(() {
        _isUploadingAvatar = true;
        _avatarErrorMessage = null;
      });

      final url = await ref
          .read(imageUploadServiceProvider)
          .uploadImage(croppedPath, fileName: "profile-avatar.png");
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarUrl = url;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarErrorMessage = "Не удалось загрузить фото профиля";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<String?> _cropAvatar(String sourcePath) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return sourcePath;
    }

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.png,
      compressQuality: 95,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: "Обрезать аватар",
          toolbarColor: Theme.of(context).colorScheme.surface,
          toolbarWidgetColor: Theme.of(context).colorScheme.onSurface,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: "Обрезать аватар",
          aspectRatioLockEnabled: true,
          aspectRatioPickerButtonHidden: true,
          resetAspectRatioEnabled: false,
          rotateButtonsHidden: false,
          cropStyle: CropStyle.circle,
        ),
      ],
    );

    return croppedFile?.path;
  }

  // ignore: unused_element
  void _removeAvatar() {
    setState(() {
      _avatarUrl = "";
      _avatarErrorMessage = null;
    });
  }

  Future<void> _pickAndUploadAvatarAndSave() async {
    final previousAvatarUrl = _avatarUrl;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        if (mounted) {
          setState(() {
            _avatarErrorMessage = "Не удалось получить файл изображения";
          });
        }
        return;
      }

      final croppedPath = await _cropAvatar(path);
      if (croppedPath == null || croppedPath.isEmpty) {
        return;
      }

      setState(() {
        _isUploadingAvatar = true;
        _avatarErrorMessage = null;
      });

      final url = await ref
          .read(imageUploadServiceProvider)
          .uploadImage(croppedPath, fileName: "profile-avatar.png");
      final success = await _applyAvatarChange(url);

      if (!mounted) {
        return;
      }

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Фото профиля обновлено")));
      } else {
        setState(() {
          _avatarUrl = previousAvatarUrl;
          _avatarCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _avatarErrorMessage = "Не удалось загрузить фото профиля";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _removeAvatarAndSave() async {
    final previousAvatarUrl = _avatarUrl;

    setState(() {
      _isUploadingAvatar = true;
      _avatarErrorMessage = null;
    });

    final success = await _applyAvatarChange("");

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Фото профиля удалено")));
    } else {
      setState(() {
        _avatarUrl = previousAvatarUrl;
        _avatarCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      });
    }

    setState(() {
      _isUploadingAvatar = false;
    });
  }

  Future<void> _showChangePasswordDialog() async {
    ref.read(authControllerProvider.notifier).clearError();
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final newPasswordConfirmationController = TextEditingController();
    var obscureCurrentPassword = true;
    var obscureNewPassword = true;
    var obscureNewPasswordConfirmation = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final authState = ref.watch(authControllerProvider);

            Future<void> submit() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              final success = await ref
                  .read(authControllerProvider.notifier)
                  .changePassword(
                    currentPassword: currentPasswordController.text,
                    newPassword: newPasswordController.text,
                    newPasswordConfirmation:
                        newPasswordConfirmationController.text,
                  );

              if (success && mounted && dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Пароль обновлен. Сессия защищенно перевыпущена.",
                    ),
                  ),
                );
              }
            }

            InputDecoration passwordDecoration({
              required String label,
              required bool obscureText,
              required VoidCallback onToggle,
            }) {
              return InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: onToggle,
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              );
            }

            return AlertDialog(
              title: const Text("Сменить пароль"),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrentPassword,
                        decoration: passwordDecoration(
                          label: "Текущий пароль",
                          obscureText: obscureCurrentPassword,
                          onToggle: () {
                            setDialogState(() {
                              obscureCurrentPassword = !obscureCurrentPassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Введите текущий пароль";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNewPassword,
                        decoration: passwordDecoration(
                          label: "Новый пароль",
                          obscureText: obscureNewPassword,
                          onToggle: () {
                            setDialogState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Введите новый пароль";
                          }
                          if (value.length < 8) {
                            return "Пароль должен быть не короче 8 символов";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordConfirmationController,
                        obscureText: obscureNewPasswordConfirmation,
                        decoration: passwordDecoration(
                          label: "Повторите новый пароль",
                          obscureText: obscureNewPasswordConfirmation,
                          onToggle: () {
                            setDialogState(() {
                              obscureNewPasswordConfirmation =
                                  !obscureNewPasswordConfirmation;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Повторите новый пароль";
                          }
                          if (value != newPasswordController.text) {
                            return "Пароли не совпадают";
                          }
                          return null;
                        },
                      ),
                      if (authState.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          authState.errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: authState.isBusy
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text("Отмена"),
                ),
                FilledButton(
                  onPressed: authState.isBusy ? null : submit,
                  child: authState.isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Сохранить"),
                ),
              ],
            );
          },
        );
      },
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    newPasswordConfirmationController.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currentUser = ref.read(authControllerProvider).user;
    final success = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          displayName: _nameController.text.trim(),
          avatarUrl: _avatarUrl.trim(),
          statusText: _statusController.text.trim(),
          bio: _bioController.text.trim(),
          city: _cityController.text.trim(),
          telegramUrl: _normalizeUrl(_telegramController.text),
          vkUrl: _normalizeUrl(_vkController.text),
          instagramUrl: _normalizeUrl(_instagramController.text),
        );

    if (!mounted) {
      return;
    }

    if (success) {
      final updatedUser = ref.read(authControllerProvider).user;
      if (currentUser != null) {
        _invalidateProfileData(
          userId: currentUser.id,
          usernames: [
            currentUser.username,
            if (updatedUser != null) updatedUser.username,
          ],
        );
      }
      context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Профиль обновлен")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final theme = Theme.of(context);
    _initFromState(authState);

    if (!authState.isAuthenticated || authState.user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Настройки профиля")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Для редактирования профиля нужно войти в аккаунт.",
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go("/login"),
                  child: const Text("Перейти ко входу"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Настройки профиля")),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _AvatarEditorCard(
                avatarUrl: _avatarUrl,
                avatarCacheBuster: _avatarCacheBuster,
                fallbackLabel: _nameController.text,
                isUploading: _isUploadingAvatar,
                errorMessage: _avatarErrorMessage,
                onUpload: () => _pickAndUploadAvatarAndSave(),
                onRemove: _avatarUrl.isEmpty
                    ? null
                    : () => _removeAvatarAndSave(),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: "Логин",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? "";
                  if (normalized.isEmpty) {
                    return "Введите username";
                  }
                  if (normalized.length < 3) {
                    return "Username должен быть не короче 3 символов";
                  }
                  if (normalized.contains(" ")) {
                    return "Username не должен содержать пробелы";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Электронная почта",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? "";
                  if (normalized.isEmpty) {
                    return "Введите email";
                  }
                  if (!normalized.contains("@")) {
                    return "Введите корректный email";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: "Имя",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _statusController,
                decoration: const InputDecoration(
                  labelText: "Статус",
                  border: OutlineInputBorder(),
                ),
                maxLength: 120,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: "Город",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: "О себе",
                  border: OutlineInputBorder(),
                ),
                minLines: 4,
                maxLines: 6,
              ),
              const SizedBox(height: 20),
              _SecuritySettingsCard(
                email: _emailController.text.trim(),
                onChangePassword: _showChangePasswordDialog,
              ),
              const SizedBox(height: 20),
              _ThemeModeSection(
                selectedMode: themeMode,
                onChanged: (mode) {
                  ref
                      .read(themeModeControllerProvider.notifier)
                      .setThemeMode(mode);
                },
              ),
              const SizedBox(height: 20),
              Text(
                "Соцсети",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telegramController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: "Телеграм",
                  hintText: "https://t.me/username",
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vkController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: "ВКонтакте",
                  hintText: "https://vk.com/username",
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _instagramController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: "Инстаграм",
                  hintText: "https://instagram.com/username",
                ),
              ),
              if (authState.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  authState.errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: authState.isBusy ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: authState.isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Сохранить"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModeSection extends StatelessWidget {
  const _ThemeModeSection({
    required this.selectedMode,
    required this.onChanged,
  });

  final ThemeMode selectedMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Тема оформления",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Можно оставить как у системы или зафиксировать светлую либо тёмную тему.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<ThemeMode>(
            multiSelectionEnabled: false,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text("Системная"),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text("Светлая"),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text("Тёмная"),
              ),
            ],
            selected: {selectedMode},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                onChanged(selection.first);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SecuritySettingsCard extends StatelessWidget {
  const _SecuritySettingsCard({
    required this.email,
    required this.onChangePassword,
  });

  final String email;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Безопасность",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            email.isEmpty
                ? "Основной аккаунт обновляется здесь же, пароль можно сменить отдельно."
                : "Текущий email для входа: $email",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onChangePassword,
            icon: const Icon(Icons.lock_outline_rounded),
            label: const Text("Сменить пароль"),
          ),
        ],
      ),
    );
  }
}

class _AvatarEditorCard extends StatelessWidget {
  const _AvatarEditorCard({
    required this.avatarUrl,
    required this.avatarCacheBuster,
    required this.fallbackLabel,
    required this.isUploading,
    required this.errorMessage,
    required this.onUpload,
    required this.onRemove,
  });

  final String avatarUrl;
  final String? avatarCacheBuster;
  final String fallbackLabel;
  final bool isUploading;
  final String? errorMessage;
  final VoidCallback onUpload;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.18),
                      theme.colorScheme.tertiary.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: RemoteAvatar(
                  imageUrl: avatarUrl,
                  cacheBuster: avatarCacheBuster,
                  fallbackLabel: fallbackLabel,
                  radius: 54,
                ),
              ),
              if (isUploading)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              Positioned(
                right: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: isUploading ? null : onUpload,
                    icon: const Icon(Icons.photo_camera_outlined),
                    color: theme.colorScheme.onPrimary,
                    tooltip: "Сменить фото",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Фото профиля",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Аватар вручную обрезается по кругу и будет виден в профиле, ленте и комментариях.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: isUploading ? null : onUpload,
                icon: const Icon(Icons.upload_outlined),
                label: Text(
                  avatarUrl.isEmpty ? "Загрузить фото" : "Сменить фото",
                ),
              ),
              if (onRemove != null)
                OutlinedButton.icon(
                  onPressed: isUploading ? null : onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text("Убрать фото"),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Поддерживаются JPG, PNG и WEBP.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
