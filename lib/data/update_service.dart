import 'dart:convert';
import 'dart:io';

class AppRelease {
  const AppRelease({
    required this.version,
    required this.name,
    required this.notes,
    required this.pageUri,
    required this.assets,
  });

  final String version;
  final String name;
  final String notes;
  final Uri pageUri;
  final Map<String, Uri> assets;

  Uri get platformDownloadUri {
    final candidates = Platform.isAndroid
        ? const ['角色日程-Android.apk', 'jx3_tasks-android.apk']
        : Platform.isWindows
            ? const [
                '角色日程-Windows-x64.zip',
                'jx3_tasks-windows-x64.zip',
              ]
            : Platform.isMacOS
                ? const [
                    '角色日程-macOS.dmg',
                    'jx3_tasks-macos.dmg',
                    'jx3_tasks-macos.zip',
                  ]
                : const <String>[];
    for (final name in candidates) {
      final uri = assets[name];
      if (uri != null) return uri;
    }
    return pageUri;
  }
}

class UpdateService {
  static final Uri _latestReleaseApi = Uri.https(
    'api.github.com',
    '/repos/cyan77/jx3_tasks/releases/latest',
  );

  Future<AppRelease> fetchLatestRelease() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(_latestReleaseApi);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'Role-Schedule-Update-Checker');
      final response = await request.close().timeout(const Duration(seconds: 12));
      final raw = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('GitHub 返回 ${response.statusCode}');
      }
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('更新信息格式无效');
      }
      final tag = json['tag_name'] as String?;
      final page = Uri.tryParse(json['html_url'] as String? ?? '');
      if (tag == null || page == null) {
        throw const FormatException('更新信息缺少版本或下载地址');
      }
      final assets = <String, Uri>{};
      for (final item in json['assets'] as List? ?? const []) {
        if (item is! Map) continue;
        final name = item['name'] as String?;
        final uri = Uri.tryParse(item['browser_download_url'] as String? ?? '');
        if (name != null && uri != null && _isTrustedGitHubUri(uri)) {
          assets[name] = uri;
        }
      }
      if (!_isTrustedGitHubUri(page)) {
        throw const FormatException('更新下载地址无效');
      }
      return AppRelease(
        version: tag.replaceFirst(RegExp(r'^v'), ''),
        name: json['name'] as String? ?? tag,
        notes: json['body'] as String? ?? '',
        pageUri: page,
        assets: assets,
      );
    } finally {
      client.close(force: true);
    }
  }
}

bool isVersionNewer(String candidate, String current) {
  List<int> parts(String value) => value
      .replaceFirst(RegExp(r'^v'), '')
      .split(RegExp(r'[-+]'))
      .first
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();

  final candidateParts = parts(candidate);
  final currentParts = parts(current);
  final count = candidateParts.length > currentParts.length
      ? candidateParts.length
      : currentParts.length;
  for (var index = 0; index < count; index++) {
    final next = index < candidateParts.length ? candidateParts[index] : 0;
    final installed = index < currentParts.length ? currentParts[index] : 0;
    if (next != installed) return next > installed;
  }
  return false;
}

bool _isTrustedGitHubUri(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host == 'github.com' &&
    uri.path.startsWith('/cyan77/jx3_tasks/');
