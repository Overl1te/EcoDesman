import "../models/app_user.dart";
import "../models/auth_session.dart";
import "../models/social_auth_provider.dart";

abstract class AuthRepository {
  Future<AuthSession?> restoreSession();

  Future<AuthSession> login({
    required String identifier,
    required String password,
  });

  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirmation,
    required bool acceptTerms,
    required bool acceptPrivacyPolicy,
    required bool acceptPersonalData,
    bool acceptPublicPersonalDataDistribution = false,
    String displayName = "",
    String phone = "",
  });

  Future<List<SocialAuthProvider>> fetchSocialProviders({
    required String redirectUri,
    required String state,
  });

  Future<AuthSession> loginWithSocial({
    required String provider,
    required String code,
    required String redirectUri,
    required bool acceptTerms,
    required bool acceptPrivacyPolicy,
    required bool acceptPersonalData,
    required bool acceptPublicPersonalDataDistribution,
  });

  Future<String> requestPasswordReset({required String identifier});

  Future<AppUser> fetchCurrentUser();

  Future<AppUser> fetchPublicProfile(int userId);

  Future<AppUser> fetchPublicProfileByUsername(String username);

  Future<List<AppUser>> searchUsers(String query);

  Future<AppUser> warnUser(int userId);

  Future<AppUser> banUser(int userId);

  Future<AppUser> unbanUser(int userId);

  Future<AppUser> updateUserRole({required int userId, required String role});

  Future<AppUser> updateProfile({
    required String username,
    required String email,
    required String displayName,
    required String avatarUrl,
    required String statusText,
    required String bio,
    required String city,
    required String telegramUrl,
    required String vkUrl,
    required String instagramUrl,
  });

  Future<AppUser> updateAvatar({required String avatarUrl});

  Future<AppUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  });

  Future<void> logout();
}
