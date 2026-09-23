import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_models.dart';

class LocalStore {
  static const _gamesKey = 'games';
  static const _charactersKey = 'characters';
  static const _tasksKey = 'tasks';
  static const _dataDirectoryKey = 'data.directory';
  static const dataFileName = 'role_schedule_data.json';

  List<Game> games = [];
  List<Character> characters = [];
  List<TaskRecord> tasks = [];
  String? _dataDirectory;

  String? get dataDirectory => _dataDirectory;

  static String dataFilePathFor(String directory) =>
      '${Directory(directory).absolute.path}${Platform.pathSeparator}$dataFileName';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _dataDirectory = _normalizeDirectory(
      preferences.getString(_dataDirectoryKey),
    );
    if (_dataDirectory != null) {
      final file = File(dataFilePathFor(_dataDirectory!));
      if (!await file.exists()) {
        throw StateError('找不到本地数据文件：${file.path}');
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        throw const FormatException('本地数据文件格式无效');
      }
      _loadPayload(Map<String, dynamic>.from(decoded));
      return;
    }

    final gamesJson = preferences.getString(_gamesKey);
    final charactersJson = preferences.getString(_charactersKey);
    final tasksJson = preferences.getString(_tasksKey);
    if (charactersJson == null && tasksJson == null) {
      _loadDemoData();
      await save();
      return;
    }
    characters = (jsonDecode(charactersJson ?? '[]') as List)
        .map((item) =>
            Character.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    games = gamesJson == null
        ? [const Game(id: 'game-jx3', name: '剑网3')]
        : (jsonDecode(gamesJson) as List)
            .map(
                (item) => Game.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
    if (games.isEmpty) games = [const Game(id: 'game-jx3', name: '剑网3')];
    tasks = (jsonDecode(tasksJson ?? '[]') as List)
        .map((item) =>
            TaskRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    _migrateCharacterMetadata(
      legacyGames: gamesJson != null && !gamesJson.contains('"metadataFields"'),
    );
    _migrateInboxGames();
  }

  Future<void> save() async {
    if (_dataDirectory != null) {
      final file = File(dataFilePathFor(_dataDirectory!));
      await file.parent.create(recursive: true);
      await file.writeAsString(exportJson(), flush: true);
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _gamesKey, jsonEncode(games.map((item) => item.toJson()).toList()));
    await preferences.setString(_charactersKey,
        jsonEncode(characters.map((item) => item.toJson()).toList()));
    await preferences.setString(
        _tasksKey, jsonEncode(tasks.map((item) => item.toJson()).toList()));
  }

  String exportJson() {
    final payload = {
      'schemaVersion': 3,
      'app': '角色日程',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'games': games.map((item) => item.toJson()).toList(),
      'characters': characters.map((item) => item.toJson()).toList(),
      'tasks': tasks.map((item) => item.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> importJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['characters'] is! List ||
        decoded['tasks'] is! List) {
      throw const FormatException('不是有效的 角色日程备份文件');
    }
    _loadPayload(Map<String, dynamic>.from(decoded));
    await save();
  }

  /// Moves the current project data to a user-selected directory.
  ///
  /// The destination must not already contain the app's data file, so an
  /// accidental folder selection cannot overwrite another data set. The
  /// preference that points to this file is written only after the copy
  /// succeeds; if the app is interrupted during the operation, it continues
  /// using the old data.
  Future<void> migrateToDirectory(String directory) async {
    final normalized = _normalizeDirectory(directory);
    if (normalized == null) {
      throw const FormatException('请选择有效的数据文件夹');
    }
    if (normalized == _dataDirectory) return;

    final target = File(dataFilePathFor(normalized));
    if (await target.exists()) {
      throw StateError('目标文件夹已有角色日程数据，请选择空文件夹');
    }
    await target.parent.create(recursive: true);
    await target.writeAsString(exportJson(), flush: true);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_dataDirectoryKey, normalized);
    _dataDirectory = normalized;
  }

  void _loadPayload(Map<String, dynamic> decoded) {
    if (decoded['characters'] is! List || decoded['tasks'] is! List) {
      throw const FormatException('本地数据文件缺少角色或任务数据');
    }
    games = decoded['games'] is List
        ? (decoded['games'] as List)
            .map(
                (item) => Game.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList()
        : [const Game(id: 'game-jx3', name: '剑网3')];
    if (games.isEmpty) games = [const Game(id: 'game-jx3', name: '剑网3')];
    characters = (decoded['characters'] as List)
        .map((item) =>
            Character.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    _migrateCharacterMetadata(
      legacyGames: decoded['games'] is! List ||
          !(decoded['games'] as List).every(
              (item) => item is Map && item.containsKey('metadataFields')),
    );
    tasks = (decoded['tasks'] as List)
        .map((item) =>
            TaskRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    _migrateInboxGames();
  }

  String? _normalizeDirectory(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : Directory(trimmed).absolute.path;
  }

  void _migrateCharacterMetadata({required bool legacyGames}) {
    if (!legacyGames) return;
    final gameIdsWithOccupation = characters
        .where((character) => character.occupation.trim().isNotEmpty)
        .map((character) => character.gameId)
        .toSet();
    games = games
        .map((game) => gameIdsWithOccupation.contains(game.id) &&
                game.metadataFields.isEmpty
            ? game
                .copyWith(metadataFields: const [legacyOccupationMetadataField])
            : game)
        .toList();
    characters = characters
        .map((character) => character.occupation.trim().isNotEmpty &&
                character.metadataValues.isEmpty
            ? character.copyWith(metadataValues: {
                legacyOccupationMetadataField.id: character.occupation,
              })
            : character)
        .toList();
  }

  void _migrateInboxGames() {
    final defaultGameId = games.first.id;
    tasks = tasks
        .map((task) => task.isInbox && task.inboxGameId == null
            ? task.copyWith(inboxGameId: defaultGameId)
            : task)
        .toList();
  }

  void _loadDemoData() {
    final now = DateTime.now();
    games = const [Game(id: 'game-jx3', name: '剑网3')];
    characters = const [
      Character(
          id: 'char-1',
          gameId: 'game-jx3',
          account: '',
          name: '奶歌',
          occupation: '奶歌',
          color: 0xff3c8c72),
      Character(
          id: 'char-2',
          gameId: 'game-jx3',
          account: '',
          name: '花间',
          occupation: '花间',
          color: 0xff66a892),
      Character(
          id: 'char-3',
          gameId: 'game-jx3',
          account: '',
          name: '苍云',
          occupation: '苍云',
          color: 0xff7fae9e),
      Character(
          id: 'char-4',
          gameId: 'game-jx3',
          account: '',
          name: '丐帮',
          occupation: '丐帮',
          color: 0xff4f796c),
    ];
    tasks = [
      TaskRecord(
          id: 'task-1',
          templateId: 'template-1',
          title: '大战',
          characterId: 'char-1',
          frequency: TaskFrequency.daily,
          createdAt: now,
          completedDates: [dateKey(now)]),
      TaskRecord(
          id: 'task-2',
          templateId: 'template-1',
          title: '大战',
          characterId: 'char-2',
          frequency: TaskFrequency.daily,
          createdAt: now),
      TaskRecord(
          id: 'task-3',
          templateId: 'template-1',
          title: '大战',
          characterId: 'char-3',
          frequency: TaskFrequency.daily,
          createdAt: now),
      TaskRecord(
          id: 'task-4',
          templateId: 'template-2',
          title: '茶馆',
          characterId: 'char-1',
          frequency: TaskFrequency.daily,
          createdAt: now),
      TaskRecord(
          id: 'task-5',
          templateId: 'template-2',
          title: '茶馆',
          characterId: 'char-3',
          frequency: TaskFrequency.daily,
          createdAt: now,
          completedDates: [dateKey(now)]),
      TaskRecord(
          id: 'task-6',
          templateId: 'template-3',
          title: '门派周常',
          characterId: 'char-1',
          frequency: TaskFrequency.weekly,
          createdAt: now),
      TaskRecord(
          id: 'task-7',
          templateId: 'template-3',
          title: '门派周常',
          characterId: 'char-2',
          frequency: TaskFrequency.weekly,
          createdAt: now),
      TaskRecord(
          id: 'task-8',
          templateId: 'template-3',
          title: '门派周常',
          characterId: 'char-4',
          frequency: TaskFrequency.weekly,
          createdAt: now),
      TaskRecord(
          id: 'task-9',
          templateId: 'template-4',
          title: '浪客行',
          characterId: 'char-2',
          frequency: TaskFrequency.weeklyCount,
          targetCount: 5,
          createdAt: now,
          completedDates: [dateKey(now.subtract(const Duration(days: 1)))]),
      TaskRecord(
          id: 'task-10',
          templateId: 'template-4',
          title: '浪客行',
          characterId: 'char-3',
          frequency: TaskFrequency.weeklyCount,
          targetCount: 5,
          createdAt: now),
      TaskRecord(
          id: 'task-11',
          templateId: 'template-5',
          title: '世界 Boss',
          characterId: 'char-4',
          frequency: TaskFrequency.once,
          createdAt: now,
          dueDate: now.add(const Duration(days: 3))),
    ];
  }
}
