import 'package:flutter/material.dart';

import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({required this.state, super.key});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final month = state.focusedMonth;
    final firstDay = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstDay.weekday - 1;
    return Column(
      children: [
        PageHeader(title: '日历 / 时间线', subtitle: '按日期查看任务安排'),
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
                  onPressed: () => state.setMonth(
                      DateTime(DateTime.now().year, DateTime.now().month)),
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
                        year: month.year,
                        month: month.month,
                        days: days,
                        leading: leading),
                    const SizedBox(height: 24),
                    _Upcoming(state: state),
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
      required this.year,
      required this.month,
      required this.days,
      required this.leading});
  final AppState state;
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
      final dateTasks = (state.selectedCharacterId == null
              ? state.tasks
              : state.selectedTasks)
          .where((task) =>
              task.frequency == TaskFrequency.once &&
              task.dueDate != null &&
              dateKey(task.dueDate!) == dateKey(date))
          .toList();
      final done = (state.selectedCharacterId == null
              ? state.tasks
              : state.selectedTasks)
          .where((task) => task.isDoneOn(date))
          .length;
      final isToday = dateKey(date) == dateKey(DateTime.now());
      cells.add(Container(
          padding: EdgeInsets.all(compact ? 6 : 8),
          decoration: BoxDecoration(
              border: Border.all(color: AppTheme.line),
              color: isToday ? const Color(0xfff2f8f6) : Colors.white),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$day',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday ? AppTheme.accent : AppTheme.ink)),
            const Spacer(),
            if (compact && (done > 0 || dateTasks.isNotEmpty))
              Row(children: [
                if (done > 0)
                  Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                          color: AppTheme.accent, shape: BoxShape.circle)),
                if (done > 0 && dateTasks.isNotEmpty) const SizedBox(width: 3),
                if (dateTasks.isNotEmpty)
                  Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                          color: AppTheme.muted, shape: BoxShape.circle)),
              ]),
            if (!compact && done > 0)
              Text('$done 项完成',
                  style: const TextStyle(fontSize: 10, color: AppTheme.accent)),
            if (!compact)
              ...dateTasks.take(2).map((task) => Text(task.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppTheme.muted)))
          ])));
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

class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final tasks = (state.selectedCharacterId == null
            ? state.tasks
            : state.selectedTasks)
        .where((task) => task.dueDate != null)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('截止日期'),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          const Text('暂无设置截止日期的任务',
              style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        ...tasks.map((task) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.event_note_outlined,
                  size: 19, color: AppTheme.muted),
              title: Text(task.title, style: const TextStyle(fontSize: 13)),
              trailing: Text(dueLabel(task.dueDate),
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
            )),
      ],
    );
  }
}
