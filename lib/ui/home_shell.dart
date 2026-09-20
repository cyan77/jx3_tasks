import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/update_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'screens/calendar_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/matrix_screen.dart';
import 'screens/settings_screen.dart';
import 'task_editor.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.state, super.key});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    if (kReleaseMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForUpdatesOnStart();
      });
    }
  }

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
            extendBody: true,
            body: SafeArea(
              child: Row(
                children: [
                  if (wide) _SideRail(state: state),
                  Expanded(
                    child: screens[state.currentTab],
                  ),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : _GlassBottomNavigation(state: state),
            floatingActionButton: state.currentTab == 0
                ? _GlassCreateButton(
                    onPressed: () => showTaskEditor(
                      context,
                      state,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Future<void> _checkForUpdatesOnStart() async {
    try {
      final results = await Future.wait([
        PackageInfo.fromPlatform(),
        UpdateService().fetchLatestRelease(),
      ]);
      final packageInfo = results[0] as PackageInfo;
      final release = results[1] as AppRelease;
      if (!mounted ||
          !isVersionNewer(release.version, packageInfo.version)) {
        return;
      }
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
                    '当前版本 v${packageInfo.version} · 最新版本 v${release.version}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.muted),
                  ),
                  if (release.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('更新内容',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
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
      if (download != true || !mounted) return;
      final opened = await launchUrl(
        release.platformDownloadUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开下载地址，请前往 GitHub Release 下载')),
        );
      }
    } catch (_) {
      // Startup checks are intentionally silent when offline or GitHub is unavailable.
    }
  }
}

class _GlassCreateButton extends StatelessWidget {
  const _GlassCreateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = Color.lerp(
      scheme.surface,
      scheme.primaryContainer,
      dark ? 0.34 : 0.62,
    )!;
    return Container(
      key: const ValueKey('glass-create-task-button'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.20 : 0.09),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: FloatingActionButton.extended(
            onPressed: onPressed,
            elevation: 0,
            highlightElevation: 0,
            backgroundColor:
                glassColor.withValues(alpha: dark ? 0.84 : 0.90),
            foregroundColor: scheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.76),
              ),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('新建任务'),
          ),
        ),
      ),
    );
  }
}

class _GlassBottomNavigation extends StatelessWidget {
  const _GlassBottomNavigation({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = Color.lerp(
      scheme.surface,
      scheme.primaryContainer,
      dark ? 0.34 : 0.62,
    )!;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        key: const ValueKey('glass-bottom-navigation'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.20 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              key: const ValueKey('glass-bottom-navigation-surface'),
              decoration: BoxDecoration(
                color: glassColor.withValues(alpha: dark ? 0.82 : 0.88),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.72),
                ),
              ),
              child: NavigationBar(
              height: 66,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              indicatorColor: Color.lerp(
                scheme.primaryContainer,
                scheme.primary,
                dark ? 0.20 : 0.12,
              )!
                  .withValues(alpha: 0.78),
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
            ),
          ),
        ),
      ),
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
