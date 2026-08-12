import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../features/admin/presentation/screens/admin_screen.dart";
import "../../features/auth/presentation/screens/login_screen.dart";
import "../../features/auth/presentation/screens/splash_screen.dart";
import "../../features/favorites/presentation/screens/favorites_screen.dart";
import "../../features/feed/presentation/screens/post_editor_screen.dart";
import "../../features/feed/presentation/screens/post_detail_screen.dart";
import "../../features/notifications/presentation/screens/notifications_screen.dart";
import "../../features/profile/presentation/screens/profile_settings_screen.dart";
import "../../features/profile/presentation/screens/public_profile_screen.dart";
import "../../features/search/presentation/screens/search_screen.dart";
import "../../features/support/presentation/screens/help_info_screen.dart";
import "../../features/support/presentation/screens/support_center_screen.dart";
import "../../features/support/presentation/screens/support_thread_screen.dart";
import "../app_shell_page.dart";

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/splash",
    routes: [
      GoRoute(
        path: "/splash",
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: "/login", builder: (context, state) => const LoginScreen()),
      GoRoute(path: "/app", builder: (context, state) => const AppShellPage()),
      GoRoute(
        path: "/favorites",
        builder: (context, state) => const FavoritesPage(),
      ),
      GoRoute(
        path: "/posts/new",
        builder: (context, state) => const PostEditorScreen(),
      ),
      GoRoute(
        path: "/posts/:postId",
        builder: (context, state) {
          final postId = int.parse(state.pathParameters["postId"]!);
          return PostDetailScreen.byId(postId: postId);
        },
      ),
      GoRoute(
        path: "/posts/:postId/edit",
        builder: (context, state) {
          final postId = int.parse(state.pathParameters["postId"]!);
          return PostEditorScreen(postId: postId);
        },
      ),
      GoRoute(
        path: "/profiles/:userId",
        builder: (context, state) {
          final userId = int.parse(state.pathParameters["userId"]!);
          return PublicProfileScreen.byId(userId: userId);
        },
      ),
      GoRoute(
        path: "/settings/profile",
        builder: (context, state) => const ProfileSettingsScreen(),
      ),
      GoRoute(
        path: "/search",
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: "/notifications",
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: "/profile/help",
        builder: (context, state) => const HelpInfoScreen(),
      ),
      GoRoute(
        path: "/profile/support",
        builder: (context, state) => const SupportCenterScreen(),
      ),
      GoRoute(
        path: "/profile/support/requests",
        builder: (context, state) => const SupportRequestsScreen(),
      ),
      GoRoute(
        path: "/profile/support/thread/:threadId",
        builder: (context, state) {
          final threadId = int.parse(state.pathParameters["threadId"]!);
          return SupportThreadScreen(threadId: threadId);
        },
      ),
      GoRoute(path: "/admin", builder: (context, state) => const AdminScreen()),
      GoRoute(
        path: "/:username/posts/:postSlug",
        builder: (context, state) {
          final username = state.pathParameters["username"]!;
          final postSlug = state.pathParameters["postSlug"]!;
          return PostDetailScreen.bySlug(
            authorUsername: username,
            postSlug: postSlug,
          );
        },
      ),
      GoRoute(
        path: "/:username",
        builder: (context, state) {
          final username = state.pathParameters["username"]!;
          return PublicProfileScreen.byUsername(username: username);
        },
      ),
    ],
  );
});
