class AppConfig {
  static const fallbackEnvironment = 'local';
  static const fallbackApiBaseUrl =
      'https://api.xn--b1apekb3anb5cpb.xn--p1ai/api/v1';

  const AppConfig({required this.environment, required this.apiBaseUrl});

  final String environment;
  final String apiBaseUrl;

  String get rootBaseUrl {
    final uri = Uri.parse(apiBaseUrl);
    final path = uri.path.replaceFirst(RegExp(r"/api/v1/?$"), "");
    final normalizedPath = path.isEmpty || path == "/" ? "" : path;
    return uri
        .replace(path: normalizedPath, query: null, fragment: null)
        .toString()
        .replaceFirst(RegExp(r"/$"), "");
  }

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      environment: String.fromEnvironment(
        'APP_ENV',
        defaultValue: fallbackEnvironment,
      ),
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: fallbackApiBaseUrl,
      ),
    );
  }
}
