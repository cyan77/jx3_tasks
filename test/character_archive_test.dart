import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:jx3_tasks/ui/screens/matrix_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jx3_tasks/data/local_store.dart';
import 'package:jx3_tasks/models/task_models.dart';
import 'package:jx3_tasks/state/app_state.dart';

void main() {
  testWidgets('disabling detaches assignments and enabling does not restore them', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'g', name: '游戏')]
      ..characters = [
        for (final id in ['a', 'b'])
          Character(id: id, gameId: 'g', account: '', name: '角色$id',
            occupation: '', color: 0xff3c8c72),
      ]
      ..tasks = [
        for (final id in ['a', 'b'])
          TaskRecord(id: id, templateId: 'shared', title: '共享任务',
            characterId: id, frequency: TaskFrequency.once, createdAt: DateTime.now()),
      ];
    final state = AppState(store);
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AnimatedBuilder(
      animation: state, builder: (_, __) => MatrixScreen(state: state)))));
    await tester.pumpAndSettle();
    await state.setCharacterDisabled(store.characters.first, true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-character-a')), findsNothing);
    expect(find.byKey(const ValueKey('task-character-b')), findsOneWidget);
    expect(store.tasks.map((task) => task.characterId), ['b']);
    await state.setCharacterDisabled(store.characters.last, true);
    await tester.pumpAndSettle();
    expect(find.text('共享任务'), findsOneWidget);
    expect(store.tasks, hasLength(1));
    expect(store.tasks.single.isInbox, isTrue);
    await state.setCharacterDisabled(store.characters.first, false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-character-a')), findsNothing);
    expect(store.tasks.single.isInbox, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('disabled characters retain data but leave daily and calendar lists', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'g', name: '游戏')]
      ..characters = [const Character(id: 'c', gameId: 'g', account: '',
        name: '角色', occupation: '', color: 0xff3c8c72)]
      ..tasks = [TaskRecord(id: 't', templateId: 't', title: '任务',
        characterId: 'c', frequency: TaskFrequency.once, createdAt: DateTime.now())];
    final state = AppState(store);
    addTearDown(state.dispose);
    await state.setCharacterDisabled(store.characters.single, true);
    expect(state.characters, isEmpty);
    expect(state.calendarTasks(), isEmpty);
    expect(store.tasks, hasLength(1));
    expect(Character.fromJson(store.characters.single.toJson()).disabled, isTrue);
    await state.setCharacterDisabled(store.characters.single, false);
    expect(state.characters, hasLength(1));
    expect(state.calendarTasks(), isEmpty);
    expect(store.tasks.single.isInbox, isTrue);
  });

  test('completed once tasks archive only after the game reset', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'g', name: '游戏', dailyResetMinutes: 420)]
      ..characters = const [Character(id: 'c', gameId: 'g', account: '',
        name: '角色', occupation: '', color: 0xff3c8c72)]
      ..tasks = [TaskRecord(id: 't', templateId: 't', title: '任务',
        characterId: 'c', frequency: TaskFrequency.once,
        createdAt: DateTime(2026, 10, 30), completedDates: ['2026-10-31'])];
    final state = AppState(store);
    addTearDown(state.dispose);
    await state.archiveCompletedOnceTasks(moment: DateTime(2026, 11, 1, 6, 59));
    expect(store.tasks.single.archived, isFalse);
    await state.archiveCompletedOnceTasks(moment: DateTime(2026, 11, 1, 7));
    expect(store.tasks.single.archived, isTrue);
    expect(state.automaticArchiveRevision, 1);
  });
}
