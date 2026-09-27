import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_checker.dart';

class UpdateNotice extends StatefulWidget {
  const UpdateNotice({required this.child, super.key});

  final Widget child;

  @override
  State<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends State<UpdateNotice> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final update = await UpdateChecker().check();
    if (!mounted || update == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Доступно обновление'),
        content: Text(
          'Вышла новая версия ${update.version}+${update.build}. '
          'Обновите приложение, чтобы получить исправления и новые функции.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Позже'),
          ),
          FilledButton(
            onPressed: () async {
              final uri = Uri.tryParse(update.releaseUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Скачать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
