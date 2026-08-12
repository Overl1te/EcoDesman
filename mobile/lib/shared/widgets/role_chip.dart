import "package:flutter/material.dart";

class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Chip(
      label: Text(_label(role)),
      visualDensity: VisualDensity.compact,
      backgroundColor: switch (role) {
        "admin" => theme.colorScheme.errorContainer,
        "support" => theme.colorScheme.primaryContainer,
        "moderator" => theme.colorScheme.secondaryContainer,
        _ => theme.colorScheme.surfaceContainerHighest,
      },
      side: BorderSide.none,
    );
  }

  String _label(String role) {
    switch (role) {
      case "admin":
        return "Админ";
      case "support":
        return "Техподдержка";
      case "moderator":
        return "Модератор";
      default:
        return "Пользователь";
    }
  }
}
