import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/local_store.dart';
import '../data/sync_service.dart';
import '../data/theme_settings.dart';
import '../models/task_models.dart';

class AppState extends ChangeNotifier {
  AppState(
    this.store, {
    SyncSettingsStore? syncSettingsStore,
    WebDavSyncService? webDavSyncService,
    ThemeSettingsStore? themeSettingsStore,
    this.remoteCheckInterval = const Duration(minutes: 1),
  })  : syncSettingsStore = syncSettingsStore ?? SyncSettingsStore(),
        webDavSyncService = webDavSyncService ?? WebDavSyncService(),
        themeSettingsStore = themeSettingsStore ?? ThemeSettingsStore() {
    selectedGameId = store.games.firstOrNull?.id;
    selectedCharacterId = characters.firstOrNull?.id;
    _initializeSync();
    _initializeTheme();
  }

  final LocalStore store;
  final SyncSettingsStore syncSettingsStore;
  final WebDavSyncService webDavSyncService;
  final ThemeSettingsStore themeSettingsStore;
  final Duration remoteCheckInterval;
  Timer? _autoSyncTimer;
  Timer? _remoteCheckTimer;
  Timer? _changeSyncTimer;
  Timer? _backupCheckRetryTimer;
  Timer? _taskDayTimer;
  Completer<void>? _syncCompleter;
  SyncConfig? _syncConfig;
  DateTime? _lastSyncAt;
  RemoteBackup? _newerRemoteBackup;
  String? _currentRemoteBackupPath;
  int _successfulSyncGeneration = 0;
  int _dataRevision = 0;
  int _syncedRevision = 0;
  bool _dataDirty = false;
  String? _conflictLocalJson;
  String? _conflictRemoteJson;
  String? _conflictRemotePath;
  bool _disposed = false;
  bool _taskDayClockStarted = false;
  bool syncBusy = false;
  bool restoreBusy = false;
  bool backupCheckBusy = false;
  String? syncMessage;
  String? selectedGameId;
  String? selectedCharacterId;
  int currentTab = 0;
  ThemeMode themeMode = ThemeMode.light;
  DateTime focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedCalendarDate = startOfDay(DateTime.now());

  List<Game> get games => store.games;
  Game? get selectedGame =>
      games.where((item) => item.id == selectedGameId).firstOrNull;
  DateTime get currentTaskDate {
    final now = DateTime.now();
    return selectedGame?.taskDayAt(now) ?? startOfDay(now);
  }

  bool get isSyncConfigured => _syncConfig?.isValid ?? false;
  SyncConfig? get syncConfig => _syncConfig;
  DateTime? get lastSyncAt => _lastSyncAt;
  RemoteBackup? get newerRemoteBackup => _newerRemoteBackup;
  String? get currentRemoteBackupPath => _currentRemoteBackupPath;
  bool get hasUnsyncedChanges => _hasUnsyncedChanges;
  bool get hasSyncConflict => _newerRemoteBackup != null && _hasUnsyncedChanges;
  String? get conflictLocalJson => _conflictLocalJson;
  String? get conflictRemoteJson => _conflictRemoteJson;

  Game? gameForTask(TaskRecord task) {
    final gameId = task.isInbox
        ? task.inboxGameId
        : store.characters
            .where((character) => character.id == task.characterId)
            .firstOrNull
            ?.gameId;
    return games.where((game) => game.id == gameId).firstOrNull;
  }

  DateTime taskDateFor(TaskRecord task, [DateTime? moment]) {
    final timestamp = moment ?? DateTime.now();
    return (gameForTask(task) ?? selectedGame)?.taskDayAt(timestamp) ??
        startOfDay(timestamp);
  }

  bool isTaskScheduledOn(TaskRecord task, DateTime date) => task.isScheduledOn(
        date,
        dailyResetMinutes: gameForTask(task)?.dailyResetMinutes ?? 0,
      );

  List<TaskRecord> scheduledTasksInRange(
    Iterable<TaskRecord> source,
    DateTime start,
    DateTime end,
  ) {
    final rangeStart = startOfDay(start);
    final rangeEnd = startOfDay(end);
    return source.where((task) {
      if (task.archived) return false;
      for (var date = rangeStart;
          date.isBefore(rangeEnd);
          date = date.add(const Duration(days: 1))) {
        if (isTaskScheduledOn(task, date)) return true;
      }
      return false;
    }).toList();
  }

  bool hasTaskStartedBy(TaskRecord task, DateTime date) => task.hasStartedBy(
        date,
        dailyResetMinutes: gameForTask(task)?.dailyResetMinutes ?? 0,
      );
  List<Character> get characters => store.characters
      .where((item) => item.gameId == selectedGameId && !item.archived)
      .toList();
  List<TaskRecord> get tasks {
    final characterIds = characters.map((item) => item.id).toSet();
    return store.tasks
        .where(
            (task) => !task.archived && characterIds.contains(task.characterId))
        .toList();
  }

  List<TaskRecord> get inboxTasks =>
      store.tasks.where((task) => !task.archived && task.isInbox).toList();

  List<TaskRecord> get allTasksForSelectedGame {
    final characterIds = store.characters
        .where((character) => character.gameId == selectedGameId)
        .map((character) => character.id)
        .toSet();
    return store.tasks
        .where((task) =>
            !task.archived &&
            (task.isInbox
                ? task.inboxGameId == selectedGameId
                : characterIds.contains(task.characterId)))
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

  Future<void> _initializeTheme() async {
    themeMode = await themeSettingsStore.load();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode == mode) return;
    themeMode = mode;
    notifyListeners();
    await themeSettingsStore.save(mode);
  }

  void setMonth(DateTime month) {
    focusedMonth = DateTime(month.year, month.month);
    selectedCalendarDate = focusedMonth;
    notifyListeners();
  }

  void selectCalendarDate(DateTime date) {
    selectedCalendarDate = startOfDay(date);
    focusedMonth = DateTime(date.year, date.month);
    notifyListeners();
  }

  List<TaskRecord> tasksForCharacter(String characterId) =>
      tasks.where((task) => task.characterId == characterId).toList();

