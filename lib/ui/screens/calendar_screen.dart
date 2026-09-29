import 'package:flutter/material.dart';

import '../../models/task_expiry.dart';
import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../task_editor.dart';
import '../widgets/common.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({required this.state, super.key});
  final AppState state;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

enum _CalendarView { month, week }

class _CalendarScreenState extends State<CalendarScreen> {
  static const _allGames = '';
  String _gameFilterId = _allGames;

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final validGameFilter = state.games.any((game) => game.id == _gameFilterId)
        ? _gameFilterId
        : _allGames;
    final tasks = state.calendarTasks(
        gameId: validGameFilter == _allGames ? null : validGameFilter);
    final filteredGame =
        state.games.where((game) => game.id == validGameFilter).firstOrNull;
    final now = DateTime.now();
    final calendarToday = filteredGame?.taskDayAt(now) ?? startOfDay(now);
    final month = state.focusedMonth;
    final selectedDate = startOfDay(state.selectedCalendarDate);
    final weekStart = selectedDate.subtract(
      Duration(days: selectedDate.weekday - DateTime.monday),
    );
    final view =
        state.calendarWeekView ? _CalendarView.week : _CalendarView.month;
    final scheme = Theme.of(context).colorScheme;
    final filterFill =
        Color.lerp(scheme.surface, scheme.primaryContainer, 0.42)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '日历 / 时间线',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: Container(
                      key: const ValueKey('calendar-game-filter'),
                      height: 40,
                      padding: const EdgeInsets.only(left: 10, right: 5),
                      decoration: BoxDecoration(
                        color: filterFill.withValues(alpha: 0.78),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.20),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        position: PopupMenuPosition.under,
                        offset: const Offset(0, 6),
                        elevation: 0,
                        menuPadding: const EdgeInsets.symmetric(vertical: 4),
                        constraints: const BoxConstraints.tightFor(width: 150),
                        color: filterFill,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: scheme.primary.withValues(alpha: 0.20),
                          ),
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: _allGames,
                            height: 40,
                            child: Text(
                              '全部游戏',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...state.games.map((game) => PopupMenuItem(
                                value: game.id,
                                height: 40,
                                child: Text(
                                  game.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              )),
                        ],
                        onSelected: (value) {
                          setState(() => _gameFilterId = value);
                        },
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              filteredGame?.name ?? '全部游戏',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.expand_more,
                              size: 16, color: AppTheme.accent),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '汇总所有角色的任务，可按游戏筛选',
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 2),
          child: Row(
            children: [
              SegmentedButton<_CalendarView>(
                key: const ValueKey('calendar-view-toggle'),
                segments: const [
                  ButtonSegment(
                    value: _CalendarView.month,
                    label: Text('月'),
                  ),
                  ButtonSegment(
                    value: _CalendarView.week,
                    label: Text('周'),
                  ),
                ],
                selected: {view},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  ),
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                onSelectionChanged: (value) {
                  state.setCalendarWeekView(value.first == _CalendarView.week);
                  setState(() {});
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: () => state.selectCalendarDate(calendarToday),
                child: Text(view == _CalendarView.month ? '回到本月' : '回到本周'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  if (view == _CalendarView.month) {
                    state.setMonth(DateTime(month.year, month.month - 1));
                  } else {
                    state.selectCalendarDate(
                        selectedDate.subtract(const Duration(days: 7)));
                  }
                },
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Expanded(
                child: Text(
                  view == _CalendarView.month
                      ? '${month.year}年 ${month.month}月'
                      : _weekLabel(weekStart),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  if (view == _CalendarView.month) {
                    state.setMonth(DateTime(month.year, month.month + 1));
                  } else {
                    state.selectCalendarDate(
                        selectedDate.add(const Duration(days: 7)));
                  }
                },
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: double.infinity),
                child: Column(
                  children: [
                    _CalendarGrid(
                      state: state,
                      tasks: tasks,
                      today: calendarToday,
                      selectedDate: selectedDate,
                      month: month,
                      weekStart: weekStart,
                      view: view,
                    ),
                    const SizedBox(height: 18),
                    _DayTasks(
                        state: state,
                        tasks: tasks,
                        date: state.selectedCalendarDate),
                    const SizedBox(height: 24),
                    _Upcoming(state: state, tasks: tasks),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.state,
    required this.tasks,
    required this.today,
    required this.selectedDate,
    required this.month,
    required this.weekStart,
    required this.view,
  });
  final AppState state;
  final List<TaskRecord> tasks;
  final DateTime today;
  final DateTime selectedDate;
  final DateTime month;
  final DateTime weekStart;
  final _CalendarView view;

  @override
  Widget build(BuildContext context) {
    return view == _CalendarView.month
        ? _CalendarMonthGrid(
            state: state,
            tasks: tasks,
            today: today,
            selectedDate: selectedDate,
            month: month,
          )
        : _CalendarWeekGrid(
            state: state,
            tasks: tasks,
            today: today,
            selectedDate: selectedDate,
            weekStart: weekStart,
          );
  }
}

class _CalendarMonthGrid extends StatelessWidget {
  const _CalendarMonthGrid({
    required this.state,
    required this.tasks,
    required this.today,
    required this.selectedDate,
    required this.month,
  });
  final AppState state;
  final List<TaskRecord> tasks;
  final DateTime today;
  final DateTime selectedDate;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final firstDay = DateTime(month.year, month.month, 1);
    final leading = firstDay.weekday - DateTime.monday;
    final days = DateTime(month.year, month.month + 1, 0).day;
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return Column(
      children: [
        Row(
          children: weekdays
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 5),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leading + days,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: compact ? 50 : 56,
          ),
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox();
            final date = DateTime(month.year, month.month, index - leading + 1);
            return _CalendarMonthDay(
              state: state,
              tasks: tasks,
              date: date,
              today: today,
              selectedDate: selectedDate,
            );
          },
        ),
      ],
    );
  }
}

