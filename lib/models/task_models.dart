enum TaskFrequency { once, daily, weekly, monthly, weeklyCount, monthlyCount }

extension TaskFrequencyLabel on TaskFrequency {
  String get label => switch (this) {
        TaskFrequency.once => '一次性',
        TaskFrequency.daily => '每日',
        TaskFrequency.weekly => '每周',
        TaskFrequency.monthly => '每月',
        TaskFrequency.weeklyCount => '每周目标次数',
        TaskFrequency.monthlyCount => '每月目标次数',
      };
}

class Game {
  const Game({
    required this.id,
    required this.name,
    this.color = 0xff2f7d72,
  });

  final String id;
  final String name;
  final int color;

  Game copyWith({String? name}) =>
      Game(id: id, name: name ?? this.name, color: color);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
      };

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as int? ?? 0xff2f7d72,
      );
}

class Character {
  const Character({
    required this.id,
    required this.gameId,
    required this.account,
    required this.name,
    required this.occupation,
    required this.color,
    this.archived = false,
  });

  final String id;
  final String gameId;
  final String account;
  final String name;
  final String occupation;
  final int color;
  final bool archived;

  Character copyWith({
    String? gameId,
    String? account,
    String? name,
    String? occupation,
    bool? archived,
  }) =>
      Character(
        id: id,
        gameId: gameId ?? this.gameId,
        account: account ?? this.account,
        name: name ?? this.name,
        occupation: occupation ?? this.occupation,
        color: color,
        archived: archived ?? this.archived,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameId': gameId,
        'account': account,
        'name': name,
        'occupation': occupation,
        'color': color,
        'archived': archived,
      };

  factory Character.fromJson(Map<String, dynamic> json) => Character(
        id: json['id'] as String,
        gameId: json['gameId'] as String? ?? 'game-jx3',
        account: json['account'] as String? ?? '',
        name: json['name'] as String,
        occupation: json['occupation'] as String? ?? '未分类',
        color: json['color'] as int? ?? 0xff2f7d72,
        archived: json['archived'] as bool? ?? false,
      );
}

class TaskSubtask {
  const TaskSubtask({
    required this.id,
    required this.title,
    this.completedDates = const [],
  });

  final String id;
  final String title;
  final List<String> completedDates;

  bool isDoneOn(DateTime date) => completedDates.contains(dateKey(date));

  int countInRange(DateTime start, DateTime end) => completedDates
      .map(DateTime.tryParse)
      .whereType<DateTime>()
      .where((date) => !date.isBefore(start) && date.isBefore(end))
      .length;

  TaskSubtask copyWith({
    String? title,
    List<String>? completedDates,
  }) =>
      TaskSubtask(
        id: id,
        title: title ?? this.title,
        completedDates: completedDates ?? this.completedDates,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completedDates': completedDates,
      };

  factory TaskSubtask.fromJson(Map<String, dynamic> json) => TaskSubtask(
        id: json['id'] as String,
        title: json['title'] as String,
        completedDates:
            List<String>.from(json['completedDates'] as List? ?? const []),
      );
}

class TaskRecord {
  const TaskRecord({
    required this.id,
    required this.templateId,
    required this.title,
    required this.characterId,
    required this.frequency,
    required this.createdAt,
    this.dueDate,
    this.targetCount = 1,
    this.weeklyDays = const [],
    this.completedDates = const [],
    this.subtasks = const [],
    this.note = '',
    this.inboxGameId,
  });

  final String id;
  final String templateId;
  final String title;
  final String characterId;
  final TaskFrequency frequency;
  final DateTime createdAt;
  final DateTime? dueDate;
  final int targetCount;
  final List<int> weeklyDays;
  final List<String> completedDates;
  final List<TaskSubtask> subtasks;
  final String note;
  final String? inboxGameId;

  bool get isInbox => characterId.isEmpty;

  bool get isCountTask =>
      frequency == TaskFrequency.weeklyCount ||
      frequency == TaskFrequency.monthlyCount;

  TaskRecord copyWith({
    String? title,
    TaskFrequency? frequency,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? targetCount,
    List<int>? weeklyDays,
    List<String>? completedDates,
    List<TaskSubtask>? subtasks,
    String? note,
    String? inboxGameId,
  }) =>
      TaskRecord(
        id: id,
        templateId: templateId,
        title: title ?? this.title,
        characterId: characterId,
        frequency: frequency ?? this.frequency,
        createdAt: createdAt,
        dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
        targetCount: targetCount ?? this.targetCount,
        weeklyDays: weeklyDays ?? this.weeklyDays,
        completedDates: completedDates ?? this.completedDates,
        subtasks: subtasks ?? this.subtasks,
        note: note ?? this.note,
        inboxGameId: inboxGameId ?? this.inboxGameId,
      );

  bool isDoneOn(DateTime date) => completedDates.contains(dateKey(date));

