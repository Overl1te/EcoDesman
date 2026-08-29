class AppConfig {
  static const fallbackEnvironment = 'production';

  /// Punycode for https://эковыхухоль.рф — the public site and API host.
  static const productionHost = 'xn--b1apekb3anb5cpb.xn--p1ai';
  static const productionSiteUrl = 'https://$productionHost';
  static const fallbackApiBaseUrl = '$productionSiteUrl/api/v1';

  static const _staleMediaHosts = {
    productionHost,
    'www.$productionHost',
    'api.$productionHost',
    'эковыхухоль.рф',
    'www.эковыхухоль.рф',
    'api.эковыхухоль.рф',
    '45.88.15.78',
  };

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

  String get mapRasterTileTemplate => '$rootBaseUrl/map-raster/{z}/{x}/{y}.png';

  String resolveMediaUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(value);
    if (uri == null) {
      return value;
    }

    if (!uri.hasScheme || uri.host.isEmpty) {
      final path = value.startsWith('/') ? value : '/$value';
      return '$rootBaseUrl$path';
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return value;
    }

    final host = uri.host.toLowerCase();
    if (!_staleMediaHosts.contains(host)) {
      return value;
    }

    return uri.replace(scheme: 'https', host: productionHost).toString();
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
