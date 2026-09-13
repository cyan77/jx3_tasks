import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jx3_tasks/data/local_store.dart';
import 'package:jx3_tasks/data/sync_service.dart';
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
    expect(store.tasks.every(
        (task) => task.frequency == TaskFrequency.weeklyCount), isTrue);
    expect(store.tasks.every((task) => task.targetCount == 3), isTrue);
    expect(store.tasks.first.completedDates, contains(completed));
    expect(store.tasks.last.completedDates, isEmpty);
    expect(store.tasks.first.subtasks.first.completedDates, contains(completed));
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

    expect(
        store.tasks.firstWhere((task) => task.characterId == 'char-1').title,
        '角色一专属十人本');
    expect(
        store.tasks.firstWhere((task) => task.characterId == 'char-2').title,
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
      subtasks: const [TaskSubtask(id: 'subtask-1', title: '先查攻略')],
      note: '稍后安排',
    );

    expect(state.inboxTasks, hasLength(1));
    expect(state.tasks, isEmpty);
    expect(state.inboxTasks.single.isInbox, isTrue);
    expect(state.inboxTasks.single.dueDate, isNull);

    final inboxTask = state.inboxTasks.single;
    await state.assignInboxTask(
      source: inboxTask,
      title: inboxTask.title,
      characterIds: {'char-1', 'char-2'},
      frequency: TaskFrequency.weekly,
      dueDate: DateTime(2026, 9, 20),
      targetCount: 1,
      weeklyDays: const [6],
      subtasks: inboxTask.subtasks,
      note: inboxTask.note,
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
}
