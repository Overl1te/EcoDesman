import "app_user.dart";
import "auth_tokens.dart";

class AuthSession {
  const AuthSession({required this.user, required this.tokens});

  final AppUser user;
  final AuthTokens tokens;
}