  List<TaskRecord> tasksForTemplate(String templateId) => store.tasks
      .where((task) => !task.isInbox && task.templateId == templateId)
      .toList();

  List<TaskRecord> get selectedTasks => selectedCharacterId == null
      ? const []
      : tasksForCharacter(selectedCharacterId!);

  List<TaskRecord> calendarTasks({String? gameId}) {
    final characterIds = store.characters
        .where((character) =>
            !character.archived &&
            (gameId == null || character.gameId == gameId))
        .map((character) => character.id)
        .toSet();
    return store.tasks
        .where(
            (task) => !task.archived && characterIds.contains(task.characterId))
        .toList();
  }

  String exportBackup() => store.exportJson();

  Future<void> _initializeSync() async {
    _syncConfig = await syncSettingsStore.load();
    _lastSyncAt = await syncSettingsStore.loadLastSyncAt();
    _currentRemoteBackupPath = await syncSettingsStore.loadCurrentBackupPath();
    _dataDirty = await syncSettingsStore.loadDataDirty();
    final conflict = await syncSettingsStore.loadConflictSnapshot();
    if (_disposed) return;
    _conflictLocalJson = conflict.localJson;
    _conflictRemoteJson = conflict.remoteJson;
    _conflictRemotePath = conflict.remotePath;
    _scheduleAutoSync();
    _scheduleRemoteBackupChecks();
    _scheduleChangeSync();
    notifyListeners();
    await checkForNewerBackupWithRetry();
  }

  Future<void> reloadSyncSettings() async {
    _syncConfig = await syncSettingsStore.load();
    _scheduleAutoSync();
    _scheduleRemoteBackupChecks();
    _scheduleChangeSync();
    notifyListeners();
    await checkForNewerBackup();
  }

  bool get _hasUnsyncedChanges => _dataDirty || _dataRevision > _syncedRevision;

  Future<void> _saveDataChange() async {
    _dataRevision++;
    _dataDirty = true;
    notifyListeners();
    _scheduleChangeSync();
    await syncSettingsStore.saveDataDirty(true);
    await store.save();
  }

