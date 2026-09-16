import 'package:flutter/material.dart';

import '../models/task_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'screens/calendar_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/matrix_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sync_screen.dart';
import 'task_editor.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(state: state),
      MatrixScreen(state: state),
      CalendarScreen(state: state),
      InboxScreen(state: state),
      SettingsScreen(state: state),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        return PopScope(
          canPop: state.currentTab == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && state.currentTab != 0) state.setTab(0);
          },
          child: Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  if (wide) _SideRail(state: state),
                  Expanded(
                      child: Column(
                    children: [
                      _GameBar(state: state),
                      Expanded(child: screens[state.currentTab]),
                    ],
                  )),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                  selectedIndex: state.currentTab,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  onDestinationSelected: state.setTab,
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.task_alt_outlined),
                        selectedIcon: Icon(Icons.task_alt),
                        label: '待办'),
                    NavigationDestination(
                        icon: Icon(Icons.checklist_outlined),
                        selectedIcon: Icon(Icons.checklist),
                        label: '任务'),
                    NavigationDestination(
                        icon: Icon(Icons.event_available_outlined),
                        selectedIcon: Icon(Icons.event_available),
                        label: '日历'),
                    NavigationDestination(
                        icon: Icon(Icons.inbox_outlined),
                        selectedIcon: Icon(Icons.inbox),
                        label: '收集箱'),
                    NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: '设置'),
                  ],
                  ),
            floatingActionButton: state.currentTab == 0
                ? FloatingActionButton.extended(
                    onPressed: () => showTaskEditor(context, state),
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    icon: const Icon(Icons.add, size: 19),
                    label: const Text('新建任务'),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => Container(
        width: 190,
        decoration: BoxDecoration(
            border: Border(
                right: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant))),
        padding: const EdgeInsets.fromLTRB(16, 22, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 26),
                child: Text('角色日程',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface))),
            _RailItem(
                icon: Icons.task_alt_outlined,
                label: '待办',
                index: 0,
                state: state),
            _RailItem(
                icon: Icons.checklist_outlined,
                label: '全部任务',
                index: 1,
                state: state),
            _RailItem(
                icon: Icons.event_available_outlined,
                label: '日历 / 时间线',
                index: 2,
                state: state),
            _RailItem(
                icon: Icons.inbox_outlined,
                label: '收集箱',
                index: 3,
                state: state),
            _RailItem(
                icon: Icons.settings_outlined,
                label: '设置',
                index: 4,
                state: state),
            const Spacer(),
            const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Text('本地离线模式',
                    style: TextStyle(fontSize: 11, color: AppTheme.muted))),
          ],
        ),
      );
}

class _GameBar extends StatelessWidget {
  const _GameBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedGame;
    final lastSyncAt = state.lastSyncAt?.toLocal();
    final compact = MediaQuery.sizeOf(context).width < 520;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sports_esports_outlined,
              size: 19, color: AppTheme.accent),
          const SizedBox(width: 7),
          const Text('游戏',
              style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected?.id,
                isExpanded: true,
                elevation: 0,
                dropdownColor: Theme.of(context).colorScheme.surface,
                focusColor: Colors.transparent,
                icon: const Icon(Icons.unfold_more, size: 18),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant),
                items: state.games
                    .map((game) => DropdownMenuItem(
                          value: game.id,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Color(game.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(game.name),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id != null) state.selectGame(id);
                },
              ),
            ),
          ),
          if (state.newerRemoteBackup != null)
            IconButton(
              tooltip: '发现更新的云端备份，点击恢复',
              onPressed: state.restoreBusy || state.syncBusy
                  ? null
                  : () => _restoreNewerBackup(context),
              icon: state.restoreBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore, size: 20),
            ),
          if (lastSyncAt != null)
            Tooltip(
              message: '上次成功同步：${_fullSyncTime(lastSyncAt)}',
              child: Padding(
                padding: const EdgeInsets.only(left: 6, right: 2),
                child: Text(
                  compact
                      ? '上次 ${twoDigits(lastSyncAt.hour)}:${twoDigits(lastSyncAt.minute)}'
                      : '上次成功 ${twoDigits(lastSyncAt.month)}/${twoDigits(lastSyncAt.day)} '
                          '${twoDigits(lastSyncAt.hour)}:${twoDigits(lastSyncAt.minute)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.muted,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: state.isSyncConfigured ? '立即同步' : '配置同步',
            onPressed: state.restoreBusy ? null : () => _sync(context),
            icon: state.syncBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    state.isSyncConfigured
                        ? Icons.cloud_sync_outlined
                        : Icons.cloud_off_outlined,
                    size: 20,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _sync(BuildContext context) async {
    if (!state.isSyncConfigured) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SyncScreen(state: state)),
      );
      return;
    }
    final success = await state.syncNow();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(state.syncMessage ?? (success ? '已同步' : '同步失败'))),
    );
  }

  Future<void> _restoreNewerBackup(BuildContext context) async {
    final backup = state.newerRemoteBackup;
    if (backup == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复更新的云端备份？'),
        content: Text(
          '本地所有游戏、角色、任务和完成记录将被“${backup.name}”替换。这次恢复不会在云端创建新备份；如需保留当前本地数据，请先手动上传备份。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await state.restoreBackup(backup);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已从云端备份恢复')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复失败：$error')),
      );
    }
  }
}

String _fullSyncTime(DateTime date) =>
    '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)} '
    '${twoDigits(date.hour)}:${twoDigits(date.minute)}:${twoDigits(date.second)}';

class _RailItem extends StatelessWidget {
  const _RailItem(
      {required this.icon,
      required this.label,
      required this.index,
      required this.state});
  final IconData icon;
  final String label;
  final int index;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final selected = state.currentTab == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        leading: Icon(icon,
            size: 19, color: selected ? AppTheme.accent : AppTheme.muted),
        title: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? AppTheme.accent
                    : Theme.of(context).colorScheme.onSurface)),
        onTap: () => state.setTab(index),
      ),
    );
  }
}
