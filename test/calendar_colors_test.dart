import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jx3_tasks/data/local_store.dart';
import 'package:jx3_tasks/models/task_models.dart';
import 'package:jx3_tasks/state/app_state.dart';
import 'package:jx3_tasks/theme/app_theme.dart';
import 'package:jx3_tasks/theme/tag_colors.dart';
import 'package:jx3_tasks/ui/screens/calendar_screen.dart';

void main() {
  testWidgets('calendar deadline dots use the configured game color',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final today = DateTime.now();
    final store = LocalStore()
      ..games = [Game(id: 'game', name: '测试游戏', color: TagColors.colorAt(2))]
      ..characters = const [Character(id: 'char', gameId: 'game',
        account: '', name: '测试角色', occupation: '', color: 0xff3c8c72)]
      ..tasks = [TaskRecord(id: 'task', templateId: 'task', title: '测试任务',
        characterId: 'char', frequency: TaskFrequency.once,
        createdAt: today, dueDate: today)];
    final state = AppState(store)..selectCalendarDate(today);
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
      home: Scaffold(body: CalendarScreen(state: state))));
    await tester.pump();
    final dot = tester.widget<Container>(find.byKey(
      ValueKey('calendar-game-dot-${dateKey(today)}-game')));
    expect((dot.decoration! as BoxDecoration).color,
      TagColors.forLabel('测试游戏', Brightness.light,
        color: store.games.single.color).foreground);
    expect(find.text('测试角色'), findsWidgets);
    expect(find.text('一次性'), findsWidgets);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('calendar-layout-toggle'));
    expect(toggle, findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-task-columns')), findsWidgets);
    await tester.tap(find.descendant(of: toggle, matching: find.text('一列')));
    await tester.pumpAndSettle();
    expect(state.calendarMultiColumn, isFalse);
    expect(find.byKey(const ValueKey('calendar-task-columns')), findsNothing);
    await tester.tap(find.descendant(of: toggle, matching: find.text('多列')));
    await tester.pumpAndSettle();
    expect(state.calendarMultiColumn, isTrue);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(toggle, findsNothing);
    expect(find.byKey(const ValueKey('calendar-task-columns')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
