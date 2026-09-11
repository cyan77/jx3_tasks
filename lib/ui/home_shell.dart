import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'screens/calendar_screen.dart';
import 'screens/dashboard_screen.dart';
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
      SettingsScreen(state: state),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        return Scaffold(
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
        decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppTheme.line))),
        padding: const EdgeInsets.fromLTRB(16, 22, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
                padding: EdgeInsets.only(left: 10, bottom: 26),
                child: Text('JX3 Tasks',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink))),
            _RailItem(
                icon: Icons.task_alt_outlined,
                label: '待办',
                index: 0,
                state: state),
            _RailItem(
                icon: Icons.checklist_outlined,
                label: '任务',
                index: 1,
                state: state),
            _RailItem(
                icon: Icons.event_available_outlined,
                label: '日历 / 时间线',
                index: 2,
                state: state),
            _RailItem(
                icon: Icons.settings_outlined,
                label: '设置',
                index: 3,
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
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.line)),
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
                icon: const Icon(Icons.unfold_more, size: 18),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ink),
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
          IconButton(
            tooltip: state.isSyncConfigured ? '立即同步' : '配置同步',
            onPressed: () => _sync(context),
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
}

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
        selectedTileColor: const Color(0xffeaf3f1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        leading: Icon(icon,
            size: 19, color: selected ? AppTheme.accent : AppTheme.muted),
        title: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppTheme.accent : AppTheme.ink)),
        onTap: () => state.setTab(index),
      ),
    );
  }
}
