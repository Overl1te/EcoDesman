import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../features/auth/presentation/controllers/auth_controller.dart";
import "../features/events/presentation/screens/events_placeholder_screen.dart";
import "../features/feed/presentation/screens/feed_screen.dart";
import "../features/map/presentation/screens/map_placeholder_screen.dart";
import "../features/notifications/presentation/controllers/notifications_controller.dart";
import "../features/profile/presentation/screens/profile_screen.dart";

class AppShellPage extends ConsumerStatefulWidget {
  const AppShellPage({super.key});

  @override
  ConsumerState<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends ConsumerState<AppShellPage> {
  int _currentIndex = 0;

  static const _titles = ["Лента", "Мероприятия", "Карта", "Профиль"];

  static const _nonMapPages = [
    FeedScreen(),
    EventsPlaceholderScreen(),
    ProfileScreen(),
  ];

  void _handleDestinationSelected(int index) {
    if (_currentIndex == index) {
      return;
    }

    if (_currentIndex == 2 && index != 2) {
      Navigator.of(context).popUntil((route) => route is! PopupRoute);
    }

    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildBody(bool isMapTab) {
    if (isMapTab) {
      return const MapPlaceholderScreen();
    }

    final nonMapIndex = _currentIndex == 3 ? 2 : _currentIndex;
    return SafeArea(
      child: IndexedStack(index: nonMapIndex, children: _nonMapPages),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final notificationsState = ref.watch(notificationsControllerProvider);
    final isMapTab = _currentIndex == 2;

    ref.read(notificationsControllerProvider.notifier).syncAuth(authState);

    return Scaffold(
      appBar: isMapTab
          ? null
          : AppBar(
              title: Text(_titles[_currentIndex]),
              actions: [
                if (_currentIndex == 0)
                  IconButton(
                    onPressed: () => context.push("/search"),
                    icon: const Icon(Icons.search),
                    tooltip: "Поиск",
                  ),
                if (authState.isAuthenticated)
                  IconButton(
                    onPressed: () => context.push("/notifications"),
                    tooltip: "Уведомления",
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none),
                        if (notificationsState.unreadCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                notificationsState.unreadCount > 9
                                    ? "9+"
                                    : "${notificationsState.unreadCount}",
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onError,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_currentIndex == 3 && authState.isAuthenticated)
                  if (authState.user?.canAccessAdmin ?? false)
                    IconButton(
                      onPressed: () => context.push("/admin"),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      tooltip: "Админка",
                    ),
                if (_currentIndex == 3 && authState.isAuthenticated)
                  IconButton(
                    onPressed: () => context.push("/settings/profile"),
                    icon: const Icon(Icons.tune),
                    tooltip: "Настройки профиля",
                  ),
              ],
            ),
      body: _buildBody(isMapTab),
      floatingActionButton: authState.isAuthenticated && !isMapTab
          ? FloatingActionButton.extended(
              onPressed: () => context.push("/posts/new"),
              icon: const Icon(Icons.edit_square),
              label: const Text("Новый пост"),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _handleDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: "Лента",
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: "События",
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: "Карта",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "Профиль",
          ),
        ],
      ),
    );
  }
}
