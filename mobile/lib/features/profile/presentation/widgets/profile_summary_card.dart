import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../../shared/widgets/remote_avatar.dart";
import "../../../../shared/widgets/role_chip.dart";
import "../../../auth/domain/models/app_user.dart";

class ProfileSummaryCard extends StatelessWidget {
  const ProfileSummaryCard({
    super.key,
    required this.user,
    this.showPrivateFields = false,
    this.actions = const [],
  });

  final AppUser user;
  final bool showPrivateFields;
  final List<Widget> actions;

  List<_SocialLinkData> get _socialLinks => [
    if (user.websiteUrl.isNotEmpty)
      _SocialLinkData(
        icon: Icons.language_outlined,
        label: "Сайт",
        url: user.websiteUrl,
      ),
    if (user.telegramUrl.isNotEmpty)
      _SocialLinkData(
        icon: Icons.send_outlined,
        label: "Telegram",
        url: user.telegramUrl,
      ),
    if (user.vkUrl.isNotEmpty)
      _SocialLinkData(
        icon: Icons.groups_outlined,
        label: "VK",
        url: user.vkUrl,
      ),
    if (user.instagramUrl.isNotEmpty)
      _SocialLinkData(
        icon: Icons.camera_alt_outlined,
        label: "Instagram",
        url: user.instagramUrl,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RemoteAvatar(
                  imageUrl: user.avatarUrl,
                  fallbackLabel: user.displayName,
                  radius: 36,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (user.username.isNotEmpty)
                            Text(
                              "@${user.username}",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          RoleChip(role: user.role),
                          if (user.warningCount > 0)
                            Chip(
                              label: Text(
                                "Предупреждения: ${user.warningCount}",
                              ),
                              visualDensity: VisualDensity.compact,
                              backgroundColor:
                                  theme.colorScheme.tertiaryContainer,
                            ),
                          if (user.isBanned)
                            Chip(
                              label: const Text("Заблокирован"),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: theme.colorScheme.errorContainer,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (user.statusText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                user.statusText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (user.bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                user.bio,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
            ],
            if (user.city.isNotEmpty ||
                (showPrivateFields && user.email.isNotEmpty)) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (user.city.isNotEmpty)
                    _MetaLabel(
                      icon: Icons.location_on_outlined,
                      text: user.city,
                    ),
                  if (showPrivateFields && user.email.isNotEmpty)
                    _MetaLabel(icon: Icons.mail_outline, text: user.email),
                  if (showPrivateFields && (user.phone ?? "").isNotEmpty)
                    _MetaLabel(icon: Icons.call_outlined, text: user.phone!),
                ],
              ),
            ],
            if (_socialLinks.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final link in _socialLinks)
                    _SocialLinkChip(
                      icon: link.icon,
                      label: link.label,
                      url: link.url,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(label: "Посты", value: user.stats.postsCount),
                _StatCard(label: "Лайки", value: user.stats.likesReceivedCount),
                _StatCard(
                  label: "Комментарии",
                  value: user.stats.commentsCount,
                ),
                _StatCard(
                  label: "Просмотры",
                  value: user.stats.viewsReceivedCount,
                ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(spacing: 12, runSpacing: 12, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$value",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialLinkData {
  const _SocialLinkData({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;
}

class _SocialLinkChip extends StatelessWidget {
  const _SocialLinkChip({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;

  void _openLink() {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: _openLink,
    );
  }
}
