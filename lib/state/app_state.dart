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
  Timer? _changeSyncTimer;
  Completer<void>? _syncCompleter;
  SyncConfig? _syncConfig;
  DateTime? _lastSyncAt;
  RemoteBackup? _newerRemoteBackup;
  int _dataRevision = 0;
  int _syncedRevision = 0;
  bool syncBusy = false;
  bool restoreBusy = false;
  bool backupCheckBusy = false;
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
  RemoteBackup? get newerRemoteBackup => _newerRemoteBackup;
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

  List<TaskRecord> tasksForTemplate(String templateId) =>
      tasks.where((task) => task.templateId == templateId).toList();

  List<TaskRecord> get selectedTasks => selectedCharacterId == null
      ? const []
      : tasksForCharacter(selectedCharacterId!);

  String exportBackup() => store.exportJson();

  Future<void> _initializeSync() async {
    _syncConfig = await syncSettingsStore.load();
    _lastSyncAt = await syncSettingsStore.loadLastSyncAt();
    _scheduleAutoSync();
    _scheduleChangeSync();
    notifyListeners();
    await checkAutoSync();
  }

  Future<void> reloadSyncSettings() async {
    _syncConfig = await syncSettingsStore.load();
    _scheduleAutoSync();
    _scheduleChangeSync();
    notifyListeners();
    await checkForNewerBackup();
  }

  bool get _hasUnsyncedChanges => _dataRevision > _syncedRevision;

  Future<void> _saveDataChange() async {
    await store.save();
    _dataRevision++;
    notifyListeners();
    _scheduleChangeSync();
  }

  void _scheduleChangeSync() {
    _changeSyncTimer?.cancel();
    if (!_hasUnsyncedChanges || !(_syncConfig?.isValid ?? false)) return;
    _changeSyncTimer = Timer(
      const Duration(seconds: 2),
      () => syncNow(silent: true),
    );
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
    if (config == null || !config.isValid) return;
    await checkForNewerBackup();
    if (_newerRemoteBackup != null) return;
    if (config.autoSyncMinutes <= 0) return;
    final due = _lastSyncAt == null ||
        DateTime.now().difference(_lastSyncAt!).inMinutes >=
            config.autoSyncMinutes;
    if (due) await syncNow(silent: true);
  }

  Future<bool> syncNow({bool silent = false}) async {
    if (syncBusy || restoreBusy) return false;
    final config = _syncConfig ?? await syncSettingsStore.load();
    _syncConfig = config;
    if (!config.isValid) {
      syncMessage = '尚未配置 WebDAV';
      notifyListeners();
      return false;
    }
    syncBusy = true;
    final revisionAtStart = _dataRevision;
    _syncCompleter = Completer<void>();
    if (!silent) syncMessage = null;
    notifyListeners();
    var syncSucceeded = false;
    try {
      final backup = await webDavSyncService.upload(config, exportBackup());
      _lastSyncAt = DateTime.now();
      _syncedRevision = revisionAtStart;
      _newerRemoteBackup = null;
      syncSucceeded = true;
      await syncSettingsStore.saveLastSyncAt(_lastSyncAt!);
      syncMessage = '已同步 · ${backup.name}';
      return true;
    } catch (error) {
      syncMessage = '同步失败：$error';
      return false;
    } finally {
      syncBusy = false;
      _syncCompleter?.complete();
      _syncCompleter = null;
      notifyListeners();
      if (syncSucceeded) _scheduleChangeSync();
    }
  }

  Future<void> checkForNewerBackup() async {
    if (backupCheckBusy || syncBusy || restoreBusy) return;
    final config = _syncConfig ?? await syncSettingsStore.load();
    _syncConfig = config;
    if (!config.isValid) {
      _newerRemoteBackup = null;
      return;
    }
    backupCheckBusy = true;
    notifyListeners();
    try {
      final backups = await webDavSyncService.listBackups(config);
      final latest = backups.firstOrNull;
      final latestTime =
          latest == null ? null : webDavSyncService.backupTime(latest);
      _newerRemoteBackup = latest != null &&
              (_lastSyncAt == null ||
                  (latestTime != null && latestTime.isAfter(_lastSyncAt!)))
          ? latest
          : null;
    } catch (_) {
      // 首页检测失败不阻塞本地使用，用户仍可从同步页面手动刷新。
    } finally {
      backupCheckBusy = false;
      notifyListeners();
    }
  }

  Future<void> restoreBackup(RemoteBackup backup) async {
    if (restoreBusy || syncBusy) throw StateError('同步操作正在进行中');
    final config = _syncConfig ?? await syncSettingsStore.load();
    _syncConfig = config;
    if (!config.isValid) throw StateError('尚未配置 WebDAV');
    _changeSyncTimer?.cancel();
    restoreBusy = true;
    notifyListeners();
    try {
      final raw = await webDavSyncService.downloadBackup(config, backup);
      await importBackup(raw);
      _dataRevision = 0;
      _syncedRevision = 0;
      _lastSyncAt = webDavSyncService.backupTime(backup) ?? DateTime.now();
      _newerRemoteBackup = null;
      await syncSettingsStore.saveLastSyncAt(_lastSyncAt!);
      syncMessage = '已恢复 · ${backup.name}';
    } finally {
      restoreBusy = false;
      notifyListeners();
    }
  }

  Future<void> backupBeforeExit() async {
    _changeSyncTimer?.cancel();
    _syncConfig ??= await syncSettingsStore.load();
    if (!(_syncConfig?.isValid ?? false)) return;
    final activeSync = _syncCompleter;
    if (activeSync != null) {
      await activeSync.future;
      if (_hasUnsyncedChanges) await syncNow(silent: true);
    } else {
      await syncNow(silent: true);
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
    await _saveDataChange();
  }

  Future<void> setTaskCompletionForCharacters({
    required String templateId,
    required Set<String> characterIds,
    required DateTime date,
    required bool completed,
  }) async {
    if (characterIds.isEmpty) return;
    final key = dateKey(date);
    var changed = false;
    for (var index = 0; index < store.tasks.length; index++) {
      final task = store.tasks[index];
      if (task.templateId != templateId ||
          !characterIds.contains(task.characterId)) {
        continue;
      }
      final completedDates = [...task.completedDates];
      if (completed && !completedDates.contains(key)) {
        completedDates.add(key);
        changed = true;
      } else if (!completed && completedDates.remove(key)) {
        changed = true;
      }
      store.tasks[index] = task.copyWith(completedDates: completedDates);
    }
    if (changed) await _saveDataChange();
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
    await _saveDataChange();
  }

  Future<void> updateTaskTemplate({
    required TaskRecord source,
    required String title,
    required Set<String> characterIds,
    required TaskFrequency frequency,
    DateTime? dueDate,
    required int targetCount,
    List<int> weeklyDays = const [],
    String note = '',
  }) async {
    if (characterIds.isEmpty) return;
    final linkedTasks = store.tasks
        .where((task) => task.templateId == source.templateId)
        .toList();
    final existingByCharacter = {
      for (final task in linkedTasks) task.characterId: task,
    };

    store.tasks.removeWhere((task) =>
        task.templateId == source.templateId &&
        !characterIds.contains(task.characterId));

    for (final characterId in characterIds) {
      final existing = existingByCharacter[characterId];
      if (existing == null) {
        store.tasks.add(TaskRecord(
          id: '${source.templateId}-$characterId',
          templateId: source.templateId,
          title: title,
          characterId: characterId,
          frequency: frequency,
          createdAt: source.createdAt,
          dueDate: dueDate,
          targetCount: targetCount,
          weeklyDays: [...weeklyDays],
          note: note,
        ));
        continue;
      }
      final index = store.tasks.indexWhere((task) => task.id == existing.id);
      if (index < 0) continue;
      store.tasks[index] = existing.copyWith(
        title: title,
        frequency: frequency,
        dueDate: dueDate,
        clearDueDate: dueDate == null,
        targetCount: targetCount,
        weeklyDays: [...weeklyDays],
        note: note,
      );
    }
    await _saveDataChange();
  }

  Future<void> assignExistingTask({
    required TaskRecord source,
    required Set<String> characterIds,
  }) async {
    if (characterIds.isEmpty) return;
    final existingCharacterIds = store.tasks
        .where((task) => task.templateId == source.templateId)
        .map((task) => task.characterId)
        .toSet();
    final validCharacterIds = characters
        .map((character) => character.id)
        .where((id) =>
            characterIds.contains(id) && !existingCharacterIds.contains(id))
        .toList();
    if (validCharacterIds.isEmpty) return;
    store.tasks.addAll(validCharacterIds.map((characterId) => TaskRecord(
          id: '${source.templateId}-$characterId',
          templateId: source.templateId,
          title: source.title,
          characterId: characterId,
          frequency: source.frequency,
          createdAt: source.createdAt,
          dueDate: source.dueDate,
          targetCount: source.targetCount,
          weeklyDays: [...source.weeklyDays],
          note: source.note,
        )));
    await _saveDataChange();
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
    // Replace the collection so this also works with immutable seed data
    // supplied by tests or import callers.
    store.characters = [...store.characters, character];
    selectedGameId = character.gameId;
    selectedCharacterId = character.id;
    await _saveDataChange();
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
    await _saveDataChange();
  }

  Future<void> updateGame(Game game, String name) async {
    final index = store.games.indexWhere((item) => item.id == game.id);
    if (index < 0) return;
    store.games[index] = game.copyWith(name: name);
    await _saveDataChange();
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
    await _saveDataChange();
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
    if (selectedCharacterId == character.id) {
      selectedGameId = gameId;
    }
    await _saveDataChange();
  }

  Future<void> deleteCharacter(Character character) async {
    store.characters.removeWhere((item) => item.id == character.id);
    store.tasks.removeWhere((task) => task.characterId == character.id);
    if (selectedCharacterId == character.id) {
      selectedCharacterId = characters.firstOrNull?.id;
    }
    await _saveDataChange();
  }

  Future<void> archiveCharacter(Character character) async {
    final index =
        store.characters.indexWhere((item) => item.id == character.id);
    if (index < 0) return;
    store.characters[index] = character.copyWith(archived: true);
    if (selectedCharacterId == character.id)
      selectedCharacterId = characters.firstOrNull?.id;
    await _saveDataChange();
  }

  Future<void> archiveCharacters(Set<String> characterIds) async {
    if (characterIds.isEmpty) return;
    for (var index = 0; index < store.characters.length; index++) {
      final character = store.characters[index];
      if (characterIds.contains(character.id)) {
        store.characters[index] = character.copyWith(archived: true);
      }
    }
    if (selectedCharacterId != null &&
        characterIds.contains(selectedCharacterId)) {
      selectedCharacterId = characters.firstOrNull?.id;
    }
    await _saveDataChange();
  }

  Future<void> deleteCharacters(Set<String> characterIds) async {
    if (characterIds.isEmpty) return;
    store.characters
        .removeWhere((character) => characterIds.contains(character.id));
    store.tasks.removeWhere((task) => characterIds.contains(task.characterId));
    if (selectedCharacterId != null &&
        characterIds.contains(selectedCharacterId)) {
      selectedCharacterId = characters.firstOrNull?.id;
    }
    await _saveDataChange();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _changeSyncTimer?.cancel();
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