  bool isCompletedOn(DateTime date) => switch (frequency) {
        TaskFrequency.once => completedDates.isNotEmpty,
        TaskFrequency.daily => isDoneOn(date),
        TaskFrequency.weekly =>
          countInRange(startOfWeek(date), startOfWeek(date).add(const Duration(days: 7))) > 0,
        TaskFrequency.monthly =>
          countInRange(startOfMonth(date), DateTime(date.year, date.month + 1)) > 0,
        TaskFrequency.weeklyCount =>
          countInRange(startOfWeek(date), startOfWeek(date).add(const Duration(days: 7))) >= targetCount,
        TaskFrequency.monthlyCount =>
          countInRange(startOfMonth(date), DateTime(date.year, date.month + 1)) >= targetCount,
      };

  bool isVisibleOn(DateTime date) => frequency != TaskFrequency.once ||
      completedDates.isEmpty ||
      isDoneOn(date);

  bool isSubtaskCompletedOn(TaskSubtask subtask, DateTime date) =>
      switch (frequency) {
        TaskFrequency.once => subtask.completedDates.isNotEmpty,
        TaskFrequency.daily => subtask.isDoneOn(date),
        TaskFrequency.weekly || TaskFrequency.weeklyCount =>
          subtask.countInRange(
                startOfWeek(date),
                startOfWeek(date).add(const Duration(days: 7)),
              ) >
              0,
        TaskFrequency.monthly || TaskFrequency.monthlyCount =>
          subtask.countInRange(
                startOfMonth(date),
                DateTime(date.year, date.month + 1),
              ) >
              0,
      };

  bool isScheduledOn(DateTime date) {
    final day = startOfDay(date);
    if (day.isBefore(startOfDay(createdAt))) return false;
    return switch (frequency) {
      TaskFrequency.once => dueDate != null && dateKey(dueDate!) == dateKey(day),
      TaskFrequency.daily => true,
      TaskFrequency.weekly => weeklyDays.isEmpty
          ? day.weekday == (dueDate?.weekday ?? createdAt.weekday)
          : weeklyDays.contains(day.weekday),
      TaskFrequency.monthly => day.day == _clampedMonthlyDay(day),
      TaskFrequency.weeklyCount =>
        weeklyDays.isEmpty || weeklyDays.contains(day.weekday),
      TaskFrequency.monthlyCount => true,
    };
  }

  int _clampedMonthlyDay(DateTime month) {
    final anchorDay = dueDate?.day ?? createdAt.day;
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return anchorDay > lastDay ? lastDay : anchorDay;
  }

  int countInRange(DateTime start, DateTime end) => completedDates
      .map(DateTime.tryParse)
      .whereType<DateTime>()
      .where((date) => !date.isBefore(start) && date.isBefore(end))
      .length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'title': title,
        'characterId': characterId,
        'frequency': frequency.name,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'targetCount': targetCount,
        'weeklyDays': weeklyDays,
        'completedDates': completedDates,
        'subtasks': subtasks.map((item) => item.toJson()).toList(),
        'note': note,
        'inboxGameId': inboxGameId,
      };

  factory TaskRecord.fromJson(Map<String, dynamic> json) => TaskRecord(
        id: json['id'] as String,
        templateId: json['templateId'] as String? ?? json['id'] as String,
        title: json['title'] as String,
        characterId: json['characterId'] as String,
        frequency:
            TaskFrequency.values.byName(json['frequency'] as String? ?? 'once'),
        createdAt: DateTime.parse(json['createdAt'] as String),
        dueDate: json['dueDate'] == null
            ? null
            : DateTime.parse(json['dueDate'] as String),
        targetCount: json['targetCount'] as int? ?? 1,
        weeklyDays: List<int>.from(json['weeklyDays'] as List? ?? const []),
        completedDates:
            List<String>.from(json['completedDates'] as List? ?? const []),
        subtasks: (json['subtasks'] as List? ?? const [])
            .map((item) =>
                TaskSubtask.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        note: json['note'] as String? ?? '',
        inboxGameId: json['inboxGameId'] as String?,
      );
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime startOfWeek(DateTime date) {
  final dayOffset = date.weekday - DateTime.monday;
  return startOfDay(date).subtract(Duration(days: dayOffset));
}

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month);

String twoDigits(int value) => value.toString().padLeft(2, '0');

DateTime taskPeriodStart(TaskRecord task, DateTime date) =>
    task.frequency == TaskFrequency.monthly ||
            task.frequency == TaskFrequency.monthlyCount
        ? startOfMonth(date)
        : startOfWeek(date);

DateTime taskPeriodEnd(TaskRecord task, DateTime date) =>
    task.frequency == TaskFrequency.monthly ||
            task.frequency == TaskFrequency.monthlyCount
        ? DateTime(date.year, date.month + 1)
        : startOfWeek(date).add(const Duration(days: 7));
