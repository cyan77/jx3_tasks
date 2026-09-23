import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/update_service.dart';
import '../../data/app_restart.dart';
import '../../data/local_store.dart';
import '../../data/theme_settings.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import 'characters_screen.dart';
import 'game_management_screen.dart';
import 'sync_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.state, super.key});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();
  final UpdateService _updateService = UpdateService();
  bool _checkingForUpdates = false;

  AppState get state => widget.state;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: double.infinity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: '设置',
                subtitle: '管理游戏、角色，以及整份任务数据的同步与备份',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _SettingCard(
                      icon: Icons.dark_mode_outlined,
                      title: '外观模式',
                      subtitle: '浅色、深色，或自动跟随系统设置',
                      onTap: _selectThemeMode,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            themeModeLabel(state.themeMode),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: AppTheme.muted,
                          ),
                        ],
                      ),
                    ),
                    if (io.Platform.isWindows || io.Platform.isMacOS) ...[
                      const SizedBox(height: 10),
                      _SettingCard(
                        icon: Icons.folder_open_outlined,
                        title: '本地数据位置',
                        subtitle: state.store.dataDirectory == null
                            ? '系统默认位置；可迁移到指定文件夹'
                            : state.store.dataDirectory!,
                        onTap: _changeDataDirectory,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _SettingCard(
                      icon: Icons.cloud_sync_outlined,
                      title: '同步与备份',
                      subtitle: '一次同步所有游戏、角色、任务和完成记录',
                      onTap: () => _open(context, SyncScreen(state: state)),
                    ),
                    const SizedBox(height: 10),
                    _SettingCard(
                      icon: Icons.sports_esports_outlined,
                      title: '游戏管理',
                      subtitle: '添加、编辑游戏，并设置每日任务截止时间',
                      onTap: () =>
                          _open(context, GameManagementScreen(state: state)),
                    ),
                    const SizedBox(height: 10),
                    _SettingCard(
                      icon: Icons.shield_outlined,
                      title: '角色管理',
                      subtitle: '按游戏管理全部角色和角色任务',
                      onTap: () =>
                          _open(context, CharactersScreen(state: state)),
                    ),
                    const SizedBox(height: 10),
                    _SettingCard(
                      icon: Icons.system_update_outlined,
                      title: '检查更新',
                      subtitle: _checkingForUpdates
                          ? '正在查询 GitHub Release…'
                          : '查询新版本并下载当前平台安装包',
                      onTap: _checkingForUpdates ? null : _checkForUpdates,
                      trailing: _checkingForUpdates
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '当前数据范围：${state.games.length} 个游戏 · ${state.store.characters.length} 个角色',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FutureBuilder<PackageInfo>(
                        future: _packageInfo,
                        builder: (context, snapshot) {
                          final info = snapshot.data;
                          final version = info == null
                              ? '读取中…'
                              : '版本 ${info.version}+${info.buildNumber}';
                          return Text(
                            version,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingForUpdates = true);
    try {
      final results = await Future.wait([
        _packageInfo,
        _updateService.fetchLatestRelease(),
      ]);
      final packageInfo = results[0] as PackageInfo;
      final release = results[1] as AppRelease;
      if (!mounted) return;
      setState(() => _checkingForUpdates = false);
      if (!isVersionNewer(release.version, packageInfo.version)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('当前已是最新版本 v${packageInfo.version}')),
        );
        return;
      }
      await _showUpdateDialog(release, packageInfo.version);
    } catch (error) {
      if (!mounted) return;
      setState(() => _checkingForUpdates = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败：$error')),
      );
    }
  }

  Future<void> _selectThemeMode() async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('外观模式'),
        children: ThemeMode.values
            .map(
              (mode) => RadioListTile<ThemeMode>(
                value: mode,
                groupValue: state.themeMode,
                title: Text(themeModeLabel(mode)),
                subtitle: mode == ThemeMode.system
                    ? const Text('随设备的浅色或深色模式自动切换')
                    : null,
                onChanged: (value) => Navigator.pop(dialogContext, value),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) await state.setThemeMode(selected);
  }

  Future<void> _changeDataDirectory() async {
    if (!io.Platform.isWindows && !io.Platform.isMacOS) return;
    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: '选择角色日程数据文件夹',
    );
    if (!mounted || selected == null || selected.trim().isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('迁移本地数据并重启？'),
        content: Text(
          '当前所有游戏、角色、任务和完成记录将迁移到：\n\n'
          '$selected\n\n'
          '数据文件名为 ${LocalStore.dataFileName}。迁移完成后应用会自动重启。'
          '\n\n目标文件夹中不能已有同名数据文件。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('迁移并重启'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await state.store.migrateToDirectory(selected);
      await restartApplication();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('迁移失败：$error')),
      );
    }
  }

  Future<void> _showUpdateDialog(
    AppRelease release,
    String currentVersion,
  ) async {
    final download = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('发现新版本 v${release.version}'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '当前版本 v$currentVersion · 最新版本 v${release.version}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                if (release.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('更新内容',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  SelectableText(
                    release.notes.trim(),
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('稍后'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('下载更新'),
          ),
        ],
      ),
    );
    if (download == true) await _openDownload(release.platformDownloadUri);
  }

  Future<void> _openDownload(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开下载地址，请前往 GitHub Release 下载')),
      );
    }
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppTheme.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 12, color: AppTheme.muted)),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppTheme.muted,
                ),
          ],
        ),
      ),
    );
  }
}