class _CalendarMonthDay extends StatelessWidget {
  const _CalendarMonthDay({
    required this.state,
    required this.tasks,
    required this.date,
    required this.today,
    required this.selectedDate,
  });
  final AppState state;
  final List<TaskRecord> tasks;
  final DateTime date;
  final DateTime today;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isToday = dateKey(date) == dateKey(today);
    final isSelected = dateKey(date) == dateKey(selectedDate);
    final hasDeadline = _hasDeadlineOn(tasks, date);
    final textColor = isSelected
        ? scheme.onPrimary
        : isToday
            ? scheme.primary
            : scheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => state.selectCalendarDate(date),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? scheme.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(color: scheme.primary, width: 1.5)
                  : null,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 5,
            child: hasDeadline
                ? Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isSelected ? scheme.primary : AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _CalendarWeekGrid extends StatelessWidget {
  const _CalendarWeekGrid({
    required this.state,
    required this.tasks,
    required this.today,
    required this.selectedDate,
    required this.weekStart,
  });
  final AppState state;
  final List<TaskRecord> tasks;
  final DateTime today;
  final DateTime selectedDate;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final dates = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    return Column(
      children: [
        Row(
          children: weekdays
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 7),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: dates.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: compact ? 108 : 132,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) => _CalendarWeekDay(
            state: state,
            tasks: tasks,
            date: dates[index],
            today: today,
            selectedDate: selectedDate,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _CalendarWeekDay extends StatelessWidget {
  const _CalendarWeekDay({
    required this.state,
    required this.tasks,
    required this.date,
    required this.today,
    required this.selectedDate,
    required this.compact,
  });
  final AppState state;
  final List<TaskRecord> tasks;
  final DateTime date;
  final DateTime today;
  final DateTime selectedDate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateTasks =
        tasks.where((task) => state.isTaskScheduledOn(task, date)).toList();
    final isToday = dateKey(date) == dateKey(today);
    final isSelected = dateKey(date) == dateKey(selectedDate);
    final hasDeadline = _hasDeadlineOn(tasks, date);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => state.selectCalendarDate(date),
      child: Container(
        padding: EdgeInsets.all(compact ? 6 : 9),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer
              : isToday
                  ? scheme.surfaceContainerHighest
                  : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected || isToday
                ? scheme.primary.withValues(alpha: isSelected ? 0.75 : 0.4)
                : scheme.outlineVariant,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 19,
              width: double.infinity,
              child: Stack(
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: compact ? 13 : 15,
                      fontWeight: isToday || isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  if (hasDeadline)
                    Positioned(
                      top: 7,
                      right: 0,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: compact
                  ? dateTasks.isEmpty
                      ? const SizedBox()
                      : Center(
                          child: Text(
                            '${dateTasks.length} 项',
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dateTasks.isEmpty)
                          const Text(
                            '无任务',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.muted,
                            ),
                          ),
                        ...dateTasks.take(3).map(
                              (task) => Text(
                                _calendarGridLabel(state, task),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ),
                        if (dateTasks.length > 3)
                          Text(
                            '+${dateTasks.length - 3} 项',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.muted,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTasks extends StatelessWidget {
  const _DayTasks(
      {required this.state, required this.tasks, required this.date});
  final AppState state;
  final List<TaskRecord> tasks;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks.where((task) {
      return task.isDoneOn(date) || state.isTaskScheduledOn(task, date);
    }).toList()
      ..sort((a, b) => _compareCalendarTasks(state, a, b));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('${date.month}月${date.day}日任务'),
        const SizedBox(height: 8),
        if (visibleTasks.isEmpty)
          const Text('当天没有任务',
              style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        ...visibleTasks.map((task) => _InteractiveTaskTile(
              state: state,
              task: task,
              date: date,
              showSubtasks: true,
            )),
      ],
    );
  }
}

class _InteractiveTaskTile extends StatelessWidget {
  const _InteractiveTaskTile({
    required this.state,
    required this.task,
    required this.date,
    this.showDueDate = false,
    this.showSubtasks = false,
  });
  final AppState state;
  final TaskRecord task;
  final DateTime date;
  final bool showDueDate;
  final bool showSubtasks;

  @override
  Widget build(BuildContext context) {
    final canShowSubtasks =
        showSubtasks && MediaQuery.sizeOf(context).width >= 600;
    final linkedCount = state.store.tasks
        .where((item) => !item.isInbox && item.templateId == task.templateId)
        .length;
    final character = state.store.characters
        .where((item) => item.id == task.characterId)
        .firstOrNull;
    final game =
        state.games.where((item) => item.id == character?.gameId).firstOrNull;
    final checked = task.isCompletedOn(date);
    final expiry = taskExpiryStatus(task, state.taskDateFor(task));
    final alertColor = expiry == TaskExpiryStatus.overdue
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).brightness == Brightness.dark
            ? AppTheme.warningDark
            : AppTheme.warning;
    final details = [
      if (game != null) game.name,
      if (character != null) character.name,
      task.frequency.label,
      if (task.hasQuantityTarget)
        '${task.quantityCompletedOn(date)}/${task.targetQuantity} 数量',
      if (task.isCountTask)
        '${task.countInRange(taskPeriodStart(task, date), taskPeriodEnd(task, date))}/${task.targetCount} 行为',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          onTap: () => state.toggleTask(task, date: date),
          leading: TaskCheck(
            checked: checked,
            onTap: () => state.toggleTask(task, date: date),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              fontSize: 13,
              color: checked
                  ? AppTheme.muted
                  : expiry == TaskExpiryStatus.normal
                      ? Theme.of(context).colorScheme.onSurface
                      : alertColor,
              decoration: checked ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(details.join(' · '),
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
              if (task.tags.isNotEmpty) ...[
                const SizedBox(height: 5),
                TaskTags(tags: task.tags, compact: true),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDueDate)
                Text(
                  _deadlineLabel(state, task),
                  style: TextStyle(
                    fontSize: 12,
                    color: expiry == TaskExpiryStatus.normal
                        ? AppTheme.muted
                        : alertColor,
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: '编辑任务',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onSelected: (value) => showTaskEditor(
                  context,
                  state,
                  task: task,
                  syncAll: value == 'all',
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'single',
                    child: Text('仅编辑当前角色'),
                  ),
                  if (linkedCount > 1)
                    const PopupMenuItem(
                      value: 'all',
                      child: Text('编辑所有已分配角色'),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (canShowSubtasks && task.subtasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 40, right: 44, bottom: 8),
            child: Column(
              children: task.subtasks.map((subtask) {
                final subtaskDone = task.isSubtaskCompletedOn(subtask, date);
                return InkWell(
                  key: ValueKey('calendar-subtask-${task.id}-${subtask.id}'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => state.toggleSubtask(task, subtask, date: date),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        TaskCheck(
                          checked: subtaskDone,
                          onTap: () =>
                              state.toggleSubtask(task, subtask, date: date),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            subtask.title,
                            style: TextStyle(
                              fontSize: 12,
                              color: subtaskDone
                                  ? AppTheme.muted
                                  : Theme.of(context).colorScheme.onSurface,
                              decoration: subtaskDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.state, required this.tasks});
  final AppState state;
  final List<TaskRecord> tasks;

  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks
        .where((task) =>
            task.dueDate != null &&
            !task.isCompletedOn(state.taskDateFor(task)))
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('截止日期'),
        const SizedBox(height: 8),
        if (visibleTasks.isEmpty)
          const Text('暂无设置截止日期的任务',
              style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        ...visibleTasks.map((task) => _InteractiveTaskTile(
              state: state,
              task: task,
              date: task.dueDate!,
              showDueDate: true,
            )),
      ],
    );
  }
}

String _weekLabel(DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  if (weekStart.year == weekEnd.year && weekStart.month == weekEnd.month) {
    return '${weekStart.month}月${weekStart.day}日–${weekEnd.day}日';
  }
  if (weekStart.year == weekEnd.year) {
    return '${weekStart.month}月${weekStart.day}日–${weekEnd.month}月${weekEnd.day}日';
  }
  return '${weekStart.year}/${weekStart.month}/${weekStart.day}–${weekEnd.year}/${weekEnd.month}/${weekEnd.day}';
}

bool _hasDeadlineOn(List<TaskRecord> tasks, DateTime date) {
  return tasks.any((task) =>
      task.dueDate != null && dateKey(task.dueDate!) == dateKey(date));
}

int _compareCalendarTasks(AppState state, TaskRecord a, TaskRecord b) {
  String gameAndCharacter(TaskRecord task) {
    final character = state.store.characters
        .where((item) => item.id == task.characterId)
        .firstOrNull;
    final game =
        state.games.where((item) => item.id == character?.gameId).firstOrNull;
    return '${game?.name ?? ''}\u0000${character?.name ?? ''}';
  }

  final characterComparison =
      gameAndCharacter(a).compareTo(gameAndCharacter(b));
  if (characterComparison != 0) return characterComparison;
  return a.title.compareTo(b.title);
}

String _calendarGridLabel(AppState state, TaskRecord task) {
  final character = state.store.characters
      .where((item) => item.id == task.characterId)
      .firstOrNull;
  return character == null ? task.title : '${character.name} · ${task.title}';
}

String _deadlineLabel(AppState state, TaskRecord task) {
  return switch (taskExpiryStatus(task, state.taskDateFor(task))) {
    TaskExpiryStatus.overdue =>
      '${task.dueDate!.month}/${task.dueDate!.day} 已逾期',
    TaskExpiryStatus.expiringSoon =>
      '${task.dueDate!.month}/${task.dueDate!.day} 即将过期',
    TaskExpiryStatus.normal => dueLabel(task.dueDate),
  };
}
