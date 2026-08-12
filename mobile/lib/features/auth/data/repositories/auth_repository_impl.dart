import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/storage/token_storage.dart";
import "../../domain/models/app_user.dart";
import "../../domain/models/auth_session.dart";
import "../../domain/models/auth_tokens.dart";
import "../../domain/models/social_auth_provider.dart";
import "../../domain/repositories/auth_repository.dart";
import "../datasources/auth_remote_data_source.dart";

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required TokenStorage tokenStorage,
  }) : _remoteDataSource = remoteDataSource,
       _tokenStorage = tokenStorage;

  final AuthRemoteDataSource _remoteDataSource;
  final TokenStorage _tokenStorage;

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final session = await _remoteDataSource.login(
      identifier: identifier,
      password: password,
    );
    await _persistTokens(session.tokens);
    return session;
  }

  @override
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
  }) async {
    final session = await _remoteDataSource.register(
      username: username,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      acceptTerms: acceptTerms,
      acceptPrivacyPolicy: acceptPrivacyPolicy,
      acceptPersonalData: acceptPersonalData,
      acceptPublicPersonalDataDistribution:
          acceptPublicPersonalDataDistribution,
      displayName: displayName,
      phone: phone,
    );
    await _persistTokens(session.tokens);
    return session;
  }

  @override
  Future<List<SocialAuthProvider>> fetchSocialProviders({
    required String redirectUri,
    required String state,
  }) {
    return _remoteDataSource.fetchSocialProviders(
      redirectUri: redirectUri,
      state: state,
    );
  }

  @override
  Future<AuthSession> loginWithSocial({
    required String provider,
    required String code,
    required String redirectUri,
    required bool acceptTerms,
    required bool acceptPrivacyPolicy,
    required bool acceptPersonalData,
    required bool acceptPublicPersonalDataDistribution,
  }) async {
    final session = await _remoteDataSource.loginWithSocial(
      provider: provider,
      code: code,
      redirectUri: redirectUri,
      acceptTerms: acceptTerms,
      acceptPrivacyPolicy: acceptPrivacyPolicy,
      acceptPersonalData: acceptPersonalData,
      acceptPublicPersonalDataDistribution:
          acceptPublicPersonalDataDistribution,
    );
    await _persistTokens(session.tokens);
    return session;
  }

  @override
  Future<String> requestPasswordReset({required String identifier}) {
    return _remoteDataSource.requestPasswordReset(identifier: identifier);
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _remoteDataSource.logout(refreshToken: refreshToken);
      } on DioException {
        // Local logout should still succeed even if the server session is gone.
      }
    }
    await _tokenStorage.clear();
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final accessToken = await _tokenStorage.readAccessToken();
    final refreshToken = await _tokenStorage.readRefreshToken();

    if (accessToken == null || refreshToken == null) {
      return null;
    }

    try {
      final user = await fetchCurrentUser();
      return AuthSession(
        user: user,
        tokens: AuthTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        ),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        await _tokenStorage.clear();
        rethrow;
      }

      try {
        final refreshedTokens = await _remoteDataSource.refresh(refreshToken);
        await _persistTokens(refreshedTokens);
        final user = await fetchCurrentUser();
        return AuthSession(user: user, tokens: refreshedTokens);
      } catch (_) {
        await _tokenStorage.clear();
        return null;
      }
    }
  }

  @override
  Future<AppUser> fetchCurrentUser() {
    return _remoteDataSource.me();
  }

  @override
  Future<AppUser> fetchPublicProfile(int userId) {
    return _remoteDataSource.fetchPublicProfile(userId);
  }

  @override
  Future<AppUser> fetchPublicProfileByUsername(String username) {
    return _remoteDataSource.fetchPublicProfileByUsername(username);
  }

  @override
  Future<List<AppUser>> searchUsers(String query) {
    return _remoteDataSource.searchUsers(query);
  }

  @override
  Future<AppUser> warnUser(int userId) {
    return _remoteDataSource.warnUser(userId);
  }

  @override
  Future<AppUser> banUser(int userId) {
    return _remoteDataSource.banUser(userId);
  }

  @override
  Future<AppUser> unbanUser(int userId) {
    return _remoteDataSource.unbanUser(userId);
  }

  @override
  Future<AppUser> updateUserRole({required int userId, required String role}) {
    return _remoteDataSource.updateUserRole(userId: userId, role: role);
  }

  @override
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
  }) {
    return _remoteDataSource.updateProfile(
      username: username,
      email: email,
      displayName: displayName,
      avatarUrl: avatarUrl,
      statusText: statusText,
      bio: bio,
      city: city,
      telegramUrl: telegramUrl,
      vkUrl: vkUrl,
      instagramUrl: instagramUrl,
    );
  }

  @override
  Future<AppUser> updateAvatar({required String avatarUrl}) {
    return _remoteDataSource.updateAvatar(avatarUrl: avatarUrl);
  }

  @override
  Future<AppUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final session = await _remoteDataSource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      newPasswordConfirmation: newPasswordConfirmation,
    );
    await _persistTokens(session.tokens);
    return session.user;
  }

  Future<void> _persistTokens(AuthTokens tokens) {
    return _tokenStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  }
}