  void _scheduleChangeSync() {
    _changeSyncTimer?.cancel();
    if (!_hasUnsyncedChanges ||
        !(_syncConfig?.isValid ?? false) ||
        _newerRemoteBackup != null) {
      return;
    }
    _changeSyncTimer = Timer(
      const Duration(seconds: 2),
      () {
        if (_hasUnsyncedChanges && _newerRemoteBackup == null) {
          unawaited(syncNow(silent: true));
        }
      },
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

  void _scheduleRemoteBackupChecks() {
    _remoteCheckTimer?.cancel();
    final config = _syncConfig;
    if (config == null || !config.isValid) return;
    _remoteCheckTimer = Timer.periodic(remoteCheckInterval, (_) {
      if (_newerRemoteBackup == null &&
          !backupCheckBusy &&
          !syncBusy &&
          !restoreBusy) {
        unawaited(checkForNewerBackup(silent: true));
      }
    });
  }

  void _scheduleTaskDayRefresh() {
    _taskDayTimer?.cancel();
    if (!_taskDayClockStarted || games.isEmpty) return;
    final now = DateTime.now();
    DateTime? nextReset;
    for (final game in games) {
      final hour = game.dailyResetMinutes ~/ 60;
      final minute = game.dailyResetMinutes % 60;
      var candidate = DateTime(now.year, now.month, now.day, hour, minute);
      if (!candidate.isAfter(now)) {
        candidate = DateTime(now.year, now.month, now.day + 1, hour, minute);
      }
      if (nextReset == null || candidate.isBefore(nextReset)) {
        nextReset = candidate;
      }
    }
    _taskDayTimer = Timer(
      nextReset!.difference(now) + const Duration(seconds: 1),
      () {
        notifyListeners();
        _scheduleTaskDayRefresh();
      },
    );
  }

  void startTaskDayClock() {
    _taskDayClockStarted = true;
    _scheduleTaskDayRefresh();
  }

  void refreshTaskDayClock() {
    if (!_taskDayClockStarted) return;
    notifyListeners();
    _scheduleTaskDayRefresh();
  }

  Future<void> checkForNewerBackupWithRetry() async {
    final config = _syncConfig;
    if (config == null || !config.isValid) return;
    final checkSucceeded = await checkForNewerBackup();
    if (checkSucceeded) {
      _backupCheckRetryTimer?.cancel();
      return;
    }
    _backupCheckRetryTimer?.cancel();
    _backupCheckRetryTimer = Timer(
      const Duration(seconds: 10),
      () => checkForNewerBackup(),
    );
  }

  Future<void> checkAutoSync() async {
    final config = _syncConfig;
    if (config == null || !config.isValid) return;
    final checkSucceeded = await checkForNewerBackup();
    if (!checkSucceeded) return;
    if (_newerRemoteBackup != null) return;
    if (!_hasUnsyncedChanges) return;
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
    final remoteCheckSucceeded = await checkForNewerBackup(silent: silent);
    if (!remoteCheckSucceeded) {
      if (!silent) {
        syncMessage = '同步前检查云端失败，未上传本地数据';
        notifyListeners();
      }
      return false;
    }
    if (_newerRemoteBackup != null) {
      if (!silent) {
        syncMessage = '发现更新的云端备份，请先处理后再上传';
        notifyListeners();
      }
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
      _currentRemoteBackupPath = backup.path;
      _successfulSyncGeneration++;
      _newerRemoteBackup = null;
      syncSucceeded = true;
      await syncSettingsStore.saveLastSyncAt(_lastSyncAt!);
      await syncSettingsStore.saveCurrentBackupPath(backup.path);
      if (revisionAtStart == _dataRevision) {
        _dataDirty = false;
        await syncSettingsStore.saveDataDirty(false);
        await _clearConflictSnapshot();
      }
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

  Future<bool> checkForNewerBackup({bool silent = false}) async {
    if (backupCheckBusy || syncBusy || restoreBusy) return false;
    final config = _syncConfig ?? await syncSettingsStore.load();
    _syncConfig = config;
    if (!config.isValid) {
      _newerRemoteBackup = null;
      return false;
    }
    backupCheckBusy = true;
    final previousBackupPath = _newerRemoteBackup?.path;
    final syncGenerationAtStart = _successfulSyncGeneration;
    if (!silent) notifyListeners();
    try {
      final backups = await webDavSyncService.listBackups(config);
      final latest = backups.firstOrNull;
      final latestTime =
          latest == null ? null : webDavSyncService.backupTime(latest);
      if (syncGenerationAtStart == _successfulSyncGeneration) {
        final isOwnLatest =
            latest != null && latest.path == _currentRemoteBackupPath;
        _newerRemoteBackup = !isOwnLatest &&
                latest != null &&
                (_lastSyncAt == null ||
                    (latestTime != null && latestTime.isAfter(_lastSyncAt!)))
            ? latest
            : null;
        if (hasSyncConflict &&
            latest != null &&
            _conflictRemotePath != latest.path) {
          _conflictLocalJson = exportBackup();
          _conflictRemoteJson = null;
          _conflictRemotePath = latest.path;
          await syncSettingsStore.saveConflictLocalSnapshot(
            json: _conflictLocalJson!,
            remotePath: latest.path,
          );
        }
      }
      return true;
    } catch (_) {
      // 首页检测失败不阻塞本地使用，用户仍可从同步页面手动刷新。
      return false;
    } finally {
      backupCheckBusy = false;
      if (!silent || previousBackupPath != _newerRemoteBackup?.path) {
        notifyListeners();
      }
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
      await importBackup(raw, markAsLocalChange: false);
      _dataRevision = 0;
      _syncedRevision = 0;
      _lastSyncAt = DateTime.now();
      _currentRemoteBackupPath = backup.path;
      _newerRemoteBackup = null;
      _dataDirty = false;
      await syncSettingsStore.saveDataDirty(false);
      await _clearConflictSnapshot();
      await syncSettingsStore.saveLastSyncAt(_lastSyncAt!);
      await syncSettingsStore.saveCurrentBackupPath(backup.path);
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
    }
    if (_hasUnsyncedChanges) await syncNow(silent: true);
  }

  Future<void> importBackup(
    String raw, {
    bool markAsLocalChange = true,
  }) async {
    await store.importJson(raw);
    selectedGameId = games.firstOrNull?.id;
    selectedCharacterId = characters.firstOrNull?.id;
    _scheduleTaskDayRefresh();
    if (markAsLocalChange) {
      _dataRevision++;
      _dataDirty = true;
      await syncSettingsStore.saveDataDirty(true);
      _currentRemoteBackupPath = null;
      _newerRemoteBackup = null;
      await _clearConflictSnapshot();
      await syncSettingsStore.saveCurrentBackupPath(null);
      _scheduleChangeSync();
    }
    notifyListeners();
  }

  Future<String> prepareConflictRemote() async {
    final backup = _newerRemoteBackup;
    if (backup == null) throw StateError('当前没有待处理的云端冲突');
    if (_conflictRemoteJson != null && _conflictRemotePath == backup.path) {
      return _conflictRemoteJson!;
    }
    final config = _syncConfig ?? await syncSettingsStore.load();
    _syncConfig = config;
    final raw = await webDavSyncService.downloadBackup(config, backup);
    _conflictRemoteJson = raw;
    _conflictRemotePath = backup.path;
    await syncSettingsStore.saveConflictRemoteSnapshot(
      json: raw,
      remotePath: backup.path,
    );
    notifyListeners();
    return raw;
  }

  Future<void> restoreConflictRemote() async {
    final backup = _newerRemoteBackup;
    if (backup == null) throw StateError('当前没有待处理的云端冲突');
    if (restoreBusy || syncBusy) throw StateError('同步操作正在进行中');
    final config = _syncConfig ?? await syncSettingsStore.load();
    _syncConfig = config;
    if (!config.isValid) throw StateError('尚未配置 WebDAV');
    _changeSyncTimer?.cancel();
    restoreBusy = true;
    notifyListeners();
    try {
      final raw = await prepareConflictRemote();
      await importBackup(raw, markAsLocalChange: false);
      _dataRevision = 0;
      _syncedRevision = 0;
      _dataDirty = false;
      _lastSyncAt = DateTime.now();
      _currentRemoteBackupPath = backup.path;
      _newerRemoteBackup = null;
      await syncSettingsStore.saveDataDirty(false);
      await _clearConflictSnapshot();
      await syncSettingsStore.saveLastSyncAt(_lastSyncAt!);
      await syncSettingsStore.saveCurrentBackupPath(backup.path);
      syncMessage = '已使用云端版本 · ${backup.name}';
    } finally {
      restoreBusy = false;
      notifyListeners();
    }
  }

  Future<bool> keepLocalAndUploadAsNewBackup() async {
    final conflict = _newerRemoteBackup;
    if (conflict == null || !_hasUnsyncedChanges) return false;
    if (syncBusy || restoreBusy) return false;
    final config = _syncConfig ?? await syncSettingsStore.load();
    _syncConfig = config;
    if (!config.isValid) {
      syncMessage = '尚未配置 WebDAV';
      notifyListeners();
      return false;
    }
    final checked = await checkForNewerBackup();
    if (!checked || _newerRemoteBackup?.path != conflict.path) {
      syncMessage = '云端又有新版本，请重新处理冲突';
      notifyListeners();
      return false;
    }
    syncBusy = true;
    final revisionAtStart = _dataRevision;
    notifyListeners();
    try {
      final backup = await webDavSyncService.upload(config, exportBackup());
      _lastSyncAt = DateTime.now();
      _syncedRevision = revisionAtStart;
      _currentRemoteBackupPath = backup.path;
      _newerRemoteBackup = null;
      _successfulSyncGeneration++;
      if (revisionAtStart == _dataRevision) {
        _dataDirty = false;
        await syncSettingsStore.saveDataDirty(false);
        await _clearConflictSnapshot();
      }
      await syncSettingsStore.saveLastSyncAt(_lastSyncAt!);
      await syncSettingsStore.saveCurrentBackupPath(backup.path);
      syncMessage = '已保留本地版本并创建新云端备份 · ${backup.name}';
      return true;
    } catch (error) {
      syncMessage = '同步失败：$error';
      return false;
    } finally {
      syncBusy = false;
      notifyListeners();
      _scheduleChangeSync();
    }
  }

  Future<String> exportConflictBundle() async {
    final remote = await prepareConflictRemote();
    final local = _conflictLocalJson ?? exportBackup();
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'type': '角色日程冲突备份',
      'local': jsonDecode(local),
      'remote': jsonDecode(remote),
    });
  }

  Future<void> _clearConflictSnapshot() async {
    _conflictLocalJson = null;
    _conflictRemoteJson = null;
    _conflictRemotePath = null;
    await syncSettingsStore.clearConflictSnapshot();
  }

  Future<void> toggleTask(TaskRecord task, {DateTime? date}) async {
    final targetDate = date == null ? taskDateFor(task) : startOfDay(date);
    final key = dateKey(targetDate);
    final index = store.tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return;
    if (task.hasQuantityTarget) {
      final current = task.quantityCompletedOn(targetDate);
      await adjustTaskQuantity(
        task,
        delta: current >= task.targetQuantity! ? -1 : 1,
        date: targetDate,
      );
      return;
    }
    final completed = [...task.completedDates];
    if (task.frequency == TaskFrequency.once) {
      if (completed.isEmpty) {
        completed.add(key);
      } else {
        completed.clear();
      }
    } else if (task.isCountTask || task.frequency == TaskFrequency.daily) {
      if (completed.contains(key)) {
        completed.remove(key);
      } else {
        completed.add(key);
      }
    } else if (task.isCompletedOn(targetDate)) {
      _removeDatesInRange(
        completed,
        taskPeriodStart(task, targetDate),
        taskPeriodEnd(task, targetDate),
      );
    } else {
      completed.add(key);
    }
    store.tasks[index] = task.copyWith(completedDates: completed);
    await _saveDataChange();
  }

  /// Records one unit of a quantity-target task. Quantity targets are kept
  /// separately from behavior counts such as "4 times per week".
  Future<void> adjustTaskQuantity(
    TaskRecord task, {
    required int delta,
    DateTime? date,
  }) async {
    if (!task.hasQuantityTarget || delta == 0) return;
    final targetDate = date == null ? taskDateFor(task) : startOfDay(date);
    final index = store.tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return;
    // Read the latest record from the store. This matters for press-and-hold
    // repeat actions, whose callback can outlive the widget snapshot that
    // started the gesture.
    final currentTask = store.tasks[index];
    if (!currentTask.hasQuantityTarget) return;
    final current = currentTask.quantityCompletedOn(targetDate);
    final next =
        (current + delta).clamp(0, currentTask.targetQuantity!).toInt();
    if (next == current) return;
    await setTaskQuantity(task, value: next, date: targetDate);
  }

  Future<void> setTaskQuantity(
    TaskRecord task, {
    required int value,
    DateTime? date,
  }) async {
    if (!task.hasQuantityTarget) return;
    final targetDate = date == null ? taskDateFor(task) : startOfDay(date);
    final index = store.tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return;
    final currentTask = store.tasks[index];
    if (!currentTask.hasQuantityTarget) return;
    final periodKey = currentTask.quantityPeriodKey(targetDate);
    final current = currentTask.quantityCompletedOn(targetDate);
    final next = value.clamp(0, currentTask.targetQuantity!).toInt();
    if (next == current) return;
    final progress = {...currentTask.quantityProgress};
    if (next == 0) {
      progress.remove(periodKey);
    } else {
      progress[periodKey] = next;
    }
    final completedDates = [...currentTask.completedDates];
    final key = dateKey(targetDate);
    if (next > 0) {
      if (!completedDates.contains(key)) completedDates.add(key);
    } else if (currentTask.frequency == TaskFrequency.once) {
      completedDates.clear();
    } else {
      completedDates.remove(key);
    }
    store.tasks[index] = currentTask.copyWith(
      quantityProgress: progress,
      completedDates: completedDates,
    );
    await _saveDataChange();
  }

  Future<void> setTaskCount(
    TaskRecord task, {
    required int value,
    DateTime? date,
  }) async {
    if (!task.isCountTask) return;
    final targetDate = date == null ? taskDateFor(task) : startOfDay(date);
    final index = store.tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return;
    final currentTask = store.tasks[index];
    if (!currentTask.isCountTask) return;
    final periodStart = taskPeriodStart(currentTask, targetDate);
    final periodEnd = taskPeriodEnd(currentTask, targetDate);
    final current = currentTask.countInRange(periodStart, periodEnd);
    final next = value.clamp(0, currentTask.targetCount).toInt();
    if (next == current) return;

    final completedDates = [...currentTask.completedDates];
    _removeDatesInRange(completedDates, periodStart, periodEnd);
    for (var offset = 0; offset < next; offset++) {
      completedDates.add(dateKey(periodStart.add(Duration(days: offset))));
    }
    store.tasks[index] = currentTask.copyWith(completedDates: completedDates);
    await _saveDataChange();
  }

  Future<void> setTaskCompleted(
    TaskRecord task, {
    required bool completed,
    DateTime? date,
  }) async {
    final targetDate = date == null ? taskDateFor(task) : startOfDay(date);
    final index = store.tasks.indexWhere((item) => item.id == task.id);
    if (index < 0 || task.isCompletedOn(targetDate) == completed) return;
    if (task.hasQuantityTarget) {
      final progress = {...task.quantityProgress};
      final periodKey = task.quantityPeriodKey(targetDate);
      if (completed) {
        progress[periodKey] = task.targetQuantity!;
      } else {
        progress.remove(periodKey);
      }
      final completedDates = [...task.completedDates];
      if (completed) {
        final key = dateKey(targetDate);
        if (!completedDates.contains(key)) completedDates.add(key);
      } else if (task.frequency == TaskFrequency.once) {
        completedDates.clear();
      } else {
        _removeDatesInRange(
          completedDates,
          taskPeriodStart(task, targetDate),
          taskPeriodEnd(task, targetDate),
        );
      }
      store.tasks[index] = task.copyWith(
        quantityProgress: progress,
        completedDates: completedDates,
      );
      await _saveDataChange();
      return;
    }
    final completedDates = [...task.completedDates];
    if (task.frequency == TaskFrequency.once) {
      if (completed) {
        completedDates.add(dateKey(targetDate));
      } else {
        completedDates.clear();
      }
    } else if (task.frequency == TaskFrequency.daily) {
      final key = dateKey(targetDate);
      if (completed) {
        completedDates.add(key);
      } else {
        completedDates.remove(key);
      }
    } else {
      final periodStart = taskPeriodStart(task, targetDate);
      final periodEnd = taskPeriodEnd(task, targetDate);
      _removeDatesInRange(completedDates, periodStart, periodEnd);
      if (completed) {
        final requiredCount = task.isCountTask ? task.targetCount : 1;
        for (var offset = 0; offset < requiredCount; offset++) {
          completedDates.add(dateKey(periodStart.add(Duration(days: offset))));
        }
      }
    }
    store.tasks[index] = task.copyWith(completedDates: completedDates);
    await _saveDataChange();
  }

  Future<void> toggleSubtask(
    TaskRecord task,
    TaskSubtask subtask, {
    DateTime? date,
  }) async {
    final targetDate = date == null ? taskDateFor(task) : startOfDay(date);
    final key = dateKey(targetDate);
    final taskIndex = store.tasks.indexWhere((item) => item.id == task.id);
    if (taskIndex < 0) return;
    final subtasks = [...task.subtasks];
    final subtaskIndex = subtasks.indexWhere((item) => item.id == subtask.id);
    if (subtaskIndex < 0) return;
    final completedDates = [...subtask.completedDates];
    if (task.frequency == TaskFrequency.once) {
      if (completedDates.isEmpty) {
        completedDates.add(key);
      } else {
        completedDates.clear();
      }
    } else if (task.frequency == TaskFrequency.daily) {
      if (completedDates.contains(key)) {
        completedDates.remove(key);
      } else {
        completedDates.add(key);
      }
    } else if (task.isSubtaskCompletedOn(subtask, targetDate)) {
      _removeDatesInRange(
        completedDates,
        taskPeriodStart(task, targetDate),
        taskPeriodEnd(task, targetDate),
      );
    } else {
      completedDates.add(key);
    }
    subtasks[subtaskIndex] = subtask.copyWith(completedDates: completedDates);
    var updatedTask = task.copyWith(subtasks: subtasks);
    if (!task.isCountTask && !task.hasQuantityTarget && subtasks.isNotEmpty) {
      final allSubtasksCompleted = subtasks
          .every((item) => updatedTask.isSubtaskCompletedOn(item, targetDate));
      final parentDates = [...task.completedDates];
      if (allSubtasksCompleted && !updatedTask.isCompletedOn(targetDate)) {
        parentDates.add(key);
      } else if (!allSubtasksCompleted &&
          updatedTask.isCompletedOn(targetDate)) {
        if (task.frequency == TaskFrequency.once) {
          parentDates.clear();
        } else if (task.frequency == TaskFrequency.daily) {
          parentDates.remove(key);
        } else {
          _removeDatesInRange(
            parentDates,
            taskPeriodStart(task, targetDate),
            taskPeriodEnd(task, targetDate),
          );
        }
      }
      updatedTask = updatedTask.copyWith(completedDates: parentDates);
    }
    store.tasks[taskIndex] = updatedTask;
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
      if (task.hasQuantityTarget) {
        final progress = {...task.quantityProgress};
        final periodKey = task.quantityPeriodKey(date);
        if (completed) {
          progress[periodKey] = task.targetQuantity!;
        } else {
          progress.remove(periodKey);
        }
        if (completed) {
          if (!completedDates.contains(key)) completedDates.add(key);
        } else if (task.frequency == TaskFrequency.once) {
          completedDates.clear();
        } else {
          _removeDatesInRange(
            completedDates,
            taskPeriodStart(task, date),
            taskPeriodEnd(task, date),
          );
        }
        store.tasks[index] = task.copyWith(
          quantityProgress: progress,
          completedDates: completedDates,
        );
        changed = true;
      } else if (task.frequency == TaskFrequency.once) {
        if (completed && completedDates.isEmpty) {
          completedDates.add(key);
          changed = true;
        } else if (!completed && completedDates.isNotEmpty) {
          completedDates.clear();
          changed = true;
        }
      } else if (task.isCountTask || task.frequency == TaskFrequency.daily) {
        if (completed && !completedDates.contains(key)) {
          completedDates.add(key);
          changed = true;
        } else if (!completed && completedDates.remove(key)) {
          changed = true;
        }
      } else if (completed && !task.isCompletedOn(date)) {
        completedDates.add(key);
        changed = true;
      } else if (!completed && task.isCompletedOn(date)) {
        _removeDatesInRange(
          completedDates,
          taskPeriodStart(task, date),
          taskPeriodEnd(task, date),
        );
        changed = true;
      }
      if (!task.hasQuantityTarget) {
        store.tasks[index] = task.copyWith(completedDates: completedDates);
      }
    }
    if (changed) await _saveDataChange();
  }

  Future<void> addTask({
    required String title,
    required List<String> characterIds,
    required TaskFrequency frequency,
    DateTime? startDate,
    DateTime? dueDate,
    required int targetCount,
    int? targetQuantity,
    List<int> weeklyDays = const [],
    List<TaskSubtask> subtasks = const [],
    List<String> tags = const [],
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
          startDate: startDate,
          dueDate: dueDate,
          targetCount: targetCount,
          targetQuantity: targetQuantity,
          weeklyDays: weeklyDays,
          subtasks: subtasks
              .map((item) => TaskSubtask(id: item.id, title: item.title))
              .toList(),
          tags: [...tags],
          note: note,
        )));
    await _saveDataChange();
  }

  Future<void> addInboxTask({
    required String title,
    String? gameId,
    TaskFrequency? frequency,
    DateTime? startDate,
    DateTime? dueDate,
    int targetCount = 1,
    int? targetQuantity,
    List<int> weeklyDays = const [],
    List<TaskSubtask> subtasks = const [],
    List<String> tags = const [],
    String note = '',
  }) async {
    final now = DateTime.now();
    final templateId = 'template-${now.microsecondsSinceEpoch}';
    store.tasks.add(TaskRecord(
      id: '$templateId-inbox',
      templateId: templateId,
      title: title,
      characterId: '',
      frequency: frequency ?? TaskFrequency.once,
      createdAt: now,
      startDate: startDate,
      dueDate: dueDate,
      targetCount: frequency == null ? 1 : targetCount,
      targetQuantity: targetQuantity,
      weeklyDays: frequency == null ? const [] : [...weeklyDays],
      subtasks: subtasks
          .map((item) => TaskSubtask(id: item.id, title: item.title))
          .toList(),
      tags: [...tags],
      note: note,
      inboxGameId: games.any((game) => game.id == gameId)
          ? gameId
          : selectedGameId ?? games.firstOrNull?.id,
      inboxFrequencySet: frequency != null,
    ));
    await _saveDataChange();
  }

  Future<void> updateInboxTask({
    required TaskRecord source,
    required String title,
    TaskFrequency? frequency,
    DateTime? startDate,
    DateTime? dueDate,
    int targetCount = 1,
    int? targetQuantity,
    List<int> weeklyDays = const [],
    List<TaskSubtask> subtasks = const [],
    List<String> tags = const [],
    String note = '',
  }) async {
    final index = store.tasks.indexWhere((task) => task.id == source.id);
    if (index < 0 || !source.isInbox) return;
    store.tasks[index] = source.copyWith(
      title: title,
      frequency: frequency ?? TaskFrequency.once,
      startDate: startDate,
      clearStartDate: startDate == null,
      dueDate: dueDate,
      clearDueDate: dueDate == null,
      targetCount: frequency == null ? 1 : targetCount,
      targetQuantity: targetQuantity,
      clearTargetQuantity: targetQuantity == null,
      weeklyDays: frequency == null ? const [] : [...weeklyDays],
      subtasks: _mergeSubtasks(source.subtasks, subtasks),
      tags: [...tags],
      note: note,
      inboxFrequencySet: frequency != null,
    );
    await _saveDataChange();
  }

  Future<void> assignInboxTask({
    required TaskRecord source,
    required String title,
    required Set<String> characterIds,
    required TaskFrequency frequency,
    DateTime? startDate,
    DateTime? dueDate,
    required int targetCount,
    int? targetQuantity,
    List<int> weeklyDays = const [],
    List<TaskSubtask> subtasks = const [],
    List<String> tags = const [],
    String note = '',
  }) async {
    if (!source.isInbox || characterIds.isEmpty) return;
    final gameId = source.inboxGameId;
    final validCharacterIds = store.characters
        .where((character) => !character.archived && character.gameId == gameId)
        .map((character) => character.id)
        .where(characterIds.contains)
        .toList();
    if (validCharacterIds.isEmpty) return;
    final assignedAt = DateTime.now();
    store.tasks.removeWhere((task) => task.id == source.id);
    store.tasks.addAll(validCharacterIds.map((characterId) => TaskRecord(
          id: '${source.templateId}-$characterId',
          templateId: source.templateId,
          title: title,
          characterId: characterId,
          frequency: frequency,
          createdAt: assignedAt,
          startDate: startDate,
          dueDate: dueDate,
          targetCount: targetCount,
          targetQuantity: targetQuantity,
          weeklyDays: [...weeklyDays],
          subtasks: subtasks
              .map((item) => TaskSubtask(id: item.id, title: item.title))
              .toList(),
          tags: [...tags],
          note: note,
        )));
    await _saveDataChange();
  }

  Future<void> updateTaskTemplate({
    required TaskRecord source,
    required String title,
    required Set<String> characterIds,
    required TaskFrequency frequency,
    DateTime? startDate,
    DateTime? dueDate,
    required int targetCount,
    int? targetQuantity,
    List<int> weeklyDays = const [],
    List<TaskSubtask> subtasks = const [],
    List<String> tags = const [],
    String note = '',
  }) async {
    if (characterIds.isEmpty) return;
    final linkedTasks = store.tasks
        .where((task) => task.templateId == source.templateId)
        .toList();
    final existingByCharacter = {
      for (final task in linkedTasks) task.characterId: task,
    };
    final assignedAt = DateTime.now();

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
          createdAt: assignedAt,
          startDate: startDate,
          dueDate: dueDate,
          targetCount: targetCount,
          targetQuantity: targetQuantity,
          weeklyDays: [...weeklyDays],
          subtasks: subtasks
              .map((item) => TaskSubtask(id: item.id, title: item.title))
              .toList(),
          tags: [...tags],
          note: note,
        ));
        continue;
      }
      final index = store.tasks.indexWhere((task) => task.id == existing.id);
      if (index < 0) continue;
      store.tasks[index] = existing.copyWith(
        title: title,
        frequency: frequency,
        startDate: startDate,
        clearStartDate: startDate == null,
        dueDate: dueDate,
        clearDueDate: dueDate == null,
        targetCount: targetCount,
        targetQuantity: targetQuantity,
        clearTargetQuantity: targetQuantity == null,
        weeklyDays: [...weeklyDays],
        subtasks: _mergeSubtasks(existing.subtasks, subtasks),
        tags: [...tags],
        note: note,
      );
    }
    await _saveDataChange();
  }

  Future<void> updateTaskRecord({
    required TaskRecord source,
    required String title,
    required TaskFrequency frequency,
    DateTime? startDate,
    DateTime? dueDate,
    required int targetCount,
    int? targetQuantity,
    List<int> weeklyDays = const [],
    List<TaskSubtask> subtasks = const [],
    List<String> tags = const [],
    String note = '',
  }) async {
    final index = store.tasks.indexWhere((task) => task.id == source.id);
    if (index < 0) return;
    store.tasks[index] = source.copyWith(
      title: title,
      frequency: frequency,
      startDate: startDate,
      clearStartDate: startDate == null,
      dueDate: dueDate,
      clearDueDate: dueDate == null,
      targetCount: targetCount,
      targetQuantity: targetQuantity,
      clearTargetQuantity: targetQuantity == null,
      weeklyDays: [...weeklyDays],
      subtasks: _mergeSubtasks(source.subtasks, subtasks),
      tags: [...tags],
      note: note,
    );
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
    final gameId = gameForTask(source)?.id;
    final validCharacterIds = store.characters
        .where((character) => !character.archived && character.gameId == gameId)
        .map((character) => character.id)
        .where((id) =>
            characterIds.contains(id) && !existingCharacterIds.contains(id))
        .toList();
    if (validCharacterIds.isEmpty) return;
    final assignedAt = DateTime.now();
    store.tasks.addAll(validCharacterIds.map((characterId) => TaskRecord(
          id: '${source.templateId}-$characterId',
          templateId: source.templateId,
          title: source.title,
          characterId: characterId,
          frequency: source.frequency,
          createdAt: assignedAt,
          startDate: source.startDate,
          dueDate: source.dueDate,
          targetCount: source.targetCount,
          targetQuantity: source.targetQuantity,
          weeklyDays: [...source.weeklyDays],
          subtasks: source.subtasks
              .map((item) => TaskSubtask(id: item.id, title: item.title))
              .toList(),
          tags: [...source.tags],
          note: source.note,
        )));
    await _saveDataChange();
  }

  Future<List<String>> assignTaskTemplatesToCharacters({
    required Set<String> templateIds,
    required Set<String> characterIds,
  }) async {
    final skipped = <String>[];
    for (final templateId in templateIds) {
      final source = store.tasks
          .where((task) => task.templateId == templateId)
          .firstOrNull;
      if (source == null) continue;
      if (source.isInbox) {
        if (!source.hasConfiguredFrequency) {
          skipped.add(source.title);
          continue;
        }
        await assignInboxTask(
          source: source,
          title: source.title,
          characterIds: characterIds,
          frequency: source.frequency,
          startDate: source.startDate,
          dueDate: source.dueDate,
          targetCount: source.targetCount,
          targetQuantity: source.targetQuantity,
          weeklyDays: source.weeklyDays,
          subtasks: source.subtasks,
          tags: source.tags,
          note: source.note,
        );
      } else {
        await assignExistingTask(
          source: source,
          characterIds: characterIds,
        );
      }
    }
    return skipped;
  }

  Future<void> deleteTask(
    TaskRecord source, {
    bool allLinked = false,
  }) async {
    final before = store.tasks.length;
    if (allLinked && !source.isInbox) {
      store.tasks.removeWhere((task) => task.templateId == source.templateId);
    } else {
      store.tasks.removeWhere((task) => task.id == source.id);
    }
    if (store.tasks.length != before) await _saveDataChange();
  }

  Future<void> setTaskTemplatesArchived(
    Set<String> templateIds, {
    required bool archived,
  }) async {
    var changed = false;
    for (var index = 0; index < store.tasks.length; index++) {
      final task = store.tasks[index];
      if (!templateIds.contains(task.templateId) || task.archived == archived) {
        continue;
      }
      store.tasks[index] = task.copyWith(archived: archived);
      changed = true;
    }
    if (changed) await _saveDataChange();
  }

  Future<void> moveTaskToInbox(
    TaskRecord source, {
    bool allLinked = false,
  }) async {
    if (source.isInbox) return;
    final exists = store.tasks.any((task) => task.id == source.id);
    if (!exists) return;

    if (allLinked) {
      store.tasks.removeWhere((task) => task.templateId == source.templateId);
    } else {
      store.tasks.removeWhere((task) => task.id == source.id);
    }

    final now = DateTime.now();
    final templateId = 'template-${now.microsecondsSinceEpoch}';
    final sourceGameId = store.characters
        .where((character) => character.id == source.characterId)
        .firstOrNull
        ?.gameId;
    store.tasks.add(TaskRecord(
      id: '$templateId-inbox',
      templateId: templateId,
      title: source.title,
      characterId: '',
      frequency: source.frequency,
      createdAt: source.createdAt,
      startDate: source.startDate,
      dueDate: source.dueDate,
      targetCount: source.targetCount,
      targetQuantity: source.targetQuantity,
      weeklyDays: [...source.weeklyDays],
      subtasks: source.subtasks
          .map((item) => TaskSubtask(id: item.id, title: item.title))
          .toList(),
      tags: [...source.tags],
      note: source.note,
      inboxGameId: sourceGameId ?? selectedGameId,
      inboxFrequencySet: true,
    ));
    await _saveDataChange();
  }

  List<TaskSubtask> _mergeSubtasks(
    List<TaskSubtask> existing,
    List<TaskSubtask> definitions,
  ) {
    final existingById = {for (final item in existing) item.id: item};
    return definitions
        .map((definition) => TaskSubtask(
              id: definition.id,
              title: definition.title,
              completedDates: [...?existingById[definition.id]?.completedDates],
            ))
        .toList();
  }

  void _removeDatesInRange(
    List<String> dates,
    DateTime start,
    DateTime end,
  ) {
    dates.removeWhere((value) {
      final date = DateTime.tryParse(value);
      return date != null && !date.isBefore(start) && date.isBefore(end);
    });
  }

  Future<void> addCharacter({
    required String name,
    required String account,
    required String occupation,
    required String gameId,
    Map<String, String> metadataValues = const {},
  }) async {
    final colors = [0xff3c8c72, 0xff66a892, 0xff7fae9e, 0xff4f796c, 0xff91b9aa];
    final character = Character(
      id: 'char-${DateTime.now().microsecondsSinceEpoch}',
      gameId: games.any((game) => game.id == gameId)
          ? gameId
          : selectedGameId ?? games.first.id,
      account: account,
      name: name,
      occupation: occupation,
      metadataValues: metadataValues,
      color: colors[store.characters.length % colors.length],
    );
    // Replace the collection so this also works with immutable seed data
    // supplied by tests or import callers.
    store.characters = [...store.characters, character];
    selectedGameId = character.gameId;
    selectedCharacterId = character.id;
    await _saveDataChange();
  }

  Future<void> addGame(
    String name, {
    int dailyResetMinutes = 0,
    List<GameMetadataField> metadataFields = const [],
  }) async {
    final game = Game(
      id: 'game-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      dailyResetMinutes: dailyResetMinutes,
      metadataFields: metadataFields,
      color: const [
        0xff3c8c72,
        0xff66a892,
        0xff7fae9e,
        0xff4f796c
      ][store.games.length % 4],
    );
    store.games.add(game);
    selectedGameId = game.id;
    selectedCharacterId = null;
    _scheduleTaskDayRefresh();
    await _saveDataChange();
  }

  Future<void> updateGame(
    Game game,
    String name, {
    required int dailyResetMinutes,
    List<GameMetadataField>? metadataFields,
  }) async {
    final index = store.games.indexWhere((item) => item.id == game.id);
    if (index < 0) return;
    store.games[index] = game.copyWith(
      name: name,
      dailyResetMinutes: dailyResetMinutes,
      metadataFields: metadataFields,
    );
    if (metadataFields != null) {
      final fields = {for (final field in metadataFields) field.id: field};
      for (var i = 0; i < store.characters.length; i++) {
        final character = store.characters[i];
        if (character.gameId != game.id) continue;
        final values = <String, String>{};
        for (final entry in character.metadataValues.entries) {
          final field = fields[entry.key];
          if (field == null) continue;
          if (field.type == MetadataFieldType.number &&
              num.tryParse(entry.value) == null) continue;
          if (field.type == MetadataFieldType.choice &&
              !field.options.contains(entry.value)) continue;
          if (field.type == MetadataFieldType.multiChoice) {
            final selected =
                entry.value.split('\n').where(field.options.contains).toList();
            if (selected.isNotEmpty) values[entry.key] = selected.join('\n');
            continue;
          }
          if (field.type == MetadataFieldType.boolean &&
              entry.value != 'true' &&
              entry.value != 'false') continue;
          values[entry.key] = entry.value;
        }
        store.characters[i] = character.copyWith(metadataValues: values);
      }
    }
    _scheduleTaskDayRefresh();
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
    store.tasks.removeWhere((task) =>
        characterIds.contains(task.characterId) || task.inboxGameId == game.id);
    if (selectedGameId == game.id) {
      selectedGameId = games.firstOrNull?.id;
      selectedCharacterId = characters.firstOrNull?.id;
    }
    _scheduleTaskDayRefresh();
    await _saveDataChange();
  }

  Future<void> updateCharacter({
    required Character character,
    required String gameId,
    required String account,
    required String name,
    required String occupation,
    Map<String, String>? metadataValues,
  }) async {
    final index =
        store.characters.indexWhere((item) => item.id == character.id);
    if (index < 0) return;
    store.characters[index] = character.copyWith(
      gameId: gameId,
      account: account,
      name: name,
      occupation: occupation,
      metadataValues: metadataValues,
    );
    if (selectedCharacterId == character.id) {
      selectedGameId = gameId;
    }
    await _saveDataChange();
  }

  Future<void> moveCharacter(
    Character character, {
    required int offset,
  }) async {
    if (offset == 0) return;
    final characterIndexes = <int>[];
    for (var index = 0; index < store.characters.length; index++) {
      final item = store.characters[index];
      if (item.gameId == character.gameId && !item.archived) {
        characterIndexes.add(index);
      }
    }
    final currentPosition = characterIndexes.indexWhere(
      (index) => store.characters[index].id == character.id,
    );
    if (currentPosition < 0) return;
    final targetPosition = currentPosition + offset;
    if (targetPosition < 0 || targetPosition >= characterIndexes.length) {
      return;
    }

    final orderedCharacters = [
      for (final index in characterIndexes) store.characters[index],
    ];
    final moved = orderedCharacters.removeAt(currentPosition);
    orderedCharacters.insert(targetPosition, moved);
    store.characters = [...store.characters];
    for (var index = 0; index < characterIndexes.length; index++) {
      store.characters[characterIndexes[index]] = orderedCharacters[index];
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
    if (selectedCharacterId == character.id) {
      selectedCharacterId = characters.firstOrNull?.id;
    }
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

  Future<void> restoreCharacter(Character character) async {
    final index =
        store.characters.indexWhere((item) => item.id == character.id);
    if (index < 0 || !store.characters[index].archived) return;
    store.characters[index] = character.copyWith(archived: false);
    await _saveDataChange();
  }

  Future<void> restoreCharacters(Set<String> characterIds) async {
    if (characterIds.isEmpty) return;
    var changed = false;
    for (var index = 0; index < store.characters.length; index++) {
      final character = store.characters[index];
      if (character.archived && characterIds.contains(character.id)) {
        store.characters[index] = character.copyWith(archived: false);
        changed = true;
      }
    }
    if (changed) await _saveDataChange();
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
    _disposed = true;
    _autoSyncTimer?.cancel();
    _remoteCheckTimer?.cancel();
    _changeSyncTimer?.cancel();
    _backupCheckRetryTimer?.cancel();
    _taskDayTimer?.cancel();
    _taskDayClockStarted = false;
    super.dispose();
  }

  int completedCountFor(
          List<TaskRecord> source, DateTime start, DateTime end) =>
      source
          .where((task) =>
              task.isCompletedOn(start) || task.countInRange(start, end) > 0)
          .length;

  int completionCount(TaskRecord task, DateTime start, DateTime end) =>
      task.countInRange(start, end);

  double progressFor(List<TaskRecord> source, DateTime start, DateTime end) {
    if (source.isEmpty) return 0;
    final completed = source.map((task) {
      if (task.hasQuantityTarget) {
        return (task.quantityCompletedOn(start) / task.targetQuantity!)
            .clamp(0, 1)
            .toDouble();
      }
      return task.isCountTask
          ? (completionCount(task, start, end) >= task.targetCount ? 1.0 : 0.0)
          : (task.isCompletedOn(start) ? 1.0 : 0.0);
    }).fold<double>(0, (sum, value) => sum + value);
    return completed / source.length;
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
