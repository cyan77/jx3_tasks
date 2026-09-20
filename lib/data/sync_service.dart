import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart';

const defaultWebDavBackupPath = '/JX3Tasks/backup.json';

class SyncConfig {
  const SyncConfig({
    required this.url,
    required this.username,
    required this.password,
    required this.remotePath,
    this.autoSyncMinutes = 0,
  });

  final String url;
  final String username;
  final String password;
  final String remotePath;
  final int autoSyncMinutes;

  bool get isValid =>
      url.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.isNotEmpty &&
      remotePath.trim().isNotEmpty;
}

class RemoteBackup {
  const RemoteBackup({
    required this.name,
    required this.path,
    this.modifiedAt,
    this.size,
  });

  final String name;
  final String path;
  final DateTime? modifiedAt;
  final int? size;
}

class SyncSettingsStore {
  static const _urlKey = 'webdav.url';
  static const _usernameKey = 'webdav.username';
  static const _passwordKey = 'webdav.password';
  static const _remotePathKey = 'webdav.remotePath';
  static const _autoSyncMinutesKey = 'webdav.autoSyncMinutes';
  static const _lastSyncAtKey = 'webdav.lastSyncAt';
  static const _currentBackupPathKey = 'webdav.currentBackupPath';

  Future<SyncConfig> load() async {
    final preferences = await SharedPreferences.getInstance();
    return SyncConfig(
      url: preferences.getString(_urlKey) ?? 'https://dav.jianguoyun.com/dav/',
      username: preferences.getString(_usernameKey) ?? '',
      password: preferences.getString(_passwordKey) ?? '',
      remotePath:
          preferences.getString(_remotePathKey) ?? defaultWebDavBackupPath,
      autoSyncMinutes: preferences.getInt(_autoSyncMinutesKey) ?? 0,
    );
  }

  Future<void> save(SyncConfig config) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_urlKey, config.url.trim());
    await preferences.setString(_usernameKey, config.username.trim());
    await preferences.setString(_passwordKey, config.password);
    await preferences.setString(
        _remotePathKey,
        config.remotePath.trim().isEmpty
            ? defaultWebDavBackupPath
            : config.remotePath.trim());
    await preferences.setInt(_autoSyncMinutesKey, config.autoSyncMinutes);
  }

  Future<DateTime?> loadLastSyncAt() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_lastSyncAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveLastSyncAt(DateTime value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastSyncAtKey, value.toIso8601String());
  }

  Future<String?> loadCurrentBackupPath() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_currentBackupPathKey);
  }

  Future<void> saveCurrentBackupPath(String? path) async {
    final preferences = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await preferences.remove(_currentBackupPathKey);
    } else {
      await preferences.setString(_currentBackupPathKey, path);
    }
  }
}

class SyncDeviceIdentityStore {
  static const _deviceNameKey = 'webdav.deviceName';

  Future<String> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_deviceNameKey);
    if (saved != null && saved.isNotEmpty) return saved;
    final host = io.Platform.localHostname
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final name =
        '${io.Platform.operatingSystem}-${host.isEmpty ? 'device' : host}'
            .toLowerCase();
    await preferences.setString(_deviceNameKey, name);
    return name;
  }
}

class WebDavSyncService {
  static const maxRemoteBackups = 10;
  final SyncDeviceIdentityStore deviceIdentityStore = SyncDeviceIdentityStore();

  Client _client(SyncConfig config) => newClient(
        config.url.trim(),
        user: config.username.trim(),
        password: config.password,
      )
        ..setConnectTimeout(10000)
        ..setSendTimeout(30000)
        ..setReceiveTimeout(30000)
        // webdav_client uploads a streamed byte body. Dio cannot infer its
        // content type on newer versions, so declare it explicitly.
        ..setHeaders({'content-type': 'application/json; charset=utf-8'});

  Future<void> testConnection(SyncConfig config) async {
    if (!config.isValid) {
      throw const FormatException('请先填写完整的 WebDAV 配置');
    }
    await _client(config).ping();
  }

