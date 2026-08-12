import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/network/api_client.dart";
import "../../domain/models/app_user.dart";
import "../../domain/models/auth_session.dart";
import "../../domain/models/auth_tokens.dart";
import "../../domain/models/social_auth_provider.dart";

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider));
});

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  AuthSession _parseSession(Response<dynamic> response) {
    final data = Map<String, dynamic>.from(response.data as Map);
    return AuthSession(
      user: AppUser.fromJson(Map<String, dynamic>.from(data["user"] as Map)),
      tokens: AuthTokens(
        accessToken: data["access"] as String,
        refreshToken: data["refresh"] as String,
      ),
    );
  }

  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _dio.post(
      "/auth/login",
      data: {"identifier": identifier, "password": password},
      options: Options(extra: const {"skipAuth": true}),
    );
    return _parseSession(response);
  }

  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirmation,
    required bool acceptTerms,
    required bool acceptPrivacyPolicy,
    required bool acceptPersonalData,
    bool acceptPublicPersonalDataDistribution = false,
    required String displayName,
    required String phone,
  }) async {
    final response = await _dio.post(
      "/auth/register",
      data: {
        "username": username,
        "email": email,
        "display_name": displayName,
        "phone": phone,
        "password": password,
        "password_confirmation": passwordConfirmation,
        "accept_terms": acceptTerms,
        "accept_privacy_policy": acceptPrivacyPolicy,
        "accept_personal_data": acceptPersonalData,
        "accept_public_personal_data_distribution":
            acceptPublicPersonalDataDistribution,
      },
      options: Options(extra: const {"skipAuth": true}),
    );
    return _parseSession(response);
  }

  Future<List<SocialAuthProvider>> fetchSocialProviders({
    required String redirectUri,
    required String state,
  }) async {
    final response = await _dio.get(
      "/auth/social/providers",
      queryParameters: {"redirect_uri": redirectUri, "state": state},
      options: Options(extra: const {"skipAuth": true}),
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data["providers"] as List<dynamic>? ?? const [])
        .map(
          (item) => SocialAuthProvider.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<AuthSession> loginWithSocial({
    required String provider,
    required String code,
    required String redirectUri,
    required bool acceptTerms,
    required bool acceptPrivacyPolicy,
    required bool acceptPersonalData,
    required bool acceptPublicPersonalDataDistribution,
  }) async {
    final response = await _dio.post(
      "/auth/social/$provider",
      data: {
        "code": code,
        "redirect_uri": redirectUri,
        "accept_terms": acceptTerms,
        "accept_privacy_policy": acceptPrivacyPolicy,
        "accept_personal_data": acceptPersonalData,
        "accept_public_personal_data_distribution":
            acceptPublicPersonalDataDistribution,
      },
      options: Options(extra: const {"skipAuth": true}),
    );
    return _parseSession(response);
  }

  Future<String> requestPasswordReset({required String identifier}) async {
    final response = await _dio.post(
      "/auth/password-reset/request",
      data: {"identifier": identifier},
      options: Options(extra: const {"skipAuth": true}),
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return data["detail"] as String? ??
        "Запрос принят. Когда подключим письмо или SMS, инструкция будет приходить сюда.";
  }

  Future<void> logout({required String refreshToken}) async {
    await _dio.post(
      "/auth/logout",
      data: {"refresh": refreshToken},
      options: Options(extra: const {"skipAuth": true}),
    );
  }

  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final response = await _dio.post(
      "/auth/change-password",
      data: {
        "current_password": currentPassword,
        "new_password": newPassword,
        "new_password_confirmation": newPasswordConfirmation,
      },
    );
    return _parseSession(response);
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    final response = await _dio.post(
      "/auth/refresh",
      data: {"refresh": refreshToken},
      options: Options(extra: const {"skipAuth": true}),
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    return AuthTokens(
      accessToken: data["access"] as String,
      refreshToken: data["refresh"] as String? ?? refreshToken,
    );
  }

  Future<AppUser> me() async {
    final response = await _dio.get("/auth/me");
    return AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

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
  }) async {
    final response = await _dio.patch(
      "/auth/me",
      data: {
        "username": username,
        "email": email,
        "display_name": displayName,
        "avatar_url": avatarUrl,
        "status_text": statusText,
        "bio": bio,
        "city": city,
        "telegram_url": telegramUrl,
        "vk_url": vkUrl,
        "instagram_url": instagramUrl,
      },
    );
    return AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<AppUser> updateAvatar({required String avatarUrl}) async {
    final response = await _dio.patch(
      "/auth/me",
      data: {"avatar_url": avatarUrl},
    );
    return AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<AppUser> fetchPublicProfile(int userId) async {
    final response = await _dio.get("/profiles/$userId");
    return AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<AppUser> fetchPublicProfileByUsername(String username) async {
    final response = await _dio.get("/profiles/by-username/$username");
    return AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<AppUser>> searchUsers(String query) async {
    final response = await _dio.get(
      "/users",
      queryParameters: {"search": query},
      options: Options(extra: const {"skipAuth": true}),
    );
    return (response.data as List<dynamic>? ?? [])
        .map((item) => AppUser.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<AppUser> warnUser(int userId) async {
    final response = await _dio.post("/users/$userId/warn");
    return AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<AppUser> banUser(int userId) async {
    final response = await _dio.post("/users/$userId/ban");
    return AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<AppUser> unbanUser(int userId) async {
    final response = await _dio.post("/users/$userId/unban");
    return AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<AppUser> updateUserRole({
    required int userId,
    required String role,
  }) async {
    final response = await _dio.patch(
      "/users/$userId/role",
      data: {"role": role},
    );
    return AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
