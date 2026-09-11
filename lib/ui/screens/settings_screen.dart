import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
          constraints: const BoxConstraints(maxWidth: 820),
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
                      icon: Icons.cloud_sync_outlined,
                      title: '同步与备份',
                      subtitle: '一次同步所有游戏、角色、任务和完成记录',
                      onTap: () => _open(context, SyncScreen(state: state)),
                    ),
                    const SizedBox(height: 10),
                    _SettingCard(
                      icon: Icons.sports_esports_outlined,
                      title: '游戏管理',
                      subtitle: '添加、编辑或删除游戏分类',
                      onTap: () =>
                          _open(context, GameManagementScreen(state: state)),
                    ),
                    const SizedBox(height: 10),
                    _SettingCard(
                      icon: Icons.shield_outlined,
                      title: '角色管理',
                      subtitle: '管理当前游戏下的角色和角色任务',
                      onTap: () =>
                          _open(context, CharactersScreen(state: state)),
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
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.line),
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
            const Icon(Icons.chevron_right, size: 20, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}
