import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/sync_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({required this.state, super.key});

  final AppState state;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final urlController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final pathController = TextEditingController();
  final settingsStore = SyncSettingsStore();
  final webDav = WebDavSyncService();
  int autoSyncMinutes = 0;
  bool loading = true;
  bool busy = false;
  bool backupsLoading = false;
  List<RemoteBackup> backups = const [];
  String? message;
  bool messageIsError = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final config = await settingsStore.load();
    if (!mounted) return;
    urlController.text = config.url;
    usernameController.text = config.username;
    passwordController.text = config.password;
    pathController.text = config.remotePath;
    autoSyncMinutes = config.autoSyncMinutes;
    setState(() => loading = false);
    if (config.isValid) _loadBackupsSilently();
  }

  SyncConfig get _config => SyncConfig(
        url: urlController.text,
        username: usernameController.text,
        password: passwordController.text,
        remotePath: pathController.text,
        autoSyncMinutes: autoSyncMinutes,
      );

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
      messageIsError = false;
    });
    try {
      await action();
    } catch (error) {
      _showFeedback('操作失败：$error', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _saveConfig() async {
    await _run(() async {
      await settingsStore.save(_config);
      await widget.state.reloadSyncSettings();
      await _loadBackupsSilently();
      _showFeedback('配置已保存在本机');
    });
  }

  Future<void> _testConnection() async {
    await _run(() async {
      final config = _config;
      await settingsStore.save(config);
      await widget.state.reloadSyncSettings();
      await webDav.testConnection(config);
      await _loadBackupsSilently();
      _showFeedback('连接成功');
    });
  }

  Future<void> _upload() async {
    final confirmed = await _confirm(
      '创建一份云端备份？',
      '这会新建一个带时间和设备标识的备份文件，不会覆盖其他设备的备份。云端只保留最近 10 份。',
    );
    if (!confirmed) return;
    await _run(() async {
      final config = _config;
      await settingsStore.save(config);
      await widget.state.reloadSyncSettings();
      final success = await widget.state.syncNow();
      if (!success) throw StateError(widget.state.syncMessage ?? '同步失败');
      await _loadBackupsSilently();
      _showFeedback('备份已保存到坚果云');
    });
  }

  Future<void> _refreshBackups() async {
    await _run(() async {
      if (mounted) setState(() => backupsLoading = true);
      try {
        final found = await _fetchBackups();
        if (mounted) setState(() => backups = found);
        _showFeedback('已找到 ${found.length} 份云端备份');
      } finally {
        if (mounted) setState(() => backupsLoading = false);
      }
    });
  }

  Future<void> _loadBackupsSilently() async {
    try {
      final found = await _fetchBackups();
      if (mounted) setState(() => backups = found);
    } catch (_) {
      // Loading the page should not block the user from editing the config.
    }
  }

  Future<List<RemoteBackup>> _fetchBackups() async {
    if (!_config.isValid) return const [];
    final config = _config;
    await settingsStore.save(config);
    await widget.state.reloadSyncSettings();
    return webDav.listBackups(config);
  }

  Future<void> _restoreBackup(RemoteBackup backup) async {
    final confirmed = await _confirm(
      '恢复这份备份？',
      '本地所有游戏、角色、任务和完成记录将被“${backup.name}”替换。这次恢复不会在云端创建新备份；如需保留当前本地数据，请先手动上传备份。',
    );
    if (!confirmed) return;
    await _run(() async {
      await widget.state.restoreBackup(backup);
      _showFeedback('已从坚果云恢复');
    });
  }

  Future<void> _exportLocal() async {
    await _run(() async {
      final bytes =
          Uint8List.fromList(utf8.encode(widget.state.exportBackup()));
      final savedPath = await FilePicker.saveFile(
        dialogTitle: '导出角色日程备份',
        fileName: 'game-tasks-backup.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
      if (savedPath == null) return;
      _showFeedback('本地备份已导出');
    });
  }

  Future<void> _importLocal() async {
    final confirmed = await _confirm(
      '导入并替换本地数据？',
      '当前本地数据会被备份文件替换。建议先导出当前数据。',
    );
    if (!confirmed) return;
    await _run(() async {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes ?? await file.xFile.readAsBytes();
      await widget.state.importBackup(utf8.decode(bytes));
      _showFeedback('本地备份已导入');
    });
  }

  void _showFeedback(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      messageIsError = error;
      message = text;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? const Color(0xffb94a48) : AppTheme.accent,
        ),
      );
  }

  Future<bool> _confirm(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('继续'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('同步与备份')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: double.infinity),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(
                  title: '同步与备份',
                  subtitle: '一次处理所有游戏、角色、任务和完成记录',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Panel(
                        title: '坚果云 WebDAV',
                        subtitle: '使用坚果云的应用密码，不要填写网页登录密码。请填写远程备份路径，密码只保存在本机。',
                        child: Column(
                          children: [
                            TextField(
                              controller: urlController,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'WebDAV 地址',
                                hintText: 'https://dav.jianguoyun.com/dav/',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: usernameController,
                              keyboardType: TextInputType.emailAddress,
                              decoration:
                                  const InputDecoration(labelText: '账号 / 邮箱'),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: passwordController,
                              obscureText: true,
                              decoration:
                                  const InputDecoration(labelText: '应用密码'),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: pathController,
                              decoration: const InputDecoration(
                                labelText: '远程备份路径',
                                hintText: '/JX3Tasks/backup.json',
                                helperText:
                                    '可以填写坚果云中的文件路径，例如 /JX3Tasks/backup.json',
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<int>(
                              initialValue: autoSyncMinutes,
                              decoration: const InputDecoration(
                                labelText: '自动同步周期',
                                helperText: '仅在应用运行或回到前台时检查，不会在系统完全退出后后台常驻运行。',
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 0, child: Text('关闭自动同步')),
                                DropdownMenuItem(
                                    value: 15, child: Text('每 15 分钟')),
                                DropdownMenuItem(
                                    value: 30, child: Text('每 30 分钟')),
                                DropdownMenuItem(
                                    value: 60, child: Text('每 1 小时')),
                                DropdownMenuItem(
                                    value: 360, child: Text('每 6 小时')),
                                DropdownMenuItem(
                                    value: 1440, child: Text('每天')),
                              ],
                              onChanged: busy
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(() => autoSyncMinutes = value);
                                      }
                                    },
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: busy ? null : _saveConfig,
                                  child: const Text('保存配置'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : _testConnection,
                                  icon: const Icon(Icons.wifi_tethering,
                                      size: 17),
                                  label: const Text('测试连接'),
                                ),
                                FilledButton.icon(
                                  onPressed: busy ? null : _upload,
                                  icon: const Icon(Icons.cloud_upload_outlined,
                                      size: 17),
                                  label: const Text('上传备份'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : _refreshBackups,
                                  icon: const Icon(Icons.refresh, size: 17),
                                  label: const Text('刷新列表'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Panel(
                        title: '云端备份（最近 10 份）',
                        subtitle: '每次上传都会生成新文件，并自动清理更旧的版本。选择任意一份即可恢复。',
                        child: backupsLoading
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: LinearProgressIndicator(minHeight: 3),
                              )
                            : backups.isEmpty
                                ? const Text(
                                    '暂无版本化备份，请先点击“上传备份”。',
                                    style: TextStyle(
                                        fontSize: 12, color: AppTheme.muted),
                                  )
                                : Column(
                                    children: [
                                      for (var index = 0;
                                          index < backups.length;
                                          index++) ...[
                                        if (index > 0) const Divider(height: 1),
                                        _RemoteBackupTile(
                                          backup: backups[index],
                                          isLatest: index == 0,
                                          isCurrent: backups[index].path ==
                                              widget.state
                                                  .currentRemoteBackupPath,
                                          onRestore: busy
                                              ? null
                                              : () => _restoreBackup(
                                                  backups[index]),
                                        ),
                                      ],
                                    ],
                                  ),
                      ),
                      const SizedBox(height: 14),
                      _Panel(
                        title: '本地备份',
                        subtitle: '导出为 JSON 文件，可保存到手机、电脑或其他云盘。',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: busy ? null : _exportLocal,
                              icon:
                                  const Icon(Icons.save_alt_outlined, size: 17),
                              label: const Text('导出备份'),
                            ),
                            OutlinedButton.icon(
                              onPressed: busy ? null : _importLocal,
                              icon: const Icon(Icons.folder_open_outlined,
                                  size: 17),
                              label: const Text('导入备份'),
                            ),
                          ],
                        ),
                      ),
                      if (busy) ...[
                        const SizedBox(height: 14),
                        const LinearProgressIndicator(minHeight: 3),
                      ],
                      if (message != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          message!,
                          style: TextStyle(
                            fontSize: 12,
                            color: messageIsError
                                ? const Color(0xffb94a48)
                                : AppTheme.accent,
                          ),
                        ),
                      ],
                      if (widget.state.lastSyncAt != null &&
                          message == null) ...[
                        const SizedBox(height: 14),
                        Text(
                          '上次同步：${_formatTime(widget.state.lastSyncAt!)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    urlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    pathController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime value) {
    final date = '${value.month}/${value.day}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _RemoteBackupTile extends StatelessWidget {
  const _RemoteBackupTile({
    required this.backup,
    required this.isLatest,
    required this.isCurrent,
    required this.onRestore,
  });

  final RemoteBackup backup;
  final bool isLatest;
  final bool isCurrent;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final modified = backup.modifiedAt == null
        ? '时间未知'
        : _formatDateTime(backup.modifiedAt!);
    final size = backup.size == null ? '' : ' · ${_formatSize(backup.size!)}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.cloud_done_outlined,
          size: 20, color: AppTheme.accent),
      title: Row(
        children: [
          Expanded(
            child: Text(backup.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 6),
            const _BackupVersionBadge(label: '当前版本', emphasized: true),
          ],
          if (isLatest) ...[
            const SizedBox(width: 6),
            const _BackupVersionBadge(label: '最新版本'),
          ],
        ],
      ),
      subtitle: Text('$modified$size',
          style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
      trailing: OutlinedButton(
        onPressed: onRestore,
        child: const Text('恢复'),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final date = '${value.year}/${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')}';
    final time = '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _formatSize(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _BackupVersionBadge extends StatelessWidget {
  const _BackupVersionBadge({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:
            emphasized ? scheme.primaryContainer : scheme.surfaceContainerLow,
        border: Border.all(
          color: emphasized ? scheme.primary : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: emphasized
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel(
      {required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}
