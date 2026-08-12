import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../config/app_config.dart";
import "../storage/token_storage.dart";

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final apiClientProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  final baseOptions = BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    headers: const {
      "Accept": "application/json",
      "Content-Type": "application/json",
    },
  );
  final refreshDio = Dio(baseOptions);

  final dio = Dio(baseOptions);

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.extra["skipAuth"] == true) {
          return handler.next(options);
        }

        final token = await tokenStorage.readAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $token";
        }

        handler.next(options);
      },
      onError: (error, handler) async {
        final isUnauthorized = error.response?.statusCode == 401;
        final options = error.requestOptions;
        final skipAuth = options.extra["skipAuth"] == true;
        final alreadyRetried = options.extra["retried"] == true;

        if (!isUnauthorized || skipAuth || alreadyRetried) {
          return handler.next(error);
        }

        final refreshToken = await tokenStorage.readRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          await tokenStorage.clear();
          return handler.next(error);
        }

        try {
          final refreshResponse = await refreshDio.post(
            "/auth/refresh",
            data: {"refresh": refreshToken},
          );
          final data = Map<String, dynamic>.from(refreshResponse.data as Map);
          final nextAccessToken = data["access"] as String;
          final nextRefreshToken = data["refresh"] as String? ?? refreshToken;

          await tokenStorage.saveTokens(
            accessToken: nextAccessToken,
            refreshToken: nextRefreshToken,
          );

          final headers = Map<String, dynamic>.from(options.headers);
          headers["Authorization"] = "Bearer $nextAccessToken";
          final extra = Map<String, dynamic>.from(options.extra);
          extra["retried"] = true;

          final retryResponse = await dio.fetch<dynamic>(
            options.copyWith(headers: headers, extra: extra),
          );
          return handler.resolve(retryResponse);
        } on DioException {
          await tokenStorage.clear();
          return handler.next(error);
        }
      },
    ),
  );

  return dio;
});
