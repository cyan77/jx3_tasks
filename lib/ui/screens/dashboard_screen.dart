import 'package:flutter/material.dart';

import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../task_editor.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.state, super.key});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final character = state.selectedCharacter;
    if (character == null) {
      return Column(children: [
        const PageHeader(title: '今日待办'),
        _EmptyState(onAdd: () => showCharacterEditor(context, state))
      ]);
    }
    final tasks = state.selectedTasks;
    final today = startOfDay(DateTime.now());
    final doneToday = tasks.where((task) => task.isDoneOn(today)).length;
    final weekDone = tasks
        .where((task) => task.isCountTask
            ? task.countInRange(
                    taskPeriodStart(task, today), taskPeriodEnd(task, today)) >=
                task.targetCount
            : task.isDoneOn(today))
        .length;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 90),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1020),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PageHeader(
                title: '今日待办',
                subtitle: '${_dateText(today)} · ${character.name}',
                action: OutlinedButton.icon(
                    onPressed: () => showTaskEditor(context, state),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('新建任务'))),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _CharacterStrip(state: state)),
            const SizedBox(height: 18),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  Expanded(
                      child: _SummaryCard(
                          label: '今日完成',
                          value:
                              '$doneToday / ${tasks.where((task) => !task.isCountTask).length}',
                          progress:
                              tasks.isEmpty ? 0 : doneToday / tasks.length)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _SummaryCard(
                          label: '本周进度',
                          value: '$weekDone / ${tasks.length}',
                          progress:
                              tasks.isEmpty ? 0 : weekDone / tasks.length)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _SummaryCard(
                          label: '角色总任务',
                          value: '${tasks.length}',
                          progress: 1,
                          showProgress: false))
                ])),
            const SizedBox(height: 26),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SectionTitle('今天',
                    trailing: Text(
                        '$doneToday / ${tasks.where((task) => !task.isCountTask).length}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.muted)))),
            const SizedBox(height: 8),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _TaskList(
                    state: state,
                    tasks: tasks.where((task) => !task.isCountTask).toList(),
                    date: today)),
            const SizedBox(height: 26),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SectionTitle('周期任务',
                    trailing: Text('本周',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.muted)))),
            const SizedBox(height: 8),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _TaskList(
                    state: state,
                    tasks: tasks
                        .where((task) =>
                            task.isCountTask ||
                            task.frequency == TaskFrequency.weekly ||
                            task.frequency == TaskFrequency.monthly)
                        .toList(),
                    date: today,
                    showPeriod: true)),
          ]),
        ),
      ),
    );
  }
}

class _CharacterStrip extends StatelessWidget {
  const _CharacterStrip({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 65,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: state.characters.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == state.characters.length) {
              return OutlinedButton.icon(
                onPressed: () => showCharacterEditor(context, state),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加角色'),
              );
            }
            final character = state.characters[index];
            final selected = character.id == state.selectedCharacterId;
            return InkWell(
              onTap: () => state.selectCharacter(character.id),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                width: 112,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xffeef6f4) : AppTheme.soft,
                  border: Border.all(
                      color: selected ? AppTheme.accent : AppTheme.line),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  children: [
                    CharacterAvatar(character: character, size: 30),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(character.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                              '${state.tasksForCharacter(character.id).length} 个任务',
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.progress,
      this.showProgress = true});
  final String label;
  final String value;
  final double progress;
  final bool showProgress;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(7)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        const SizedBox(height: 7),
        Text(value,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink)),
        if (showProgress) ...[
          const SizedBox(height: 9),
          ProgressLine(value: progress)
        ]
      ]));
}

class _TaskList extends StatelessWidget {
  const _TaskList(
      {required this.state,
      required this.tasks,
      required this.date,
      this.showPeriod = false});
  final AppState state;
  final List<TaskRecord> tasks;
  final DateTime date;
  final bool showPeriod;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty)
      return Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          alignment: Alignment.center,
          child: const Text('暂无任务，今天可以轻松一点',
              style: TextStyle(fontSize: 12, color: AppTheme.muted)));
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(7)),
      child: Column(
        children: tasks.map((task) {
          final count = task.countInRange(
              taskPeriodStart(task, date), taskPeriodEnd(task, date));
          final checked = task.isCountTask
              ? count >= task.targetCount
              : task.isDoneOn(date);
          return ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
            leading: TaskCheck(
                checked: checked, onTap: () => state.toggleTask(task)),
            title: Text(task.title,
                style: TextStyle(
                    fontSize: 14,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    color: checked ? AppTheme.muted : AppTheme.ink)),
            subtitle: Text(
                task.isCountTask
                    ? '$count / ${task.targetCount} 次 · ${task.frequency.label}'
                    : '${task.frequency.label}${task.dueDate == null ? '' : ' · ${dueLabel(task.dueDate)}'}',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
            trailing: showPeriod && task.isCountTask
                ? SizedBox(
                    width: 64,
                    child: ProgressLine(value: count / task.targetCount))
                : null,
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Expanded(
          child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('先添加一个角色',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('角色是任务管理的第一层视角',
            style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        const SizedBox(height: 15),
        FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('添加角色'))
      ])));
}

String _dateText(DateTime date) => '${date.year}年${date.month}月${date.day}日 ${[
      '一',
      '二',
      '三',
      '四',
      '五',
      '六',
      '日'
    ][date.weekday - 1]}';