  Future<RemoteBackup> upload(SyncConfig config, String json) async {
    if (!config.isValid) {
      throw const FormatException('请先填写完整的 WebDAV 配置');
    }
    final client = _client(config);
    final basePath = _normalizedPath(config.remotePath);
    final directory = _parentPath(basePath);
    if (directory.isNotEmpty) await client.mkdirAll(directory);
    final now = DateTime.now();
    final device = await deviceIdentityStore.load();
    final fileName = '${_fileStem(basePath)}_${_timestamp(now)}_$device.json';
    final path = _joinPath(directory, fileName);
    await client.write(path, Uint8List.fromList(utf8.encode(json)));
    await _removeOldBackups(client, config, keep: maxRemoteBackups);
    return RemoteBackup(name: fileName, path: path, modifiedAt: now);
  }

  Future<List<RemoteBackup>> listBackups(SyncConfig config) async {
    if (!config.isValid) {
      throw const FormatException('请先填写完整的 WebDAV 配置');
    }
    final client = _client(config);
    final basePath = _normalizedPath(config.remotePath);
    final directory = _parentPath(basePath);
    final prefix = '${_fileStem(basePath)}_';
    final legacyName = basePath.substring(basePath.lastIndexOf('/') + 1);
    final files = await client.readDir(directory);
    final backups = files
        .where((file) =>
            file.isDir != true &&
            file.name != null &&
            (file.name == legacyName || file.name!.startsWith(prefix)) &&
            file.name!.endsWith('.json'))
        .map((file) => RemoteBackup(
              name: file.name!,
              path: file.path ?? _joinPath(directory, file.name!),
              modifiedAt: file.mTime,
              size: file.size,
            ))
        .toList();
    backups.sort((a, b) {
      final aTime = _timeFromName(a.name) ?? a.modifiedAt;
      final bTime = _timeFromName(b.name) ?? b.modifiedAt;
      if (aTime != null && bTime != null) return bTime.compareTo(aTime);
      return b.name.compareTo(a.name);
    });
    return backups;
  }

  Future<String> downloadBackup(SyncConfig config, RemoteBackup backup) async {
    if (!config.isValid) {
      throw const FormatException('请先填写完整的 WebDAV 配置');
    }
    final bytes = await _client(config).read(backup.path);
    return utf8.decode(bytes);
  }

  DateTime? backupTime(RemoteBackup backup) =>
      _timeFromName(backup.name) ?? backup.modifiedAt;

  Future<void> _removeOldBackups(Client client, SyncConfig config,
      {required int keep}) async {
    final backups = await listBackups(config);
    for (final backup in backups.skip(keep)) {
      await client.remove(backup.path);
    }
  }

  String _normalizedPath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return defaultWebDavBackupPath;
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  String _parentPath(String path) {
    final index = path.lastIndexOf('/');
    return index <= 0 ? '/' : path.substring(0, index);
  }

  String _joinPath(String directory, String name) =>
      directory == '/' ? '/$name' : '$directory/$name';

  String _fileStem(String path) {
    final fileName = path.substring(path.lastIndexOf('/') + 1);
    final extension = fileName.lastIndexOf('.');
    final stem = extension > 0 ? fileName.substring(0, extension) : fileName;
    return stem.isEmpty ? 'backup' : stem;
  }

  String _timestamp(DateTime value) {
    final date = '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
    final time = '${value.hour.toString().padLeft(2, '0')}'
        '${value.minute.toString().padLeft(2, '0')}'
        '${value.second.toString().padLeft(2, '0')}'
        '${value.millisecond.toString().padLeft(3, '0')}'
        '${value.microsecond.toString().padLeft(6, '0')}';
    return '${date}_$time';
  }

  DateTime? _timeFromName(String name) {
    final match = RegExp(r'(\d{8})_(\d{9,15})').firstMatch(name);
    if (match == null) return null;
    final date = match.group(1)!;
    final time = match.group(2)!;
    return DateTime.tryParse(
        '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}T'
        '${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}.'
        '${time.substring(6, 9)}');
  }
}
