import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/sync_service.dart';
import '../models/task_models.dart';

class AppState extends ChangeNotifier {
  AppState(this.store) {
    selectedGameId = store.games.firstOrNull?.id;
    selectedCharacterId = characters.firstOrNull?.id;
    _initializeSync();
  }

  final LocalStore store;
  final SyncSettingsStore syncSettingsStore = SyncSettingsStore();
  final WebDavSyncService webDavSyncService = WebDavSyncService();
  Timer? _autoSyncTimer;
  SyncConfig? _syncConfig;
  DateTime? _lastSyncAt;
  bool syncBusy = false;
  String? syncMessage;
  String? selectedGameId;
  String? selectedCharacterId;
  int currentTab = 0;
  DateTime focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<Game> get games => store.games;
  Game? get selectedGame =>
      games.where((item) => item.id == selectedGameId).firstOrNull;
  bool get isSyncConfigured => _syncConfig?.isValid ?? false;
  SyncConfig? get syncConfig => _syncConfig;
  DateTime? get lastSyncAt => _lastSyncAt;
  List<Character> get characters => store.characters
      .where((item) => item.gameId == selectedGameId && !item.archived)
      .toList();
  List<TaskRecord> get tasks {
    final characterIds = characters.map((item) => item.id).toSet();
    return store.tasks
        .where((task) => characterIds.contains(task.characterId))
        .toList();
  }

  Character? get selectedCharacter =>
      characters.where((item) => item.id == selectedCharacterId).firstOrNull;

  void selectCharacter(String? id) {
    selectedCharacterId = id;
    notifyListeners();
  }

  void selectGame(String id) {
    if (!games.any((game) => game.id == id)) return;
    selectedGameId = id;
    selectedCharacterId = characters.firstOrNull?.id;
    notifyListeners();
  }

  void setTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  void setMonth(DateTime month) {
    focusedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  List<TaskRecord> tasksForCharacter(String characterId) =>
      tasks.where((task) => task.characterId == characterId).toList();

  List<TaskRecord> get selectedTasks => selectedCharacterId == null
      ? const []
      : tasksForCharacter(selectedCharacterId!);

  String exportBackup() => store.exportJson();

  Future<void> _initializeSync() async {
    _syncConfig = await syncSettingsStore.load();
    _lastSyncAt = await syncSettingsStore.loadLastSyncAt();
    _scheduleAutoSync();
    notifyListeners();
    await checkAutoSync();
  }

  Future<void> reloadSyncSettings() async {
    _syncConfig = await syncSettingsStore.load();
    _scheduleAutoSync();
    notifyListeners();
  }

  void _scheduleAutoSync() {
    _autoSyncTimer?.cancel();
    final config = _syncConfig;
    if (config == null || !config.isValid || config.autoSyncMinutes <= 0) {
      return;
    }
    _autoSyncTimer = Timer.periodic(
      Duration(minutes: config.autoSyncMinutes),
      (_) => checkAutoSync(),
    );
  }

  Future<void> checkAutoSync() async {
    final config = _syncConfig;
    if (config == null || !config.isValid || config.autoSyncMinutes <= 0) {
      return;
    }
    final due = _lastSyncAt == null ||
        DateTime.now().difference(_lastSyncAt!).inMinutes >=
            config.autoSyncMinutes;
    if (due) await syncNow(silent: true);
  }

  Future<bool> syncNow({bool silent = false}) async {
    if (syncBusy) return false;
    final config = _syncConfig ?? await syncSettingsStore.load();
    _syncConfig = config;
    if (!config.isValid) {
      syncMessage = '尚未配置 WebDAV';
      notifyListeners();
      return false;
    }
    syncBusy = true;
    if (!silent) syncMessage = null;
    notifyListeners();
    try {
      final backup = await webDavSyncService.upload(config, exportBackup());
      _lastSyncAt = DateTime.now();
      await syncSettingsStore.saveLastSyncAt(_lastSyncAt!);
      syncMessage = '已同步 · ${backup.name}';
      return true;
    } catch (error) {
      syncMessage = '同步失败：$error';
      return false;
    } finally {
      syncBusy = false;
      notifyListeners();
    }
  }

  Future<void> importBackup(String raw) async {
    await store.importJson(raw);
    selectedGameId = games.firstOrNull?.id;
    selectedCharacterId = characters.firstOrNull?.id;
    notifyListeners();
  }

  Future<void> toggleTask(TaskRecord task, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final key = dateKey(targetDate);
    final index = store.tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return;
    final completed = [...task.completedDates];
    if (completed.contains(key)) {
      completed.remove(key);
    } else {
      completed.add(key);
    }
    store.tasks[index] = task.copyWith(completedDates: completed);
    await store.save();
    notifyListeners();
  }

  Future<void> addTask({
    required String title,
    required List<String> characterIds,
    required TaskFrequency frequency,
    DateTime? dueDate,
    required int targetCount,
    List<int> weeklyDays = const [],
    String note = '',
  }) async {
    final now = DateTime.now();
    final templateId = 'template-${now.microsecondsSinceEpoch}';
    store.tasks.addAll(characterIds.map((characterId) => TaskRecord(
          id: '$templateId-$characterId',
          templateId: templateId,
          title: title,
          characterId: characterId,
          frequency: frequency,
          createdAt: now,
          dueDate: dueDate,
          targetCount: targetCount,
          weeklyDays: weeklyDays,
          note: note,
        )));
    await store.save();
    notifyListeners();
  }

  Future<void> addCharacter({
    required String name,
    required String account,
    required String occupation,
    required String gameId,
  }) async {
    final colors = [0xff2f7d72, 0xff5a78aa, 0xff8b6e54, 0xff98734a, 0xff6e6292];
    final character = Character(
      id: 'char-${DateTime.now().microsecondsSinceEpoch}',
      gameId: games.any((game) => game.id == gameId)
          ? gameId
          : selectedGameId ?? games.first.id,
      account: account,
      name: name,
      occupation: occupation,
      color: colors[store.characters.length % colors.length],
    );
    store.characters.add(character);
    selectedCharacterId = character.id;
    await store.save();
    notifyListeners();
  }

  Future<void> addGame(String name) async {
    final game = Game(
      id: 'game-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      color: const [
        0xff2f7d72,
        0xff5a78aa,
        0xff8b6e54,
        0xff98734a
      ][store.games.length % 4],
    );
    store.games.add(game);
    selectedGameId = game.id;
    selectedCharacterId = null;
    await store.save();
    notifyListeners();
  }

