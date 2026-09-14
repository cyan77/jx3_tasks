import 'package:flutter/gestures.dart';
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
    final today = state.currentTaskDate;
    final allTasks = state.selectedTasks;
    final todayTasks = allTasks.where((task) {
      if (task.frequency == TaskFrequency.daily) return true;
      if (task.frequency != TaskFrequency.once) return false;
      return task.isVisibleOn(today);
    }).toList()
      ..sort((a, b) => _compareTasks(a, b, today));
    final periodTasks = allTasks
        .where((task) =>
            task.frequency == TaskFrequency.weekly ||
            task.frequency == TaskFrequency.monthly ||
            task.isCountTask)
        .toList()
      ..sort((a, b) => _compareTasks(a, b, today));
    final doneToday =
        todayTasks.where((task) => task.isCompletedOn(today)).length;
    final periodDone =
        periodTasks.where((task) => task.isCompletedOn(today)).length;
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
                    onPressed: () => showTaskEditor(
                          context,
                          state,
                          preselectCurrentCharacter: false,
                        ),
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('新建任务'))),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _CharacterStrip(state: state)),
            const SizedBox(height: 18),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(builder: (context, constraints) {
                  final cards = [
                    _SummaryCard(
                        label: '今日完成',
                        value: '$doneToday / ${todayTasks.length}',
                        progress: todayTasks.isEmpty
                            ? 0
                            : doneToday / todayTasks.length),
                    _SummaryCard(
                        label: '周期进度',
                        value: '$periodDone / ${periodTasks.length}',
                        progress: periodTasks.isEmpty
                            ? 0
                            : periodDone / periodTasks.length),
                    _SummaryCard(
                        label: '角色总任务',
                        value: '${allTasks.length}',
                        progress: 1,
                        showProgress: false),
                  ];
                  if (constraints.maxWidth < 520) {
                    return Column(
                      children: [
                        for (var index = 0; index < cards.length; index++) ...[
                          SizedBox(width: double.infinity, child: cards[index]),
                          if (index < cards.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var index = 0; index < cards.length; index++) ...[
                        Expanded(child: cards[index]),
                        if (index < cards.length - 1)
                          const SizedBox(width: 10),
                      ],
                    ],
                  );
                })),
            const SizedBox(height: 26),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SectionTitle('今天',
                    trailing: Text(
                        '$doneToday / ${todayTasks.length}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.muted)))),
            const SizedBox(height: 8),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _TaskList(
                    state: state,
                    tasks: todayTasks,
                    date: today)),
            const SizedBox(height: 26),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SectionTitle('周期任务',
                    trailing: Text('按当前周期',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.muted)))),
            const SizedBox(height: 8),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _TaskList(
                    state: state,
                    tasks: periodTasks,
                    date: today,
                    showPeriod: true)),
          ]),
        ),
      ),
    );
  }
}

class _CharacterStrip extends StatefulWidget {
  const _CharacterStrip({required this.state});
  final AppState state;

  @override
  State<_CharacterStrip> createState() => _CharacterStripState();
}

