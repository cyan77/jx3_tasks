import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jx3_tasks/data/local_store.dart';
import 'package:jx3_tasks/models/task_models.dart';
import 'package:jx3_tasks/state/app_state.dart';

void main() {
  test('disabled characters retain data but leave daily and calendar lists', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore()
      ..games = const [Game(id: 'g', name: '游戏')]
      ..characters = const [Character(id: 'c', gameId: 'g', account: '',
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
    expect(state.calendarTasks(), hasLength(1));
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
