import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jx3_tasks/data/local_store.dart';
import 'package:jx3_tasks/models/task_models.dart';
import 'package:jx3_tasks/state/app_state.dart';

void main() {
  test('date helpers return stable calendar boundaries', () {
    final date = DateTime(2026, 9, 10, 14, 30);
    expect(dateKey(date), '2026-09-10');
    expect(startOfWeek(date), DateTime(2026, 9, 7));
    expect(startOfMonth(date), DateTime(2026, 9));
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
      note: '周四前完成',
    );

    expect(store.tasks, hasLength(2));
    expect(store.tasks.every((task) => task.title == '十人本'), isTrue);
    expect(store.tasks.every(
        (task) => task.frequency == TaskFrequency.weeklyCount), isTrue);
    expect(store.tasks.every((task) => task.targetCount == 3), isTrue);
    expect(store.tasks.first.completedDates, contains(completed));
    expect(store.tasks.last.completedDates, isEmpty);
  });
}
