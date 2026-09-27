import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.build,
    required this.releaseUrl,
  });

  final String version;
  final int build;
  final String releaseUrl;
}

class UpdateChecker {
  UpdateChecker({Dio? client})
      : _client = client ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'EcoDesman-Mobile',
          },
        ));

  static const _latestReleaseUrl =
      'https://api.github.com/repos/Overl1te/EcoDesman/releases/latest';

  final Dio _client;

  Future<AppUpdateInfo?> check() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final response = await _client.get<Map<String, dynamic>>(
        _latestReleaseUrl,
      );
      final data = response.data;
      if (data == null) return null;

      final parsed = _parseTag(data['tag_name'] as String?);
      final releaseUrl = data['html_url'] as String?;
      if (parsed == null || releaseUrl == null || releaseUrl.isEmpty) {
        return null;
      }

      final installed = _Version(package.version, int.tryParse(package.buildNumber) ?? 0);
      if (parsed <= installed) return null;

      return AppUpdateInfo(
        version: parsed.name,
        build: parsed.build,
        releaseUrl: releaseUrl,
      );
    } catch (_) {
      // An update check must never prevent the app from starting.
      return null;
    }
  }

  _Version? _parseTag(String? tag) {
    if (tag == null) return null;
    final normalized = tag.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    final parts = normalized.split('+');
    final version = parts.first.split('-').first;
    final numbers = version.split('.').map(int.tryParse).toList();
    if (numbers.any((number) => number == null) || numbers.isEmpty) return null;
    return _Version(
      version,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      major: numbers[0]!,
      minor: numbers.length > 1 ? numbers[1]! : 0,
      patch: numbers.length > 2 ? numbers[2]! : 0,
    );
  }
}

class _Version implements Comparable<_Version> {
  const _Version(this.name, this.build, {this.major = 0, this.minor = 0, this.patch = 0});

  final String name;
  final int build;
  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(_Version other) {
    final versionCompare = major != other.major
        ? major.compareTo(other.major)
        : minor != other.minor
            ? minor.compareTo(other.minor)
            : patch.compareTo(other.patch);
    return versionCompare != 0 ? versionCompare : build.compareTo(other.build);
  }

  bool operator <=(_Version other) => compareTo(other) <= 0;
}
