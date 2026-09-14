import 'package:flutter/material.dart';

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
    final filteredGame = state.games
        .where((game) => game.id == validGameFilter)
        .firstOrNull;
    final now = DateTime.now();
    final calendarToday =
        filteredGame?.taskDayAt(now) ?? startOfDay(now);
    final month = state.focusedMonth;
    final firstDay = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstDay.weekday - 1;
    return Column(
      children: [
        PageHeader(
          title: '日历 / 时间线',
          subtitle: '汇总所有角色的任务，可按游戏筛选',
          action: SizedBox(
            width: 180,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: validGameFilter,
                isExpanded: true,
                icon: const Icon(Icons.filter_list, size: 18),
                items: [
                  const DropdownMenuItem(
                    value: _allGames,
                    child: Text('全部游戏'),
                  ),
                  ...state.games.map((game) => DropdownMenuItem(
                        value: game.id,
                        child: Text(game.name),
                      )),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _gameFilterId = value);
                  }
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              IconButton(
                  onPressed: () =>
                      state.setMonth(DateTime(month.year, month.month - 1)),
                  icon: const Icon(Icons.chevron_left, size: 20)),
              Text('${month.year}年 ${month.month}月',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              IconButton(
                  onPressed: () =>
                      state.setMonth(DateTime(month.year, month.month + 1)),
                  icon: const Icon(Icons.chevron_right, size: 20)),
              const Spacer(),
              TextButton(
                  onPressed: () => state.selectCalendarDate(calendarToday),
                  child: const Text('回到本月')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    _CalendarGrid(
                        state: state,
                        tasks: tasks,
                        today: calendarToday,
                        year: month.year,
                        month: month.month,
                        days: days,
                        leading: leading),
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
  const _CalendarGrid(
      {required this.state,
      required this.tasks,
      required this.today,
      required this.year,
      required this.month,
      required this.days,
      required this.leading});
  final AppState state;
  final List<TaskRecord> tasks;
  final DateTime today;
  final int year;
  final int month;
  final int days;
  final int leading;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final cells = <Widget>[];
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    for (final day in weekdays) {
      cells.add(Container(
          alignment: Alignment.center,
          padding: EdgeInsets.only(bottom: compact ? 5 : 8),
          child: Text(day,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600))));
    }
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= days; day++) {
      final date = DateTime(year, month, day);
      final dateTasks = tasks
          .where((task) => state.isTaskScheduledOn(task, date))
          .toList();
      final done = tasks.where((task) => task.isDoneOn(date)).length;
      final isToday = dateKey(date) == dateKey(today);
      final isSelected =
          dateKey(date) == dateKey(state.selectedCalendarDate);
      cells.add(InkWell(
        onTap: () => state.selectCalendarDate(date),
        child: Container(
            padding: EdgeInsets.all(compact ? 6 : 8),
            decoration: BoxDecoration(
                border: Border.all(
                    color: isSelected
                        ? AppTheme.accent
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1),
                color: isSelected || isToday
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$day',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isToday || isSelected
                          ? AppTheme.accent
                          : Theme.of(context).colorScheme.onSurface)),
              const Spacer(),
              if (compact && (done > 0 || dateTasks.isNotEmpty))
                Row(children: [
                  if (done > 0)
                    Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            color: AppTheme.accent, shape: BoxShape.circle)),
                  if (done > 0 && dateTasks.isNotEmpty)
                    const SizedBox(width: 3),
                  if (dateTasks.isNotEmpty)
                    Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            color: AppTheme.muted, shape: BoxShape.circle)),
                ]),
              if (!compact && done > 0)
                Text('$done 项完成',
                    style:
                        const TextStyle(fontSize: 10, color: AppTheme.accent)),
              if (!compact)
                ...dateTasks.take(2).map((task) => Text(
                    _calendarGridLabel(state, task),
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 10, color: AppTheme.muted)))
            ])),
      ));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final cellWidth = constraints.maxWidth / 7;
      final cellHeight = compact ? 58.0 : 86.0;
      return GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: cellWidth / cellHeight,
          children: cells);
    });
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
  });
  final AppState state;
  final TaskRecord task;
  final DateTime date;
  final bool showDueDate;

  @override
  Widget build(BuildContext context) {
    final linkedCount = state.store.tasks
        .where((item) =>
            !item.isInbox && item.templateId == task.templateId)
        .length;
    final character = state.store.characters
        .where((item) => item.id == task.characterId)
        .firstOrNull;
    final game = state.games
        .where((item) => item.id == character?.gameId)
        .firstOrNull;
    final checked = task.isCompletedOn(date);
    final details = [
      if (game != null) game.name,
      if (character != null) character.name,
      task.frequency.label,
    ];
    return ListTile(
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
              : Theme.of(context).colorScheme.onSurface,
          decoration: checked ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(details.join(' · '),
          style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDueDate)
            Text(
              _deadlineLabel(state, task),
              style: TextStyle(
                fontSize: 12,
                color: _isOverdue(state, task)
                    ? const Color(0xffb94a48)
                    : AppTheme.muted,
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

int _compareCalendarTasks(AppState state, TaskRecord a, TaskRecord b) {
  String gameAndCharacter(TaskRecord task) {
    final character = state.store.characters
        .where((item) => item.id == task.characterId)
        .firstOrNull;
    final game = state.games
        .where((item) => item.id == character?.gameId)
        .firstOrNull;
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

bool _isOverdue(AppState state, TaskRecord task) {
  final taskDate = state.taskDateFor(task);
  return task.dueDate != null &&
      startOfDay(task.dueDate!).isBefore(taskDate) &&
      !task.isCompletedOn(taskDate);
}

String _deadlineLabel(AppState state, TaskRecord task) =>
    _isOverdue(state, task)
        ? '${task.dueDate!.month}/${task.dueDate!.day} 已逾期'
        : dueLabel(task.dueDate);
