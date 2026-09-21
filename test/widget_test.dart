import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jx3_tasks/data/local_store.dart';
import 'package:jx3_tasks/data/sync_service.dart';
import 'package:jx3_tasks/data/theme_settings.dart';
import 'package:jx3_tasks/data/update_service.dart';
import 'package:jx3_tasks/models/task_expiry.dart';
import 'package:jx3_tasks/models/task_models.dart';
import 'package:jx3_tasks/state/app_state.dart';
import 'package:jx3_tasks/theme/app_theme.dart';
import 'package:jx3_tasks/app.dart';
import 'package:jx3_tasks/ui/task_editor.dart';
import 'package:jx3_tasks/ui/screens/matrix_screen.dart';
import 'package:jx3_tasks/ui/screens/dashboard_screen.dart';
import 'package:jx3_tasks/ui/screens/calendar_screen.dart';
import 'package:jx3_tasks/ui/screens/characters_screen.dart';
import 'package:jx3_tasks/ui/screens/sync_screen.dart';
import 'package:jx3_tasks/ui/home_shell.dart';
import 'package:jx3_tasks/ui/widgets/common.dart';

void main() {
  testWidgets('repeating icon button accelerates while held', (tester) async {
    var count = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RepeatingIconButton(
          icon: Icons.add,
          tooltip: '增加',
          onPressed: () => count++,
        ),
      ),
    ));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(RepeatingIconButton)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final countAfterLongPress = count;
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();

    expect(countAfterLongPress, greaterThanOrEqualTo(1));
    expect(count, greaterThan(countAfterLongPress));
  });

  testWidgets('new assigned tasks default to one-time frequency',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'game', name: '游戏')]
      ..characters = const [
        Character(
          id: 'character',
          gameId: 'game',
          account: '',
          name: '角色',
          occupation: '',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = const [];
    final state = AppState(store);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTaskEditor(context, state),
            child: const Text('打开任务编辑器'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开任务编辑器'));
    await tester.pumpAndSettle();

    expect(find.text('一次性'), findsOneWidget);
    expect(find.text('每日'), findsNothing);
    state.dispose();
  });

  testWidgets('shared dropdown menus open below their full-width field',
      (tester) async {
    String selected = 'game-jx3';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, setState) => AppDropdownField<String>(
                  key: const ValueKey('shared-dropdown'),
                  value: selected,
                  label: '所属游戏',
                  items: const [
                    DropdownMenuItem(value: 'game-jx3', child: Text('剑网3')),
                    DropdownMenuItem(value: 'game-hsr', child: Text('崩铁')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => selected = value);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final field = find.byKey(const ValueKey('shared-dropdown'));
    final button = tester.widget<PopupMenuButton<int>>(
      find.descendant(of: field, matching: find.byType(PopupMenuButton<int>)),
    );
    expect(button.position, PopupMenuPosition.under);
    expect(button.offset.dy, greaterThan(0));
    expect(button.elevation, 0);
    expect(button.constraints?.maxWidth, 300);
    expect(button.constraints?.maxHeight, 240);
    final fieldBottom = tester.getBottomLeft(field).dy;

    await tester.tap(find.byTooltip('所属游戏'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('崩铁')).dy, greaterThan(fieldBottom));
  });

  testWidgets('unconfigured WebDAV stays collapsed until requested',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const []
      ..characters = const []
      ..tasks = const [];
    final state = AppState(store);

    await tester.pumpWidget(
      MaterialApp(home: SyncScreen(state: state)),
    );
    await tester.pumpAndSettle();

    expect(find.text('未配置'), findsOneWidget);
    expect(find.byKey(const ValueKey('configure-webdav')), findsOneWidget);
    expect(find.byKey(const ValueKey('webdav-config-form')), findsNothing);
    expect(find.text('云端备份（最近 10 份）'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('configure-webdav')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('webdav-config-form')), findsOneWidget);
    expect(find.text('WebDAV 地址'), findsOneWidget);
    expect(find.text('测试并保存'), findsOneWidget);
    state.dispose();
  });

  test('inbox save includes uncommitted comma-separated tag input', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const []
      ..tasks = [];
    final state = AppState(store);

    final tags = normalizeTaskTags(const [], '紧急，周常');
    await state.addInboxTask(
      title: '收集箱标签测试',
      gameId: 'game-jx3',
      tags: tags,
    );

    expect(state.inboxTasks.single.tags, unorderedEquals(['紧急', '周常']));
    state.dispose();
  });

  testWidgets('日期控件统一使用简体中文', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const []
      ..characters = const []
      ..tasks = const [];

    await tester.pumpWidget(Jx3TasksApp(store: store));
    await tester.pump();

    final context = tester.element(find.byType(HomeShell));
    expect(Localizations.localeOf(context), const Locale('zh', 'CN'));
    expect(
      MaterialLocalizations.of(context).formatMonthYear(DateTime(2026, 9)),
      contains('月'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('theme preference defaults to light and persists the selected mode',
      () async {
    SharedPreferences.setMockInitialValues({});
    final settings = ThemeSettingsStore();

    expect(await settings.load(), ThemeMode.light);
    await settings.save(ThemeMode.dark);
    expect(await settings.load(), ThemeMode.dark);
  });

  test('dark theme uses a dark color scheme', () {
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.dark.colorScheme.surface.computeLuminance(), lessThan(0.1));
  });

  test('release version comparison only accepts a newer semantic version', () {
    expect(isVersionNewer('0.3.1', '0.3.0'), isTrue);
    expect(isVersionNewer('v0.4.0', '0.3.9+7'), isTrue);
    expect(isVersionNewer('0.3.0', '0.3.0'), isFalse);
    expect(isVersionNewer('0.3.0+8', '0.3.0+7'), isFalse);
    expect(isVersionNewer('0.2.9', '0.3.0'), isFalse);
  });

  test('once task warns within seven days or with at most one rest day', () {
    TaskRecord taskDue(DateTime dueDate) => TaskRecord(
          id: 'once',
          templateId: 'once',
          title: '限时任务',
          characterId: 'character',
          frequency: TaskFrequency.once,
          createdAt: DateTime(2026, 9, 1),
          dueDate: dueDate,
        );

    expect(
      taskExpiryStatus(taskDue(DateTime(2026, 9, 19)), DateTime(2026, 9, 15)),
      TaskExpiryStatus.expiringSoon,
    );
    expect(
      taskExpiryStatus(taskDue(DateTime(2026, 9, 21)), DateTime(2026, 9, 15)),
      TaskExpiryStatus.expiringSoon,
    );
    expect(
      taskExpiryStatus(taskDue(DateTime(2026, 9, 20)), DateTime(2026, 9, 16)),
      TaskExpiryStatus.expiringSoon,
    );
    expect(
      taskExpiryStatus(taskDue(DateTime(2026, 9, 25)), DateTime(2026, 9, 15)),
      TaskExpiryStatus.expiringSoon,
    );
    expect(
      taskExpiryStatus(taskDue(DateTime(2026, 10, 1)), DateTime(2026, 9, 15)),
      TaskExpiryStatus.normal,
    );
    expect(
      taskExpiryStatus(taskDue(DateTime(2026, 9, 25)), DateTime(2026, 9, 20)),
      TaskExpiryStatus.expiringSoon,
    );
    expect(isChinaRestDay(DateTime(2026, 9, 20)), isFalse);
    expect(isChinaRestDay(DateTime(2026, 9, 25)), isTrue);
  });

  test('restoring a cloud backup does not upload another backup', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'local-game', name: '本地游戏')]
      ..characters = const []
      ..tasks = const [];
    final webDav = _FakeWebDavSyncService(
      '''{
        "schemaVersion": 3,
        "app": "Role Schedule",
        "games": [{"id": "remote-game", "name": "云端游戏"}],
        "characters": [],
        "tasks": []
      }''',
    );
    final settings = _FakeSyncSettingsStore();
    final state = AppState(
      store,
      syncSettingsStore: settings,
      webDavSyncService: webDav,
    );

    await state.restoreBackup(
      const RemoteBackup(name: 'backup.json', path: '/backup.json'),
    );

    expect(webDav.downloadCount, 1);
    expect(webDav.uploadCount, 0);
    expect(store.games.single.name, '云端游戏');
    expect(state.syncMessage, '已恢复 · backup.json');
    expect(state.currentRemoteBackupPath, '/backup.json');
    expect(settings.currentBackupPath, '/backup.json');

    await state.importBackup(webDav.downloadPayload);
    expect(state.currentRemoteBackupPath, isNull);
    expect(settings.currentBackupPath, isNull);
    state.dispose();
  });

  test('configured sync periodically checks for backups from other devices',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'game', name: '游戏')]
      ..characters = const []
      ..tasks = const [];
    final webDav = _FakeWebDavSyncService('{}');
    final state = AppState(
      store,
      syncSettingsStore: _FakeSyncSettingsStore(),
      webDavSyncService: webDav,
      remoteCheckInterval: const Duration(milliseconds: 10),
    );

    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(webDav.listCount, greaterThanOrEqualTo(2));

    state.dispose();
    final checksAfterDispose = webDav.listCount;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(webDav.listCount, checksAfterDispose);
  });

  testWidgets('system back returns a secondary tab to the todo home',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const []
      ..tasks = const [];
    final state = AppState(store)..setTab(4);

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, child) => MaterialApp(home: HomeShell(state: state)),
      ),
    );
    expect(state.currentTab, 4);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(state.currentTab, 0);
    expect(find.text('今日待办'), findsOneWidget);
    state.dispose();
  });

  testWidgets('top add starts unassigned while bottom add keeps current role',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '当前角色',
          occupation: '',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = const [];
    final state = AppState(store);

    await tester.pumpWidget(MaterialApp(home: HomeShell(state: state)));

    await tester.tap(find.text('新建任务').first);
    await tester.pumpAndSettle();
    expect(
        tester.widget<FilterChip>(find.byType(FilterChip)).selected, isFalse);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('page header title and subtitle are explicitly left aligned',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PageHeader(title: '任务', subtitle: '查看所有角色任务'),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('任务')).textAlign,
      TextAlign.left,
    );
    expect(
      tester.widget<Text>(find.text('查看所有角色任务')).textAlign,
      TextAlign.left,
    );
    expect(
      tester.getSize(find.byType(PageHeader)).width,
      tester.getSize(find.byType(Scaffold)).width,
    );
  });

  testWidgets('窄屏标题和右上操作按钮保持在标题区内', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageHeader(
            title: '全部任务',
            subtitle: '显示任务数量',
            action: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('新建任务'),
            ),
          ),
        ),
      ),
    );

    final titleTop = tester.getTopLeft(find.text('全部任务')).dy;
    final actionTop = tester.getTopLeft(find.text('新建任务')).dy;
    expect(actionTop, greaterThan(titleTop));
    expect(actionTop, lessThan(titleTop + 32));
  });

  testWidgets('手机端全部任务只保留右上新建入口', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(400, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = LocalStore()
      ..games = const [Game(id: 'game', name: '游戏')]
      ..characters = const []
      ..tasks = const [];
    final state = AppState(store)..setTab(1);

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, child) => MaterialApp(home: HomeShell(state: state)),
      ),
    );
    await tester.pump();

    expect(find.text('新建任务'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    state.dispose();
  });

  testWidgets('calendar keeps subtasks hidden on narrow screens',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final date = DateTime(2026, 9, 10);
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '账号',
          name: '角色',
          occupation: '奶歌',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = [
        TaskRecord(
          id: 'calendar-task-narrow',
          templateId: 'calendar-task-narrow',
          title: '手机日历任务',
          characterId: 'char-1',
          frequency: TaskFrequency.once,
          createdAt: DateTime(2026, 9, 1),
          dueDate: date,
          subtasks: const [
            TaskSubtask(id: 'subtask-1', title: '手机端隐藏的子任务'),
          ],
        ),
      ];
    final state = AppState(store)..selectCalendarDate(date);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, child) => CalendarScreen(state: state),
          ),
        ),
      ),
    );

    expect(find.text('手机日历任务'), findsNWidgets(2));
    expect(find.text('手机端隐藏的子任务'), findsNothing);
    state.dispose();
  });

  testWidgets('task search starts as an icon and expands in the title row',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const []
      ..tasks = const [];
    final state = AppState(store);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MatrixScreen(state: state)),
      ),
    );

    expect(find.byTooltip('搜索任务'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byTooltip('搜索任务'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('关闭搜索'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭搜索'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    state.dispose();
  });

  testWidgets('all tasks page supports selecting multiple task templates',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '角色一',
          occupation: '',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = [
        TaskRecord(
          id: 'task-1-char-1',
          templateId: 'task-1',
          title: '任务一',
          characterId: 'char-1',
          frequency: TaskFrequency.daily,
          createdAt: DateTime(2026, 9, 1),
        ),
        TaskRecord(
          id: 'task-2-char-1',
          templateId: 'task-2',
          title: '任务二',
          characterId: 'char-1',
          frequency: TaskFrequency.weekly,
          createdAt: DateTime(2026, 9, 1),
        ),
      ];
    final state = AppState(store);

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, child) => MaterialApp(
          home: Scaffold(body: MatrixScreen(state: state)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('全部任务'), findsOneWidget);
    expect(find.text('新建任务'), findsOneWidget);
    expect(find.text('任务一'), findsOneWidget);
    expect(find.text('任务二'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('批量分配'), findsNothing);
    expect(find.text('点击任务右上角的选择按钮进行多选管理'), findsOneWidget);
    expect(find.byKey(const ValueKey('select-task-task-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('select-task-task-2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('select-task-task-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('select-task-task-2')));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 项'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('selected-task-task-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-task-task-2')), findsOneWidget);
    expect(find.text('批量分配'), findsOneWidget);
    expect(find.text('移到收集箱'), findsOneWidget);
    final selectionBar = find.byKey(
      const ValueKey('mobile-selection-actions'),
    );
    expect(selectionBar, findsOneWidget);
    expect(tester.getTopLeft(selectionBar).dx, greaterThanOrEqualTo(0));
    expect(tester.getTopRight(selectionBar).dx, lessThanOrEqualTo(800));
    await tester.tap(find.text('任务一'));
    await tester.pump();
    expect(find.text('已选 1 项'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('selected-task-task-1')), findsNothing);
    expect(find.byKey(const ValueKey('selected-task-task-2')), findsOneWidget);
    expect(find.text('管理分配'), findsOneWidget);
    state.dispose();
  });

  testWidgets('long press enters selection mode for every task card',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '角色一',
          occupation: '',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = [
        TaskRecord(
          id: 'task-1-char-1',
          templateId: 'task-1',
          title: '任务一',
          characterId: 'char-1',
          frequency: TaskFrequency.daily,
          createdAt: DateTime(2026, 9, 1),
        ),
        TaskRecord(
          id: 'task-2-char-1',
          templateId: 'task-2',
          title: '任务二',
          characterId: 'char-1',
          frequency: TaskFrequency.weekly,
          createdAt: DateTime(2026, 9, 1),
        ),
      ];
    final state = AppState(store);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MatrixScreen(state: state))),
    );
    await tester.pump();

    await tester.longPress(find.text('任务一'));
    await tester.pump();
    expect(find.text('已选 1 项'), findsNWidgets(2));

    await tester.tap(find.text('任务二'));
    await tester.pump();
    expect(find.text('已选 2 项'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('selected-task-task-2')), findsOneWidget);

    await tester.tap(find.text('任务一'));
    await tester.pump();
    expect(find.text('已选 1 项'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('selected-task-task-1')), findsNothing);
    state.dispose();
  });

  testWidgets('all tasks page filters by game, character, and completion',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final today = dateKey(DateTime.now());
    final store = LocalStore()
      ..games = const [
        Game(id: 'game-jx3', name: '剑网3'),
        Game(id: 'game-hsr', name: '崩坏：星穹铁道'),
      ]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '角色一',
          occupation: '',
          color: 0xff2f7d72,
        ),
        Character(
          id: 'char-2',
          gameId: 'game-hsr',
          account: '',
          name: '角色二',
          occupation: '',
          color: 0xff5a78aa,
        ),
      ]
      ..tasks = [
        TaskRecord(
          id: 'done-char-1',
          templateId: 'done',
          title: '已完成任务',
          characterId: 'char-1',
          frequency: TaskFrequency.daily,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          completedDates: [today],
          tags: const ['周常'],
        ),
        TaskRecord(
          id: 'open-char-2',
          templateId: 'open',
          title: '未完成任务',
          characterId: 'char-2',
          frequency: TaskFrequency.daily,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          tags: const ['日常'],
        ),
        TaskRecord(
          id: 'expiring-char-2',
          templateId: 'expiring',
          title: '即将过期任务',
          characterId: 'char-2',
          frequency: TaskFrequency.once,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          dueDate: startOfDay(DateTime.now()),
        ),
      ];
    final state = AppState(store);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MatrixScreen(state: state))),
    );
    await tester.pump();
    expect(tester.getTopLeft(find.byTooltip('按游戏筛选')).dx, 20);
    final filterControls = [
      find.byKey(const ValueKey('task-filter-control-按游戏筛选')),
      find.byKey(const ValueKey('task-filter-control-按角色筛选')),
      find.byKey(const ValueKey('task-filter-control-按完成状态筛选')),
      find.byKey(const ValueKey('task-filter-control-按归档状态筛选')),
    ];
    final firstFilter = tester.widget<PopupMenuButton<dynamic>>(
      filterControls.first,
    );
    expect(firstFilter.position, PopupMenuPosition.under);
    expect(firstFilter.offset.dy, greaterThan(0));
    expect(firstFilter.elevation, 0);
    expect(firstFilter.constraints?.maxHeight, greaterThan(0));
    expect(firstFilter.constraints?.maxHeight, lessThanOrEqualTo(420));
    for (final control in filterControls.skip(1)) {
      final filter = tester.widget<PopupMenuButton<dynamic>>(control);
      expect(filter.position, PopupMenuPosition.under);
      expect(filter.constraints?.maxHeight, greaterThan(0));
      expect(filter.constraints?.maxHeight, lessThanOrEqualTo(420));
    }
    final filterContainers = [
      find.byKey(const ValueKey('task-filter-按游戏筛选')),
      find.byKey(const ValueKey('task-filter-按角色筛选')),
      find.byKey(const ValueKey('task-filter-按完成状态筛选')),
      find.byKey(const ValueKey('task-filter-按归档状态筛选')),
    ];
    for (final container in filterContainers) {
      expect(tester.getSize(container).height, 40);
    }
    final tagFilterButton =
        find.byKey(const ValueKey('task-tag-filter-button'));
    expect(tagFilterButton, findsOneWidget);
    expect(find.byKey(const ValueKey('task-tag-filter-options')), findsNothing);
    final gameFilterContainer = tester.widget<Container>(
      find.byKey(const ValueKey('task-filter-按游戏筛选')),
    );
    final gameFilterDecoration =
        gameFilterContainer.decoration! as BoxDecoration;
    expect(gameFilterDecoration.borderRadius, BorderRadius.circular(12));
    expect(gameFilterDecoration.color, isNotNull);
    await tester.tap(filterControls.first);
    await tester.pumpAndSettle();
    final openMenuItems =
        find.byWidgetPredicate((widget) => widget is PopupMenuItem);
    expect(openMenuItems, findsWidgets);
    for (final item in openMenuItems.evaluate()) {
      expect(tester.getSize(find.byWidget(item.widget)).height, 40);
    }
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsOneWidget);
    expect(find.text('未完成任务'), findsOneWidget);
    expect(find.text('即将过期任务'), findsOneWidget);
    expect(find.text('即将过期'), findsOneWidget);

    for (final control in filterControls) {
      expect(control, findsOneWidget);
    }
    final filterTop = tester.getTopLeft(filterControls.first).dy;
    for (var index = 1; index < 4; index++) {
      expect(tester.getTopLeft(filterControls[index]).dy, filterTop);
    }
    await tester.tap(filterControls[2]);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('全部状态').last).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(filterControls[2]).dy),
    );
    await tester.tap(find.text('即将过期').last);
    await tester.pumpAndSettle();

    expect(find.text('即将过期任务'), findsOneWidget);
    expect(find.text('已完成任务'), findsNothing);
    expect(find.text('未完成任务'), findsNothing);

    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();
    await tester.tap(filterControls[2]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('已完成').last);
    await tester.pumpAndSettle();

    expect(find.text('已完成任务'), findsOneWidget);
    expect(find.text('未完成任务'), findsNothing);
    expect(find.text('清除筛选'), findsOneWidget);

    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();
    await tester.tap(filterControls[0]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('崩坏：星穹铁道').last);
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsNothing);
    expect(find.text('未完成任务'), findsOneWidget);

    await tester.tap(filterControls[1]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('角色二').last);
    await tester.pumpAndSettle();
    expect(find.text('未完成任务'), findsOneWidget);

    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();
    await tester.tap(tagFilterButton);
    await tester.pumpAndSettle();
    final tagOptions = find.byKey(const ValueKey('task-tag-filter-options'));
    expect(tagOptions, findsOneWidget);
    expect(
      tester.getBottomLeft(tagOptions).dy,
      lessThanOrEqualTo(tester.getTopLeft(tagFilterButton).dy),
    );
    expect(find.text('#日常'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('task-tag-filter-日常')));
    await tester.pumpAndSettle();
    expect(find.text('未完成任务'), findsOneWidget);
    expect(find.text('已完成任务'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('task-tag-filter-日常')));
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsOneWidget);
    state.dispose();
  });

  testWidgets('全部任务可按角色切换完成状态', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final today = dateKey(DateTime.now());
    final store = LocalStore()
      ..games = const [Game(id: 'game', name: '游戏')]
      ..characters = const [
        Character(
          id: 'character-1',
          gameId: 'game',
          account: '',
          name: '角色一',
          occupation: '',
          color: 0xff2f7d72,
        ),
        Character(
          id: 'character-2',
          gameId: 'game',
          account: '',
          name: '角色二',
          occupation: '',
          color: 0xff5a78aa,
        ),
      ]
      ..tasks = [
        TaskRecord(
          id: 'task-1',
          templateId: 'shared-task',
          title: '共享任务',
          characterId: 'character-1',
          frequency: TaskFrequency.daily,
          createdAt: DateTime.now(),
          completedDates: [today],
        ),
        TaskRecord(
          id: 'task-2',
          templateId: 'shared-task',
          title: '共享任务',
          characterId: 'character-2',
          frequency: TaskFrequency.daily,
          createdAt: DateTime.now(),
        ),
      ];
    final state = AppState(store);

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, child) => MaterialApp(
          home: Scaffold(body: MatrixScreen(state: state)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('已完成 1/2'), findsOneWidget);
    final characterTwoControl = find.ancestor(
      of: find.text('角色二'),
      matching: find.byType(InkWell),
    );
    expect(characterTwoControl, findsOneWidget);
    expect(
        tester.getSize(characterTwoControl).height, greaterThanOrEqualTo(40));
    tester.widget<InkWell>(characterTwoControl).onTap!();
    await tester.pumpAndSettle();
    final characterTwoTask =
        store.tasks.singleWhere((task) => task.id == 'task-2');
    expect(
      characterTwoTask.isCompletedOn(state.taskDateFor(characterTwoTask)),
      isTrue,
    );
    expect(find.text('已完成 1/2'), findsNothing);

    final characterOneControl = find.ancestor(
      of: find.text('角色一'),
      matching: find.byType(InkWell),
    );
    expect(characterOneControl, findsOneWidget);
    tester.widget<InkWell>(characterOneControl).onTap!();
    await tester.pumpAndSettle();
    final characterOneTask =
        store.tasks.singleWhere((task) => task.id == 'task-1');
    expect(
      characterOneTask.isCompletedOn(state.taskDateFor(characterOneTask)),
      isFalse,
    );
    expect(find.text('已完成 1/2'), findsOneWidget);
    state.dispose();
  });

  test('multiple task templates can be assigned to characters together',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '角色一',
          occupation: '',
          color: 0xff2f7d72,
        ),
        Character(
          id: 'char-2',
          gameId: 'game-jx3',
          account: '',
          name: '角色二',
          occupation: '',
          color: 0xff5a78aa,
        ),
      ]
      ..tasks = [
        for (final id in ['task-1', 'task-2'])
          TaskRecord(
            id: '$id-char-1',
            templateId: id,
            title: id,
            characterId: 'char-1',
            frequency: TaskFrequency.daily,
            createdAt: DateTime(2026, 9, 1),
          ),
      ];
    final state = AppState(store);

    final skipped = await state.assignTaskTemplatesToCharacters(
      templateIds: {'task-1', 'task-2'},
      characterIds: {'char-2'},
    );

    expect(skipped, isEmpty);
    expect(store.tasks, hasLength(4));
    expect(
      store.tasks.where((task) => task.characterId == 'char-2').length,
      2,
    );
    state.dispose();
  });

  test('date helpers return stable calendar boundaries', () {
    final date = DateTime(2026, 9, 10, 14, 30);
    expect(dateKey(date), '2026-09-10');
    expect(startOfWeek(date), DateTime(2026, 9, 7));
    expect(startOfMonth(date), DateTime(2026, 9));
  });

  test('从全部任务标记次数任务会直接切换整体状态', () async {
    SharedPreferences.setMockInitialValues({});
    final date = DateTime(2026, 9, 16);
    final task = TaskRecord(
      id: 'count-task',
      templateId: 'count-task',
      title: '次数任务',
      characterId: 'character',
      frequency: TaskFrequency.weeklyCount,
      targetCount: 3,
      createdAt: date,
    );
    final store = LocalStore()..tasks = [task];
    final state = AppState(store);

    await state.setTaskCompleted(task, completed: true, date: date);
    expect(store.tasks.single.isCompletedOn(date), isTrue);
    await state.setTaskCompleted(
      store.tasks.single,
      completed: false,
      date: date,
    );
    expect(store.tasks.single.isCompletedOn(date), isFalse);
    state.dispose();
  });

  test('game reset time defines its task day and survives backup data', () {
    const game = Game(
      id: 'game-jx3',
      name: '剑网3',
      dailyResetMinutes: 7 * 60,
    );

    expect(game.taskDayAt(DateTime(2026, 9, 14, 6, 59)), DateTime(2026, 9, 13));
    expect(game.taskDayAt(DateTime(2026, 9, 14, 7)), DateTime(2026, 9, 14));
    expect(Game.fromJson(game.toJson()).dailyResetMinutes, 7 * 60);

    const lateReset = Game(
      id: 'game-hsr',
      name: '崩坏：星穹铁道',
      dailyResetMinutes: 23 * 60,
    );
    expect(lateReset.taskDayAt(DateTime(2026, 9, 14, 22, 59)),
        DateTime(2026, 9, 13));
    expect(
        lateReset.taskDayAt(DateTime(2026, 9, 14, 23)), DateTime(2026, 9, 14));
  });

  test('task state resolves the reset time from the task game', () {
    SharedPreferences.setMockInitialValues({});
    final task = TaskRecord(
      id: 'daily-1',
      templateId: 'daily-1',
      title: '每日任务',
      characterId: 'char-1',
      frequency: TaskFrequency.daily,
      createdAt: DateTime(2026, 9, 14),
    );
    final weeklyTask = TaskRecord(
      id: 'weekly-1',
      templateId: 'weekly-1',
      title: '每周任务',
      characterId: 'char-1',
      frequency: TaskFrequency.weekly,
      createdAt: DateTime(2026, 9, 14, 6, 30),
    );
    final store = LocalStore()
      ..games = const [
        Game(
          id: 'game-jx3',
          name: '剑网3',
          dailyResetMinutes: 7 * 60,
        ),
      ]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '角色一',
          occupation: '',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = [task, weeklyTask];
    final state = AppState(store);

    expect(state.taskDateFor(task, DateTime(2026, 9, 14, 6, 30)),
        DateTime(2026, 9, 13));
    expect(state.taskDateFor(task, DateTime(2026, 9, 14, 7, 30)),
        DateTime(2026, 9, 14));
    expect(state.isTaskScheduledOn(weeklyTask, DateTime(2026, 9, 13)), isTrue);
    expect(state.isTaskScheduledOn(weeklyTask, DateTime(2026, 9, 14)), isFalse);
  });

  test('task start date controls scheduling and survives backup round trips',
      () {
    final task = TaskRecord(
      id: 'daily-starting-later',
      templateId: 'daily-starting-later',
      title: '稍后开始',
      characterId: 'char-1',
      frequency: TaskFrequency.daily,
      createdAt: DateTime(2026, 9, 1),
      startDate: DateTime(2026, 9, 20),
      tags: const ['日常', '重要'],
    );

    expect(task.hasStartedBy(DateTime(2026, 9, 19)), isFalse);
    expect(task.isScheduledOn(DateTime(2026, 9, 19)), isFalse);
    expect(task.isScheduledOn(DateTime(2026, 9, 20)), isTrue);

    final restored = TaskRecord.fromJson(task.toJson());
    expect(restored.startDate, DateTime(2026, 9, 20));
    expect(restored.tags, ['日常', '重要']);
    expect(restored.isScheduledOn(DateTime(2026, 9, 20)), isTrue);
  });

  test('character summaries only include tasks scheduled in the current week',
      () {
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '角色一',
          occupation: '',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = [
        TaskRecord(
          id: 'due-last-week',
          templateId: 'due-last-week',
          title: '截止上周',
          characterId: 'char-1',
          frequency: TaskFrequency.once,
          createdAt: DateTime(2026, 9, 1),
          dueDate: DateTime(2026, 9, 20),
        ),
        TaskRecord(
          id: 'due-this-week',
          templateId: 'due-this-week',
          title: '截止本周',
          characterId: 'char-1',
          frequency: TaskFrequency.once,
          createdAt: DateTime(2026, 9, 1),
          dueDate: DateTime(2026, 9, 21),
        ),
        TaskRecord(
          id: 'monthly-later',
          templateId: 'monthly-later',
          title: '本月稍后',
          characterId: 'char-1',
          frequency: TaskFrequency.monthly,
          createdAt: DateTime(2026, 9, 1),
          dueDate: DateTime(2026, 9, 30),
        ),
      ];
    final state = AppState(store);

    final tasks = state.scheduledTasksInRange(
      store.tasks,
      DateTime(2026, 9, 21),
      DateTime(2026, 9, 28),
    );

    expect(tasks.map((task) => task.id), ['due-this-week']);
  });

  test('count task tracks completions independently', () {
    final task = TaskRecord(
      id: '1',
      templateId: '1',
      title: '浪客行',
      characterId: 'char-1',
      frequency: TaskFrequency.weeklyCount,
      targetCount: 5,
      createdAt: DateTime(2026, 9, 1),
      completedDates: ['2026-09-07', '2026-09-08'],
    );
    expect(task.countInRange(DateTime(2026, 9, 7), DateTime(2026, 9, 14)), 2);
    expect(task.isCountTask, isTrue);
  });

  test('quantity target is independent from weekly and monthly behavior counts',
      () {
    final once = TaskRecord(
      id: 'quantity-once',
      templateId: 'quantity-once',
      title: '小铁',
      characterId: 'char-1',
      frequency: TaskFrequency.once,
      targetQuantity: 200,
      quantityProgress: const {'once': 199},
      createdAt: DateTime(2026, 9, 1),
    );
    expect(once.isCompletedOn(DateTime(2026, 9, 20)), isFalse);
    expect(once.quantityCompletedOn(DateTime(2026, 9, 20)), 199);

    final weeklyQuantity = TaskRecord(
      id: 'quantity-weekly',
      templateId: 'quantity-weekly',
      title: '小铁',
      characterId: 'char-1',
      frequency: TaskFrequency.weekly,
      targetQuantity: 200,
      quantityProgress: const {'2026-09-07': 200},
      createdAt: DateTime(2026, 9, 1),
    );
    expect(weeklyQuantity.isCompletedOn(DateTime(2026, 9, 13)), isTrue);
    expect(weeklyQuantity.isCompletedOn(DateTime(2026, 9, 14)), isFalse);

    final weeklyBehavior = TaskRecord(
      id: 'behavior-weekly',
      templateId: 'behavior-weekly',
      title: '大战',
      characterId: 'char-1',
      frequency: TaskFrequency.weeklyCount,
      targetCount: 4,
      completedDates: const [
        '2026-09-07',
        '2026-09-08',
        '2026-09-09',
        '2026-09-10',
      ],
      createdAt: DateTime(2026, 9, 1),
    );
    expect(weeklyBehavior.isCompletedOn(DateTime(2026, 9, 13)), isTrue);
    expect(weeklyBehavior.hasQuantityTarget, isFalse);
    expect(TaskRecord.fromJson(once.toJson()).targetQuantity, 200);
  });

  test('quantity target records progress and can be undone', () async {
    SharedPreferences.setMockInitialValues({});
    final task = TaskRecord(
      id: 'quantity-state',
      templateId: 'quantity-state',
      title: '花瓣',
      characterId: 'char-1',
      frequency: TaskFrequency.monthly,
      targetQuantity: 3,
      createdAt: DateTime(2026, 9, 1),
    );
    final store = LocalStore()..tasks = [task];
    final state = AppState(store);

    await state.adjustTaskQuantity(task, date: DateTime(2026, 9, 20), delta: 2);
    expect(store.tasks.single.quantityCompletedOn(DateTime(2026, 9, 20)), 2);
    await state.setTaskQuantity(
      task,
      value: 1,
      date: DateTime(2026, 9, 20),
    );
    expect(store.tasks.single.quantityCompletedOn(DateTime(2026, 9, 20)), 1);
    expect(store.tasks.single.isCompletedOn(DateTime(2026, 9, 20)), isFalse);
    await state.toggleTask(store.tasks.single, date: DateTime(2026, 9, 20));
    expect(store.tasks.single.quantityCompletedOn(DateTime(2026, 9, 20)), 2);
    expect(store.tasks.single.isCompletedOn(DateTime(2026, 9, 20)), isFalse);
    await state.setTaskQuantity(
      store.tasks.single,
      value: 3,
      date: DateTime(2026, 9, 20),
    );
    expect(store.tasks.single.isCompletedOn(DateTime(2026, 9, 20)), isTrue);
    await state.toggleTask(store.tasks.single, date: DateTime(2026, 9, 20));
    expect(store.tasks.single.quantityCompletedOn(DateTime(2026, 9, 20)), 2);
    state.dispose();
  });

  test('behavior count can be edited directly within its period', () async {
    SharedPreferences.setMockInitialValues({});
    final task = TaskRecord(
      id: 'count-state',
      templateId: 'count-state',
      title: '大战',
      characterId: 'char-1',
      frequency: TaskFrequency.weeklyCount,
      targetCount: 4,
      createdAt: DateTime(2026, 9, 1),
    );
    final store = LocalStore()..tasks = [task];
    final state = AppState(store);

    await state.setTaskCount(
      task,
      value: 3,
      date: DateTime(2026, 9, 20),
    );
    expect(
        store.tasks.single.countInRange(
          DateTime(2026, 9, 14),
          DateTime(2026, 9, 21),
        ),
        3);
    await state.setTaskCount(
      store.tasks.single,
      value: 1,
      date: DateTime(2026, 9, 20),
    );
    expect(
        store.tasks.single.countInRange(
          DateTime(2026, 9, 14),
          DateTime(2026, 9, 21),
        ),
        1);
    state.dispose();
  });

  test('once task remains completed after its completion date', () async {
    SharedPreferences.setMockInitialValues({});
    final yesterday = DateTime(2026, 9, 12);
    final today = DateTime(2026, 9, 13);
    final task = TaskRecord(
      id: 'once-1',
      templateId: 'once-1',
      title: '一次性任务',
      characterId: 'char-1',
      frequency: TaskFrequency.once,
      createdAt: DateTime(2026, 9, 1),
      completedDates: [dateKey(yesterday)],
      subtasks: [
        TaskSubtask(
          id: 'subtask-1',
          title: '一次性子任务',
          completedDates: [dateKey(yesterday)],
        ),
      ],
    );
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '账号',
          name: '角色',
          occupation: '奶歌',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = [task];
    final state = AppState(store);

    expect(task.isCompletedOn(today), isTrue);
    expect(task.isVisibleOn(today), isFalse);
    expect(task.isSubtaskCompletedOn(task.subtasks.single, today), isTrue);

    await state.toggleTask(task, date: today);
    expect(store.tasks.single.completedDates, isEmpty);

    await state.toggleTask(store.tasks.single, date: today);
    expect(store.tasks.single.completedDates, [dateKey(today)]);
  });

  test('backup filename time takes precedence over unreliable WebDAV mtime',
      () {
    final service = WebDavSyncService();
    final backup = RemoteBackup(
      name: 'backup_20260913_120000000000000_device.json',
      path: '/backup.json',
      modifiedAt: DateTime(2030),
    );

    expect(service.backupTime(backup), DateTime(2026, 9, 13, 12));
  });

  test('calendar date selection also focuses its month', () {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(LocalStore());
    state.selectCalendarDate(DateTime(2027, 2, 18, 19, 30));

    expect(state.selectedCalendarDate, DateTime(2027, 2, 18));
    expect(state.focusedMonth, DateTime(2027, 2));
  });

  test('adding a character in another game selects its game and character',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [
        Game(id: 'game-jx3', name: '剑网3'),
        Game(id: 'game-hsr', name: '崩坏：星穹铁道'),
      ]
      ..characters = const [
        Character(
          id: 'char-jx3',
          gameId: 'game-jx3',
          account: '账号一',
          name: '剑网3角色',
          occupation: '奶歌',
          color: 0xff2f7d72,
        ),
      ];
    final state = AppState(store);

    await state.addCharacter(
      name: '崩铁角色',
      account: '账号二',
      occupation: '',
      gameId: 'game-hsr',
    );

    expect(state.selectedGameId, 'game-hsr');
    expect(state.selectedCharacter?.name, '崩铁角色');
  });

  test('characters can be reordered within the same game', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '角色一',
          occupation: '',
          color: 0xff2f7d72,
        ),
        Character(
          id: 'char-2',
          gameId: 'game-jx3',
          account: '',
          name: '角色二',
          occupation: '',
          color: 0xff66a892,
        ),
        Character(
          id: 'char-3',
          gameId: 'game-jx3',
          account: '',
          name: '角色三',
          occupation: '',
          color: 0xff7fae9e,
        ),
      ];
    final state = AppState(store);

    await state.moveCharacter(store.characters[1], offset: -1);
    expect(store.characters.map((character) => character.id),
        ['char-2', 'char-1', 'char-3']);
    await state.moveCharacter(store.characters[1], offset: 1);
    expect(store.characters.map((character) => character.id),
        ['char-2', 'char-3', 'char-1']);
    state.dispose();
  });

  test('editing a shared task updates fields and preserves completion',
      () async {
    SharedPreferences.setMockInitialValues({});
    final completed = dateKey(DateTime(2026, 9, 13));
    final source = TaskRecord(
      id: 'task-1',
      templateId: 'template-1',
      title: '大战',
      characterId: 'char-1',
      frequency: TaskFrequency.daily,
      createdAt: DateTime(2026, 9, 1),
      completedDates: [completed],
      subtasks: [
        TaskSubtask(
          id: 'subtask-1',
          title: '旧子任务',
          completedDates: [completed],
        ),
      ],
    );
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '角色一',
          occupation: '',
          color: 0xff2f7d72,
        ),
        Character(
          id: 'char-2',
          gameId: 'game-jx3',
          account: '',
          name: '角色二',
          occupation: '',
          color: 0xff5a78aa,
        ),
      ]
      ..tasks = [source];
    final state = AppState(store);

    await state.updateTaskTemplate(
      source: source,
      title: '十人本',
      characterIds: {'char-1', 'char-2'},
      frequency: TaskFrequency.weeklyCount,
      dueDate: DateTime(2026, 10, 1),
      targetCount: 3,
      weeklyDays: [2, 4],
      subtasks: const [
        TaskSubtask(id: 'subtask-1', title: '同步后的子任务'),
        TaskSubtask(id: 'subtask-2', title: '新增子任务'),
      ],
      note: '周四前完成',
    );

    expect(store.tasks, hasLength(2));
    expect(store.tasks.every((task) => task.title == '十人本'), isTrue);
    expect(
        store.tasks
            .every((task) => task.frequency == TaskFrequency.weeklyCount),
        isTrue);
    expect(store.tasks.every((task) => task.targetCount == 3), isTrue);
    expect(store.tasks.first.completedDates, contains(completed));
    expect(store.tasks.last.completedDates, isEmpty);
    expect(
        store.tasks.first.subtasks.first.completedDates, contains(completed));
    expect(store.tasks.last.subtasks.first.completedDates, isEmpty);

    final firstCharacterTask =
        store.tasks.firstWhere((task) => task.characterId == 'char-1');
    await state.updateTaskRecord(
      source: firstCharacterTask,
      title: '角色一专属十人本',
      frequency: firstCharacterTask.frequency,
      dueDate: firstCharacterTask.dueDate,
      targetCount: firstCharacterTask.targetCount,
      weeklyDays: firstCharacterTask.weeklyDays,
      subtasks: const [
        TaskSubtask(id: 'subtask-1', title: '角色一专属子任务'),
      ],
    );

    expect(store.tasks.firstWhere((task) => task.characterId == 'char-1').title,
        '角色一专属十人本');
    expect(store.tasks.firstWhere((task) => task.characterId == 'char-2').title,
        '十人本');
    expect(
        store.tasks.firstWhere((task) => task.characterId == 'char-2').subtasks,
        hasLength(2));
  });

  test('inbox tasks stay outside character task lists until assigned',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '账号一',
          name: '角色一',
          occupation: '奶歌',
          color: 0xff2f7d72,
        ),
        Character(
          id: 'char-2',
          gameId: 'game-jx3',
          account: '账号二',
          name: '角色二',
          occupation: '冰心',
          color: 0xff5a78aa,
        ),
      ];
    final state = AppState(store);

    await state.addInboxTask(
      title: '想做的新任务',
      dueDate: DateTime(2026, 9, 18),
      subtasks: const [TaskSubtask(id: 'subtask-1', title: '先查攻略')],
      note: '稍后安排',
    );

    expect(state.inboxTasks, hasLength(1));
    expect(state.tasks, isEmpty);
    expect(state.inboxTasks.single.isInbox, isTrue);
    expect(state.inboxTasks.single.hasConfiguredFrequency, isFalse);
    expect(state.inboxTasks.single.dueDate, DateTime(2026, 9, 18));

    final inboxTask = state.inboxTasks.single;
    await state.updateInboxTask(
      source: inboxTask,
      title: inboxTask.title,
      frequency: TaskFrequency.weekly,
      dueDate: DateTime(2026, 9, 20),
      weeklyDays: const [6],
      subtasks: inboxTask.subtasks,
      note: inboxTask.note,
    );

    final scheduledInboxTask = state.inboxTasks.single;
    expect(scheduledInboxTask.hasConfiguredFrequency, isTrue);
    expect(scheduledInboxTask.frequency, TaskFrequency.weekly);
    expect(scheduledInboxTask.dueDate, DateTime(2026, 9, 20));
    final restoredInboxTask = TaskRecord.fromJson(scheduledInboxTask.toJson());
    expect(restoredInboxTask.hasConfiguredFrequency, isTrue);
    expect(restoredInboxTask.dueDate, DateTime(2026, 9, 20));

    await state.assignInboxTask(
      source: scheduledInboxTask,
      title: scheduledInboxTask.title,
      characterIds: {'char-1', 'char-2'},
      frequency: scheduledInboxTask.frequency,
      dueDate: scheduledInboxTask.dueDate,
      targetCount: 1,
      weeklyDays: scheduledInboxTask.weeklyDays,
      subtasks: scheduledInboxTask.subtasks,
      note: scheduledInboxTask.note,
    );

    expect(state.inboxTasks, isEmpty);
    expect(state.tasks, hasLength(2));
    expect(state.tasks.map((task) => task.characterId).toSet(),
        {'char-1', 'char-2'});
    expect(state.tasks.every((task) => task.frequency == TaskFrequency.weekly),
        isTrue);
    expect(state.tasks.every((task) => task.dueDate == DateTime(2026, 9, 20)),
        isTrue);
    expect(state.tasks.every((task) => task.subtasks.length == 1), isTrue);
  });

  test('assigned tasks can move to inbox or be deleted as a group', () async {
    SharedPreferences.setMockInitialValues({});
    TaskRecord assigned(String id, String characterId) => TaskRecord(
          id: id,
          templateId: 'template-shared',
          title: '共享任务',
          characterId: characterId,
          frequency: TaskFrequency.weekly,
          createdAt: DateTime(2026, 9, 1),
          dueDate: DateTime(2026, 9, 30),
          weeklyDays: const [3, 6],
          completedDates: const ['2026-09-13'],
          subtasks: const [
            TaskSubtask(id: 'subtask-1', title: '保留子任务名称'),
          ],
          note: '保留备注',
        );
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '账号一',
          name: '角色一',
          occupation: '奶歌',
          color: 0xff2f7d72,
        ),
        Character(
          id: 'char-2',
          gameId: 'game-jx3',
          account: '账号二',
          name: '角色二',
          occupation: '冰心',
          color: 0xff5a78aa,
        ),
      ]
      ..tasks = [assigned('task-1', 'char-1'), assigned('task-2', 'char-2')];
    final state = AppState(store);

    await state.moveTaskToInbox(store.tasks.first, allLinked: false);

    expect(state.inboxTasks, hasLength(1));
    expect(state.tasks, hasLength(1));
    expect(state.tasks.single.characterId, 'char-2');
    expect(state.inboxTasks.single.hasConfiguredFrequency, isTrue);
    expect(state.inboxTasks.single.frequency, TaskFrequency.weekly);
    expect(state.inboxTasks.single.dueDate, DateTime(2026, 9, 30));
    expect(state.inboxTasks.single.weeklyDays, [3, 6]);
    expect(state.inboxTasks.single.completedDates, isEmpty);
    expect(state.inboxTasks.single.subtasks.single.title, '保留子任务名称');
    expect(state.inboxTasks.single.note, '保留备注');

    await state.deleteTask(state.tasks.single, allLinked: true);
    expect(state.tasks, isEmpty);
    expect(state.inboxTasks, hasLength(1));
  });

  test('task templates can be archived, restored, and serialized', () async {
    SharedPreferences.setMockInitialValues({});
    TaskRecord assigned(String id, String characterId) => TaskRecord(
          id: id,
          templateId: 'template-archive',
          title: '可归档任务',
          characterId: characterId,
          frequency: TaskFrequency.daily,
          createdAt: DateTime(2026, 9, 1),
        );
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '角色一',
          occupation: '',
          color: 0xff2f7d72,
        ),
        Character(
          id: 'char-2',
          gameId: 'game-jx3',
          account: '',
          name: '角色二',
          occupation: '',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = [assigned('task-1', 'char-1'), assigned('task-2', 'char-2')];
    final state = AppState(store);

    await state.setTaskTemplatesArchived(
      {'template-archive'},
      archived: true,
    );

    expect(state.tasks, isEmpty);
    expect(state.calendarTasks(), isEmpty);
    expect(store.tasks.every((task) => task.archived), isTrue);
    expect(TaskRecord.fromJson(store.tasks.first.toJson()).archived, isTrue);

    await state.setTaskTemplatesArchived(
      {'template-archive'},
      archived: false,
    );

    expect(state.tasks, hasLength(2));
    expect(store.tasks.every((task) => !task.archived), isTrue);
  });

  test('an inbox task without a start date begins when it is assigned',
      () async {
    SharedPreferences.setMockInitialValues({});
    final inbox = TaskRecord(
      id: 'template-later-inbox',
      templateId: 'template-later',
      title: '稍后分配',
      characterId: '',
      frequency: TaskFrequency.daily,
      createdAt: DateTime(2026, 1, 1),
      inboxGameId: 'game-jx3',
      inboxFrequencySet: true,
    );
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '角色一',
          occupation: '',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = [inbox];
    final state = AppState(store);
    final beforeAssignment = DateTime.now();

    await state.assignInboxTask(
      source: inbox,
      title: inbox.title,
      characterIds: {'char-1'},
      frequency: inbox.frequency,
      targetCount: 1,
    );

    final assigned = store.tasks.single;
    expect(assigned.startDate, isNull);
    expect(assigned.createdAt.isBefore(beforeAssignment), isFalse);
    expect(assigned.hasStartedBy(DateTime.now()), isTrue);
  });

  test('weekly and monthly tasks keep completion for their period', () {
    final weekly = TaskRecord(
      id: 'weekly',
      templateId: 'weekly',
      title: '周任务',
      characterId: 'char-1',
      frequency: TaskFrequency.weekly,
      createdAt: DateTime(2026, 9, 1),
      weeklyDays: const [2, 4],
      completedDates: const ['2026-09-08'],
    );
    final monthly = TaskRecord(
      id: 'monthly',
      templateId: 'monthly',
      title: '月任务',
      characterId: 'char-1',
      frequency: TaskFrequency.monthly,
      createdAt: DateTime(2026, 9, 1),
      completedDates: const ['2026-09-03'],
    );

    expect(weekly.isCompletedOn(DateTime(2026, 9, 10)), isTrue);
    expect(weekly.isCompletedOn(DateTime(2026, 9, 15)), isFalse);
    expect(weekly.isScheduledOn(DateTime(2026, 9, 10)), isTrue);
    expect(weekly.isScheduledOn(DateTime(2026, 9, 11)), isFalse);
    expect(monthly.isCompletedOn(DateTime(2026, 9, 28)), isTrue);
    expect(monthly.isCompletedOn(DateTime(2026, 10, 1)), isFalse);

    final weeklyCount = TaskRecord(
      id: 'weekly-count',
      templateId: 'weekly-count',
      title: '周目标',
      characterId: 'char-1',
      frequency: TaskFrequency.weeklyCount,
      createdAt: DateTime(2026, 9, 1),
      targetCount: 3,
    );
    final monthlyCount = TaskRecord(
      id: 'monthly-count',
      templateId: 'monthly-count',
      title: '月目标',
      characterId: 'char-1',
      frequency: TaskFrequency.monthlyCount,
      createdAt: DateTime(2026, 9, 1),
      targetCount: 8,
    );
    expect(weeklyCount.isScheduledOn(DateTime(2026, 9, 10)), isTrue);
    expect(monthlyCount.isScheduledOn(DateTime(2026, 9, 28)), isTrue);
  });

  test('finishing all binary subtasks completes their parent', () async {
    SharedPreferences.setMockInitialValues({});
    final task = TaskRecord(
      id: 'task-subtasks',
      templateId: 'task-subtasks',
      title: '带子任务的周常',
      characterId: 'char-1',
      frequency: TaskFrequency.weekly,
      createdAt: DateTime(2026, 9, 1),
      subtasks: const [
        TaskSubtask(id: 'subtask-1', title: '步骤一'),
        TaskSubtask(id: 'subtask-2', title: '步骤二'),
      ],
    );
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '账号',
          name: '角色',
          occupation: '奶歌',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = [task];
    final state = AppState(store);
    final date = DateTime(2026, 9, 10);

    await state.toggleSubtask(task, task.subtasks.first, date: date);
    expect(store.tasks.single.isCompletedOn(date), isFalse);
    await state.toggleSubtask(
        store.tasks.single, store.tasks.single.subtasks.last,
        date: date);
    expect(store.tasks.single.isCompletedOn(date), isTrue);
  });

  testWidgets('calendar task shows independently completable subtasks',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final date = DateTime(2026, 9, 10);
    final task = TaskRecord(
      id: 'calendar-task',
      templateId: 'calendar-task',
      title: '日历任务',
      characterId: 'char-1',
      frequency: TaskFrequency.once,
      createdAt: DateTime(2026, 9, 1),
      dueDate: date,
      subtasks: const [
        TaskSubtask(id: 'subtask-1', title: '日历子任务一'),
        TaskSubtask(id: 'subtask-2', title: '日历子任务二'),
      ],
    );
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '账号',
          name: '角色',
          occupation: '奶歌',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = [task];
    final state = AppState(store)..selectCalendarDate(date);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, child) => CalendarScreen(state: state),
          ),
        ),
      ),
    );

    expect(find.text('日历子任务一'), findsOneWidget);
    expect(find.text('日历子任务二'), findsOneWidget);
    final firstSubtask =
        find.byKey(const ValueKey('calendar-subtask-calendar-task-subtask-1'));
    await tester.ensureVisible(firstSubtask);
    await tester.tap(firstSubtask);
    await tester.pumpAndSettle();

    expect(
      store.tasks.single
          .isSubtaskCompletedOn(store.tasks.single.subtasks.first, date),
      isTrue,
    );
    expect(store.tasks.single.isCompletedOn(date), isFalse);
    state.dispose();
  });

  test('inbox includes every game and archived characters can be restored',
      () async {
    SharedPreferences.setMockInitialValues({});
    const archived = Character(
      id: 'char-archived',
      gameId: 'game-jx3',
      account: '账号',
      name: '归档角色',
      occupation: '奶歌',
      color: 0xff2f7d72,
      archived: true,
    );
    final store = LocalStore()
      ..games = const [
        Game(id: 'game-jx3', name: '剑网3'),
        Game(id: 'game-hsr', name: '崩坏：星穹铁道'),
      ]
      ..characters = [archived]
      ..tasks = [
        TaskRecord(
          id: 'inbox-jx3',
          templateId: 'inbox-jx3',
          title: '剑网3 收集箱',
          characterId: '',
          frequency: TaskFrequency.once,
          createdAt: DateTime(2026, 9, 1),
          inboxGameId: 'game-jx3',
        ),
        TaskRecord(
          id: 'inbox-hsr',
          templateId: 'inbox-hsr',
          title: '崩铁收集箱',
          characterId: '',
          frequency: TaskFrequency.once,
          createdAt: DateTime(2026, 9, 1),
          inboxGameId: 'game-hsr',
        ),
      ];
    final state = AppState(store);

    expect(state.inboxTasks.map((task) => task.title).toSet(),
        {'剑网3 收集箱', '崩铁收集箱'});
    state.selectGame('game-hsr');
    expect(state.inboxTasks.map((task) => task.title).toSet(),
        {'剑网3 收集箱', '崩铁收集箱'});
    await state.restoreCharacter(archived);
    expect(store.characters.single.archived, isFalse);
  });

  testWidgets('home game selector lives below the page title and nowhere else',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const []
      ..tasks = const [];
    final state = AppState(store);

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, child) => MaterialApp(home: HomeShell(state: state)),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('home-game-filter')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('home-game-filter'))).dy,
      greaterThan(tester.getTopLeft(find.text('今日待办')).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('home-game-counts'))).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const ValueKey('home-game-filter'))).dy,
      ),
    );
    final menuButton = find.byKey(const ValueKey('home-game-menu'));
    final menuLeft = tester.getTopLeft(menuButton).dx;
    await tester.tap(menuButton);
    await tester.pumpAndSettle();
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('home-game-option-game-jx3')),
          )
          .dx,
      closeTo(menuLeft, 1),
    );
    await tester.tap(find.text('剑网3').last);
    await tester.pumpAndSettle();

    for (final tab in [1, 2, 3, 4]) {
      state.setTab(tab);
      await tester.pump();
      expect(find.byKey(const ValueKey('home-game-filter')), findsNothing);
    }
    state.dispose();
  });

  testWidgets('home game summary counts only unfinished tasks', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '账号',
          name: '角色',
          occupation: '奶歌',
          color: 0xff2f7d72,
        ),
        Character(
          id: 'char-2',
          gameId: 'game-jx3',
          account: '账号',
          name: '已完成角色',
          occupation: '奶歌',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = [
        TaskRecord(
          id: 'completed-task',
          templateId: 'completed-task',
          title: '已完成任务',
          characterId: 'char-1',
          frequency: TaskFrequency.once,
          createdAt: DateTime(2026, 9, 1),
          completedDates: const ['2026-09-01'],
        ),
        TaskRecord(
          id: 'completed-task-2',
          templateId: 'completed-task-2',
          title: '另一角色已完成任务',
          characterId: 'char-2',
          frequency: TaskFrequency.once,
          createdAt: DateTime(2026, 9, 1),
          completedDates: const ['2026-09-01'],
        ),
        TaskRecord(
          id: 'pending-task',
          templateId: 'pending-task',
          title: '未完成任务',
          characterId: 'char-1',
          frequency: TaskFrequency.once,
          createdAt: DateTime(2026, 9, 1),
        ),
        TaskRecord(
          id: 'inbox-task',
          templateId: 'inbox-task',
          title: '收集箱任务',
          characterId: '',
          frequency: TaskFrequency.once,
          createdAt: DateTime(2026, 9, 1),
          inboxGameId: 'game-jx3',
        ),
      ];

    await tester.pumpWidget(Jx3TasksApp(store: store));
    await tester.pump();

    expect(find.text('1 个角色 · 2 个任务'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home shell fits a narrow phone width', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const []
      ..tasks = const [];

    await tester.pumpWidget(Jx3TasksApp(store: store));
    await tester.pump();

    expect(find.text('今日待办'), findsOneWidget);
    final glassNavigation = find.byKey(
      const ValueKey('glass-bottom-navigation'),
    );
    expect(glassNavigation, findsOneWidget);
    expect(
      find.descendant(
        of: glassNavigation,
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    final navigationContainer = tester.widget<Container>(glassNavigation);
    expect(
      (navigationContainer.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(24),
    );
    final navigationSurface = tester.widget<Container>(
      find.byKey(const ValueKey('glass-bottom-navigation-surface')),
    );
    expect(
      (navigationSurface.decoration! as BoxDecoration).color,
      isNot(AppTheme.light.colorScheme.surface),
    );
    final glassCreateButton = find.byKey(
      const ValueKey('glass-create-task-button'),
    );
    expect(glassCreateButton, findsOneWidget);
    expect(
      find.descendant(
        of: glassCreateButton,
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    final createButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(createButton.elevation, 0);
    expect(
      createButton.backgroundColor,
      isNot(AppTheme.light.colorScheme.surface),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('character actions move below the subtitle on narrow screens',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const []
      ..tasks = const [];
    final state = AppState(store);

    await tester.pumpWidget(
      MaterialApp(home: CharactersScreen(state: state)),
    );
    await tester.pump();

    final actions = find.byKey(const ValueKey('mobile-character-actions'));
    expect(actions, findsOneWidget);
    expect(find.text('批量管理'), findsOneWidget);
    expect(find.text('添加角色'), findsOneWidget);
    expect(
      tester.getTopLeft(actions).dy,
      greaterThan(tester.getBottomLeft(find.text('按游戏管理角色；可在角色菜单中调整显示顺序')).dy),
    );
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('首页保留当天完成的角色并在下一任务日隐藏', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final today = dateKey(DateTime.now());
    final store = LocalStore()
      ..games = const [Game(id: 'game', name: '游戏')]
      ..characters = const [
        Character(
          id: 'done-character',
          gameId: 'game',
          account: '',
          name: '已清空角色',
          occupation: '',
          color: 0xff2f7d72,
        ),
        Character(
          id: 'pending-character',
          gameId: 'game',
          account: '',
          name: '仍有待办角色',
          occupation: '',
          color: 0xff5a78aa,
        ),
        Character(
          id: 'previously-done-character',
          gameId: 'game',
          account: '',
          name: '昨日已清空角色',
          occupation: '',
          color: 0xff8a6f4d,
        ),
      ]
      ..tasks = [
        TaskRecord(
          id: 'done-task',
          templateId: 'done-task',
          title: '已完成任务',
          characterId: 'done-character',
          frequency: TaskFrequency.daily,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          completedDates: [today],
        ),
        TaskRecord(
          id: 'pending-task',
          templateId: 'pending-task',
          title: '尚未完成任务',
          characterId: 'pending-character',
          frequency: TaskFrequency.daily,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        TaskRecord(
          id: 'previously-done-task',
          templateId: 'previously-done-task',
          title: '昨日完成的一次性任务',
          characterId: 'previously-done-character',
          frequency: TaskFrequency.once,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          dueDate: DateTime.now().subtract(const Duration(days: 1)),
          completedDates: [
            dateKey(DateTime.now().subtract(const Duration(days: 1))),
          ],
        ),
      ];
    final state = AppState(store);

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder: (context, child) => MaterialApp(
          home: Scaffold(body: DashboardScreen(state: state)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('已清空角色'), findsWidgets);
    expect(find.text('仍有待办角色'), findsWidgets);
    expect(find.text('昨日已清空角色'), findsNothing);
    expect(find.text('今日已完成'), findsOneWidget);
    expect(find.text('1 个待办'), findsOneWidget);

    await tester.tap(find.text('仍有待办角色'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TaskCheck).first);
    await tester.pumpAndSettle();

    expect(find.text('已清空角色'), findsWidgets);
    expect(find.text('仍有待办角色'), findsWidgets);
    expect(find.text('今日已完成'), findsNWidgets(2));
    expect(find.text('今天的任务都完成了'), findsNothing);
    state.dispose();
  });

  testWidgets('unfinished once task stays visible before its due date',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const [
        Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '角色一',
          occupation: '',
          color: 0xff2f7d72,
        ),
      ]
      ..tasks = [
        TaskRecord(
          id: 'once-future',
          templateId: 'once-future',
          title: '截止日前持续显示',
          characterId: 'char-1',
          frequency: TaskFrequency.once,
          createdAt: now.subtract(const Duration(days: 1)),
          dueDate: now.add(const Duration(days: 3)),
        ),
      ];

    await tester.pumpWidget(Jx3TasksApp(store: store));
    await tester.pump();

    expect(find.text('截止日前持续显示'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('calendar includes every active game and supports game filtering', () {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [
        Game(id: 'game-jx3', name: '剑网3'),
        Game(id: 'game-hsr', name: '崩坏：星穹铁道'),
      ]
      ..characters = const [
        Character(
          id: 'char-jx3',
          gameId: 'game-jx3',
          account: '',
          name: '剑网3角色',
          occupation: '',
          color: 0xff2f7d72,
        ),
        Character(
          id: 'char-hsr',
          gameId: 'game-hsr',
          account: '',
          name: '崩铁角色',
          occupation: '',
          color: 0xff5a78aa,
        ),
        Character(
          id: 'char-archived',
          gameId: 'game-hsr',
          account: '',
          name: '已归档角色',
          occupation: '',
          color: 0xff8b6e54,
          archived: true,
        ),
      ]
      ..tasks = [
        TaskRecord(
          id: 'task-jx3',
          templateId: 'task-jx3',
          title: '剑网3任务',
          characterId: 'char-jx3',
          frequency: TaskFrequency.daily,
          createdAt: DateTime(2026, 9, 1),
        ),
        TaskRecord(
          id: 'task-hsr',
          templateId: 'task-hsr',
          title: '崩铁任务',
          characterId: 'char-hsr',
          frequency: TaskFrequency.daily,
          createdAt: DateTime(2026, 9, 1),
        ),
        TaskRecord(
          id: 'task-archived',
          templateId: 'task-archived',
          title: '归档任务',
          characterId: 'char-archived',
          frequency: TaskFrequency.daily,
          createdAt: DateTime(2026, 9, 1),
        ),
        TaskRecord(
          id: 'task-inbox',
          templateId: 'task-inbox',
          title: '收集箱任务',
          characterId: '',
          frequency: TaskFrequency.once,
          createdAt: DateTime(2026, 9, 1),
          inboxGameId: 'game-hsr',
        ),
      ];
    final state = AppState(store);

    expect(state.calendarTasks().map((task) => task.title).toSet(),
        {'剑网3任务', '崩铁任务'});
    expect(state.calendarTasks(gameId: 'game-hsr').single.title, '崩铁任务');
  });

  testWidgets('game bar shows the last successful sync time', (tester) async {
    SharedPreferences.setMockInitialValues({
      'webdav.lastSyncAt': '2026-09-14T20:35:12',
    });
    final store = LocalStore()
      ..games = const [Game(id: 'game-jx3', name: '剑网3')]
      ..characters = const []
      ..tasks = const [];

    await tester.pumpWidget(Jx3TasksApp(store: store));
    await tester.pump();
    await tester.pump();

    expect(find.text('上次成功 09/14 20:35'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('game metadata supports common table field types and round trips', () {
    const game = Game(
      id: 'game-meta',
      name: '元数据游戏',
      metadataFields: [
        GameMetadataField(id: 'text', name: '文本', type: MetadataFieldType.text),
        GameMetadataField(
            id: 'long', name: '备注', type: MetadataFieldType.multiline),
        GameMetadataField(
            id: 'number', name: '等级', type: MetadataFieldType.number),
        GameMetadataField(
            id: 'choice',
            name: '服务器',
            type: MetadataFieldType.choice,
            options: ['一服', '二服']),
        GameMetadataField(
            id: 'multi',
            name: '标签',
            type: MetadataFieldType.multiChoice,
            options: ['副本', '休闲']),
        GameMetadataField(
            id: 'bool', name: '主角色', type: MetadataFieldType.boolean),
        GameMetadataField(
            id: 'date', name: '创建日期', type: MetadataFieldType.date),
        GameMetadataField(
            id: 'time', name: '上线时间', type: MetadataFieldType.time),
        GameMetadataField(id: 'url', name: '攻略链接', type: MetadataFieldType.url),
      ],
    );
    final restored = Game.fromJson(game.toJson());
    expect(restored.metadataFields.map((field) => field.type).toSet(),
        MetadataFieldType.values.toSet());

    final character = Character(
      id: 'character-meta',
      gameId: game.id,
      account: '账号',
      name: '角色',
      occupation: '',
      color: 0xff3c8c72,
      metadataValues: const {
        'multi': '副本\\n休闲',
        'bool': 'true',
        'date': '2026-09-14',
      },
    );
    final restoredCharacter = Character.fromJson(character.toJson());
    expect(restoredCharacter.metadataValues, character.metadataValues);
    expect(restoredCharacter.metadataSummary(game), contains('副本、休闲'));
    expect(restoredCharacter.metadataSummary(game), contains('主角色：是'));
  });
}

class _FakeSyncSettingsStore extends SyncSettingsStore {
  static const config = SyncConfig(
    url: 'https://example.com/dav/',
    username: 'user',
    password: 'password',
    remotePath: '/RoleSchedule/backup.json',
  );
  String? currentBackupPath;

  @override
  Future<SyncConfig> load() async => config;

  @override
  Future<DateTime?> loadLastSyncAt() async => null;

  @override
  Future<void> saveLastSyncAt(DateTime value) async {}

  @override
  Future<String?> loadCurrentBackupPath() async => currentBackupPath;

  @override
  Future<void> saveCurrentBackupPath(String? path) async {
    currentBackupPath = path;
  }
}

class _FakeWebDavSyncService extends WebDavSyncService {
  _FakeWebDavSyncService(this.downloadPayload);

  final String downloadPayload;
  int downloadCount = 0;
  int uploadCount = 0;
  int listCount = 0;

  @override
  Future<String> downloadBackup(
    SyncConfig config,
    RemoteBackup backup,
  ) async {
    downloadCount++;
    return downloadPayload;
  }

  @override
  Future<RemoteBackup> upload(SyncConfig config, String json) async {
    uploadCount++;
    return const RemoteBackup(name: 'new.json', path: '/new.json');
  }

  @override
  Future<List<RemoteBackup>> listBackups(SyncConfig config) async {
    listCount++;
    return const [];
  }
}