  Future<void> updateGame(Game game, String name) async {
    final index = store.games.indexWhere((item) => item.id == game.id);
    if (index < 0) return;
    store.games[index] = game.copyWith(name: name);
    await store.save();
    notifyListeners();
  }

  Future<void> deleteGame(Game game) async {
    if (store.games.length <= 1) return;
    store.games.removeWhere((item) => item.id == game.id);
    final characterIds = store.characters
        .where((character) => character.gameId == game.id)
        .map((character) => character.id)
        .toSet();
    store.characters
        .removeWhere((character) => characterIds.contains(character.id));
    store.tasks.removeWhere((task) => characterIds.contains(task.characterId));
    if (selectedGameId == game.id) {
      selectedGameId = games.firstOrNull?.id;
      selectedCharacterId = characters.firstOrNull?.id;
    }
    await store.save();
    notifyListeners();
  }

  Future<void> updateCharacter({
    required Character character,
    required String gameId,
    required String account,
    required String name,
    required String occupation,
  }) async {
    final index =
        store.characters.indexWhere((item) => item.id == character.id);
    if (index < 0) return;
    store.characters[index] = character.copyWith(
      gameId: gameId,
      account: account,
      name: name,
      occupation: occupation,
    );
    await store.save();
    notifyListeners();
  }

  Future<void> deleteCharacter(Character character) async {
    store.characters.removeWhere((item) => item.id == character.id);
    store.tasks.removeWhere((task) => task.characterId == character.id);
    if (selectedCharacterId == character.id) {
      selectedCharacterId = characters.firstOrNull?.id;
    }
    await store.save();
    notifyListeners();
  }

  Future<void> archiveCharacter(Character character) async {
    final index =
        store.characters.indexWhere((item) => item.id == character.id);
    if (index < 0) return;
    store.characters[index] = character.copyWith(archived: true);
    if (selectedCharacterId == character.id)
      selectedCharacterId = characters.firstOrNull?.id;
    await store.save();
    notifyListeners();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  int completedCountFor(
          List<TaskRecord> source, DateTime start, DateTime end) =>
      source
          .where((task) =>
              task.isDoneOn(start) || task.countInRange(start, end) > 0)
          .length;

  int completionCount(TaskRecord task, DateTime start, DateTime end) =>
      task.countInRange(start, end);

  double progressFor(List<TaskRecord> source, DateTime start, DateTime end) {
    if (source.isEmpty) return 0;
    final completed = source
        .where((task) => task.isCountTask
            ? completionCount(task, start, end) >= task.targetCount
            : task.isDoneOn(start))
        .length;
    return completed / source.length;
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