class _CharacterStripState extends State<_CharacterStrip> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    final delta = event.scrollDelta.dx != 0
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta == 0) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final position = _controller.position;
      _controller.jumpTo(
        (_controller.offset + delta)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerSignal: _handlePointerSignal,
        child: SizedBox(
          height: 65,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: widget.state.characters.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == widget.state.characters.length) {
                return OutlinedButton.icon(
                  onPressed: () => showCharacterEditor(context, widget.state),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加角色'),
                );
              }
              final character = widget.state.characters[index];
              final selected =
                  character.id == widget.state.selectedCharacterId;
              return InkWell(
                onTap: () => widget.state.selectCharacter(character.id),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  width: 112,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerLow,
                    border: Border.all(
                        color: selected
                            ? AppTheme.accent
                            : Theme.of(context).colorScheme.outlineVariant),
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
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${widget.state.tasksForCharacter(character.id).length} 个任务',
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
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(7)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        const SizedBox(height: 7),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
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
    if (tasks.isEmpty) {
      return Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          alignment: Alignment.center,
          child: const Text('暂无任务，今天可以轻松一点',
              style: TextStyle(fontSize: 12, color: AppTheme.muted)));
    }
    return Container(
      decoration: BoxDecoration(
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(7)),
      child: Column(
        children: tasks.map((task) {
          final linkedTasks = state.tasksForTemplate(task.templateId);
          final canCompleteForMultipleCharacters = linkedTasks.length > 1;
          final count = task.countInRange(
              taskPeriodStart(task, date), taskPeriodEnd(task, date));
          final checked = task.isCountTask
              ? count >= task.targetCount
              : task.isCompletedOn(date);
          return Column(
            children: [
              ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
                leading: TaskCheck(
                    checked: checked, onTap: () => state.toggleTask(task)),
                title: Text(task.title,
                    style: TextStyle(
                        fontSize: 14,
                        decoration:
                            checked ? TextDecoration.lineThrough : null,
                        color: checked
                            ? AppTheme.muted
                            : Theme.of(context).colorScheme.onSurface)),
                subtitle: Text(
                    task.isCountTask
                        ? '$count / ${task.targetCount} 次 · ${task.frequency.label}'
                        : _taskMeta(task, date),
                    style:
                        const TextStyle(fontSize: 11, color: AppTheme.muted)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                        if (canCompleteForMultipleCharacters)
                          const PopupMenuItem(
                            value: 'all',
                            child: Text('编辑所有已分配角色'),
                          ),
                      ],
                    ),
                    if (canCompleteForMultipleCharacters)
                      IconButton(
                        tooltip: '为多个角色完成',
                        onPressed: () => _showMultiCharacterCompletion(
                            context, state, task, date),
                        icon: const Icon(Icons.group_outlined, size: 19),
                      ),
                    if (showPeriod && task.isCountTask)
                      SizedBox(
                        width: 64,
                        child: ProgressLine(value: count / task.targetCount),
                      ),
                  ],
                ),
              ),
              if (task.subtasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(46, 0, 13, 8),
                  child: Column(
                    children: task.subtasks.map((subtask) {
                      final subtaskDone =
                          task.isSubtaskCompletedOn(subtask, date);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
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
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _showMultiCharacterCompletion(
    BuildContext context,
    AppState state,
    TaskRecord task,
    DateTime date,
  ) async {
    final linkedTasks = state.tasksForTemplate(task.templateId);
    final linkedCharacterIds =
        linkedTasks.map((item) => item.characterId).toSet();
    final linkedCharacters = state.characters
        .where((character) => linkedCharacterIds.contains(character.id))
        .toList();
    final selectedIds = <String>{task.characterId};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('多个角色完成 · ${task.title}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('选择角色',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setDialogState(() {
                        if (selectedIds.length == linkedCharacters.length) {
                          selectedIds.clear();
                        } else {
                          selectedIds
                            ..clear()
                            ..addAll(linkedCharacterIds);
                        }
                      }),
                      child: Text(selectedIds.length == linkedCharacters.length
                          ? '取消全选'
                          : '全选'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      children: linkedCharacters
                          .map((character) => CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: selectedIds.contains(character.id),
                                secondary: CharacterAvatar(
                                    character: character, size: 28),
                                title: Text(character.name),
                                subtitle: character.occupation.isEmpty
                                    ? null
                                    : Text(character.occupation),
                                onChanged: (selected) => setDialogState(() {
                                  if (selected == true) {
                                    selectedIds.add(character.id);
                                  } else {
                                    selectedIds.remove(character.id);
                                  }
                                }),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            OutlinedButton(
              onPressed: selectedIds.isEmpty
                  ? null
                  : () async {
                      await state.setTaskCompletionForCharacters(
                        templateId: task.templateId,
                        characterIds: Set.of(selectedIds),
                        date: date,
                        completed: false,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: Text(task.isCountTask ? '取消今日记录' : '取消完成'),
            ),
            FilledButton(
              onPressed: selectedIds.isEmpty
                  ? null
                  : () async {
                      await state.setTaskCompletionForCharacters(
                        templateId: task.templateId,
                        characterIds: Set.of(selectedIds),
                        date: date,
                        completed: true,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: Text(task.isCountTask ? '记录今日一次' : '标记完成'),
            ),
          ],
        ),
      ),
    );
  }
}

int _compareTasks(TaskRecord a, TaskRecord b, DateTime taskDate) {
  final aDone = a.isCompletedOn(taskDate);
  final bDone = b.isCompletedOn(taskDate);
  if (aDone != bDone) return aDone ? 1 : -1;
  if (a.dueDate == null && b.dueDate != null) return 1;
  if (a.dueDate != null && b.dueDate == null) return -1;
  final dueComparison = a.dueDate?.compareTo(b.dueDate!) ?? 0;
  return dueComparison != 0 ? dueComparison : a.title.compareTo(b.title);
}

String _taskMeta(TaskRecord task, DateTime date) {
  final parts = <String>[task.frequency.label];
  if ((task.frequency == TaskFrequency.weekly ||
          task.frequency == TaskFrequency.weeklyCount) &&
      task.weeklyDays.isNotEmpty) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    parts.add(task.weeklyDays.map((day) => '周${labels[day - 1]}').join('、'));
  }
  if (task.dueDate != null) {
    final overdue = task.frequency == TaskFrequency.once &&
        startOfDay(task.dueDate!).isBefore(startOfDay(date)) &&
        !task.isCompletedOn(date);
    parts.add(overdue
        ? '${task.dueDate!.month}/${task.dueDate!.day} 已逾期'
        : dueLabel(task.dueDate));
  }
  return parts.join(' · ');
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
