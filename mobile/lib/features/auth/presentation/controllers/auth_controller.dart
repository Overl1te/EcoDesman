import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/network/error_message.dart";
import "../../data/repositories/auth_repository_impl.dart";
import "../../domain/models/app_user.dart";
import "../../domain/models/social_auth_provider.dart";

enum AuthStatus { unknown, authenticated, guest, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.isBusy = false,
    this.errorMessage,
  });

  factory AuthState.unknown() {
    return const AuthState(status: AuthStatus.unknown, isBusy: true);
  }

  factory AuthState.authenticated(AppUser user) {
    return AuthState(status: AuthStatus.authenticated, user: user);
  }

  factory AuthState.guest() {
    return const AuthState(status: AuthStatus.guest);
  }

  factory AuthState.unauthenticated({String? errorMessage}) {
    return AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: errorMessage,
    );
  }

  final AuthStatus status;
  final AppUser? user;
  final bool isBusy;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  bool _bootstrapStarted = false;

  @override
  AuthState build() {
    return AuthState.unknown();
  }

  Future<void> bootstrap() async {
    if (_bootstrapStarted) {
      return;
    }
    _bootstrapStarted = true;

    try {
      final session = await ref.read(authRepositoryProvider).restoreSession();
      if (session == null) {
        state = AuthState.unauthenticated();
        return;
      }

      state = AuthState.authenticated(session.user);
    } catch (_) {
      state = AuthState.unauthenticated();
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(identifier: identifier, password: password);
      state = AuthState.authenticated(session.user);
    } catch (error) {
      state = AuthState.unauthenticated(
        errorMessage: humanizeNetworkError(
          error,
          fallback: "Не удалось выполнить вход",
        ),
      );
    }
  }

  Future<void> register({
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
    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .register(
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
      state = AuthState.authenticated(session.user);
    } catch (error) {
      state = AuthState.unauthenticated(
        errorMessage: humanizeNetworkError(
          error,
          fallback: "Не удалось создать аккаунт",
        ),
      );
    }
  }

  Future<String> requestPasswordReset({required String identifier}) {
    return ref
        .read(authRepositoryProvider)
        .requestPasswordReset(identifier: identifier);
  }

  Future<List<SocialAuthProvider>> fetchSocialProviders({
    required String redirectUri,
    required String state,
  }) {
    return ref
        .read(authRepositoryProvider)
        .fetchSocialProviders(redirectUri: redirectUri, state: state);
  }

  Future<void> loginWithSocial({
    required String provider,
    required String code,
    required String redirectUri,
    required bool acceptTerms,
    required bool acceptPrivacyPolicy,
    required bool acceptPersonalData,
    required bool acceptPublicPersonalDataDistribution,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .loginWithSocial(
            provider: provider,
            code: code,
            redirectUri: redirectUri,
            acceptTerms: acceptTerms,
            acceptPrivacyPolicy: acceptPrivacyPolicy,
            acceptPersonalData: acceptPersonalData,
            acceptPublicPersonalDataDistribution:
                acceptPublicPersonalDataDistribution,
          );
      state = AuthState.authenticated(session.user);
    } catch (error) {
      state = AuthState.unauthenticated(
        errorMessage: humanizeNetworkError(
          error,
          fallback: "Не удалось выполнить вход через внешний сервис",
        ),
      );
    }
  }

  void continueAsGuest() {
    state = AuthState.guest();
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }
    state = state.copyWith(clearError: true);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = AuthState.unauthenticated();
  }

  Future<bool> updateProfile({
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
    if (!state.isAuthenticated) {
      return false;
    }

    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .updateProfile(
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
      state = AuthState.authenticated(user);
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: humanizeNetworkError(
          error,
          fallback: "Не удалось сохранить профиль",
        ),
      );
      return false;
    }
  }

  Future<bool> updateAvatar({required String avatarUrl}) async {
    if (!state.isAuthenticated) {
      return false;
    }

    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .updateAvatar(avatarUrl: avatarUrl);
      state = AuthState.authenticated(user);
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: humanizeNetworkError(
          error,
          fallback: "Не удалось обновить фото профиля",
        ),
      );
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    if (!state.isAuthenticated) {
      return false;
    }

    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
            newPasswordConfirmation: newPasswordConfirmation,
          );
      state = AuthState.authenticated(user);
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: humanizeNetworkError(
          error,
          fallback: "Не удалось изменить пароль",
        ),
      );
      return false;
    }
  }
}
