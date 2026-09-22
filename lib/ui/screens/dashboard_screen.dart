import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/task_expiry.dart';
import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../task_editor.dart';
import '../widgets/common.dart';
import 'sync_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.state, super.key});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.characters.isEmpty) {
      return Column(children: [
        const PageHeader(title: '今日待办'),
        _HomeGameSelector(state: state),
        _EmptyState(onAdd: () => showCharacterEditor(context, state))
      ]);
    }
    final today = state.currentTaskDate;
    final visibleCharacters = state.characters
        .where((character) => _shouldShowCharacter(state, character, today))
        .toList();
    if (visibleCharacters.isEmpty) {
      return Column(children: [
        PageHeader(
          title: '今日待办',
          subtitle: _dateText(today),
          action: OutlinedButton.icon(
            onPressed: () => showTaskEditor(
              context,
              state,
              preselectCurrentCharacter: false,
            ),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('新建任务'),
          ),
        ),
        _HomeGameSelector(state: state),
        const _AllDoneState(),
      ]);
    }
    final character = visibleCharacters
            .where((item) => item.id == state.selectedCharacterId)
            .firstOrNull ??
        visibleCharacters.first;
    if (character.id != state.selectedCharacterId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (state.selectedCharacterId != character.id) {
          state.selectCharacter(character.id);
        }
      });
    }
    final allTasks = state.tasksForCharacter(character.id);
    final todayTasks = _todayTasks(state, allTasks, today)
      ..sort((a, b) => _compareTasks(a, b, today));
    final periodTasks = _periodTasks(state, allTasks, today)
      ..sort((a, b) => _compareTasks(a, b, today));
    final doneToday =
        todayTasks.where((task) => task.isCompletedOn(today)).length;
    final periodDone =
        periodTasks.where((task) => task.isCompletedOn(today)).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 90),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: double.infinity),
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
            _HomeGameSelector(state: state),
            const SizedBox(height: 14),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _CharacterStrip(
                    state: state, characters: visibleCharacters)),
            const SizedBox(height: 18),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final cards = [
                    _SummaryCard(
                        label: '今日完成',
                        value: '$doneToday / ${todayTasks.length}',
                        progress: todayTasks.isEmpty
                            ? 0
                            : doneToday / todayTasks.length,
                        compact: compact),
                    _SummaryCard(
                        label: '周期进度',
                        value: '$periodDone / ${periodTasks.length}',
                        progress: periodTasks.isEmpty
                            ? 0
                            : periodDone / periodTasks.length,
                        compact: compact),
                    _SummaryCard(
                        label: '角色总任务',
                        value: '${allTasks.length}',
                        progress: 1,
                        showProgress: false,
                        compact: compact),
                  ];
                  return Row(
                    children: [
                      for (var index = 0; index < cards.length; index++) ...[
                        Expanded(child: cards[index]),
                        if (index < cards.length - 1)
                          SizedBox(width: compact ? 6 : 10),
                      ],
                    ],
                  );
                })),
            const SizedBox(height: 26),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SectionTitle('今天',
                    trailing: Text('$doneToday / ${todayTasks.length}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.muted)))),
            const SizedBox(height: 8),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _TaskList(state: state, tasks: todayTasks, date: today)),
            const SizedBox(height: 26),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SectionTitle('周期任务',
                    trailing: Text('按当前周期',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.muted)))),
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

class _HomeGameSelector extends StatelessWidget {
  const _HomeGameSelector({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedGame;
    final lastSyncAt = state.lastSyncAt?.toLocal();
    final scheme = Theme.of(context).colorScheme;
    final unfinishedTasks = state.allTasksForSelectedGame
        .where((task) => !task.isCompletedOn(state.taskDateFor(task)))
        .toList();
    final visibleCharacterIds = state.characters.map((item) => item.id).toSet();
    final characterCount = unfinishedTasks
        .map((task) => task.characterId)
        .where(visibleCharacterIds.contains)
        .toSet()
        .length;
    final taskCount = unfinishedTasks.length;
    final menuColor =
        Color.lerp(scheme.surface, scheme.primaryContainer, 0.32)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const ValueKey('home-game-filter'),
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.78),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.sports_esports_outlined,
                        size: 19, color: AppTheme.accent),
                    const SizedBox(width: 9),
                    const Text('当前游戏',
                        style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: PopupMenuButton<String>(
                          key: const ValueKey('home-game-menu'),
                          tooltip: '切换首页游戏',
                          padding: EdgeInsets.zero,
                          position: PopupMenuPosition.under,
                          offset: const Offset(0, 6),
                          elevation: 0,
                          color: menuColor,
                          menuPadding: const EdgeInsets.symmetric(vertical: 4),
                          constraints: const BoxConstraints(
                            minWidth: 120,
                            maxWidth: 220,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.78),
                            ),
                          ),
                          onSelected: state.selectGame,
                          itemBuilder: (context) => state.games
                              .map((game) => PopupMenuItem<String>(
                                    key:
                                        ValueKey('home-game-option-${game.id}'),
                                    value: game.id,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(game.name)),
                                        if (game.id == selected?.id)
                                          const Icon(Icons.check,
                                              size: 18, color: AppTheme.accent),
                                      ],
                                    ),
                                  ))
                              .toList(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  selected?.name ?? '请选择',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.keyboard_arrow_down, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (state.newerRemoteBackup != null)
                      IconButton(
                        tooltip: '发现更新的云端备份，点击恢复',
                        visualDensity: VisualDensity.compact,
                        onPressed: state.restoreBusy || state.syncBusy
                            ? null
                            : () => _restoreNewerBackup(context),
                        icon: state.restoreBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.restore, size: 20),
                      ),
                    if (lastSyncAt != null &&
                        MediaQuery.sizeOf(context).width >= 520)
                      Tooltip(
                        message: '上次成功同步：${_fullSyncTime(lastSyncAt)}',
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6, right: 2),
                          child: Text(
                            '上次成功 ${twoDigits(lastSyncAt.month)}/${twoDigits(lastSyncAt.day)} '
                            '${twoDigits(lastSyncAt.hour)}:${twoDigits(lastSyncAt.minute)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: state.isSyncConfigured ? '立即同步' : '配置同步',
                      visualDensity: VisualDensity.compact,
                      onPressed:
                          state.restoreBusy ? null : () => _sync(context),
                      icon: state.syncBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              state.isSyncConfigured
                                  ? Icons.cloud_sync_outlined
                                  : Icons.cloud_off_outlined,
                              size: 20,
                            ),
                    ),
                  ],
                ),
                if (lastSyncAt != null &&
                    MediaQuery.sizeOf(context).width < 520) ...[
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '上次同步成功 ${twoDigits(lastSyncAt.month)}/${twoDigits(lastSyncAt.day)} '
                        '${twoDigits(lastSyncAt.hour)}:${twoDigits(lastSyncAt.minute)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              '$characterCount 个角色 · $taskCount 个任务',
              key: const ValueKey('home-game-counts'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sync(BuildContext context) async {
    if (!state.isSyncConfigured) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SyncScreen(state: state)),
      );
      return;
    }
    final success = await state.syncNow();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(state.syncMessage ?? (success ? '已同步' : '同步失败'))),
    );
  }

  Future<void> _restoreNewerBackup(BuildContext context) async {
    final backup = state.newerRemoteBackup;
    if (backup == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复更新的云端备份？'),
        content: Text(
          '本地所有游戏、角色、任务和完成记录将被“${backup.name}”替换。这次恢复不会在云端创建新备份；如需保留当前本地数据，请先手动上传备份。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await state.restoreBackup(backup);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已从云端备份恢复')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复失败：$error')),
      );
    }
  }
}

String _fullSyncTime(DateTime date) =>
    '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)} '
    '${twoDigits(date.hour)}:${twoDigits(date.minute)}:${twoDigits(date.second)}';

List<TaskRecord> _todayTasks(
  AppState state,
  List<TaskRecord> tasks,
  DateTime today,
) =>
    tasks.where((task) {
      if (task.frequency == TaskFrequency.daily) {
        return state.hasTaskStartedBy(task, today);
      }
      if (task.frequency != TaskFrequency.once) return false;
      return state.hasTaskStartedBy(task, today) && task.isVisibleOn(today);
    }).toList();

List<TaskRecord> _periodTasks(
  AppState state,
  List<TaskRecord> tasks,
  DateTime today,
) =>
    tasks
        .where((task) =>
            state.hasTaskStartedBy(task, today) &&
            (task.frequency == TaskFrequency.weekly ||
                task.frequency == TaskFrequency.monthly ||
                task.isCountTask))
        .toList();

List<TaskRecord> _pendingTasksForCharacter(
  AppState state,
  Character character,
  DateTime today,
) {
  final tasks = state.tasksForCharacter(character.id);
  return [
    ..._todayTasks(state, tasks, today),
    ..._periodTasks(state, tasks, today),
  ].where((task) => !task.isCompletedOn(today)).toList();
}

bool _shouldShowCharacter(
  AppState state,
  Character character,
  DateTime today,
) {
  if (_pendingTasksForCharacter(state, character, today).isNotEmpty) {
    return true;
  }
  final todayKey = dateKey(today);
  final tasks = state.tasksForCharacter(character.id);
  final visibleTasks = [
    ..._todayTasks(state, tasks, today),
    ..._periodTasks(state, tasks, today),
  ];
  return visibleTasks.any((task) => task.completedDates.contains(todayKey));
}

class _CharacterStrip extends StatefulWidget {
  const _CharacterStrip({required this.state, required this.characters});
  final AppState state;
  final List<Character> characters;

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
    final delta =
        event.scrollDelta.dx != 0 ? event.scrollDelta.dx : event.scrollDelta.dy;
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
            itemCount: widget.characters.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == widget.characters.length) {
                return OutlinedButton.icon(
                  onPressed: () => showCharacterEditor(context, widget.state),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加角色'),
                );
              }
              final character = widget.characters[index];
              final selected = character.id == widget.state.selectedCharacterId;
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
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                                _characterStatusText(
                                  widget.state,
                                  character,
                                  widget.state.currentTaskDate,
                                ),
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

String _characterStatusText(
  AppState state,
  Character character,
  DateTime today,
) {
  final pending = _pendingTasksForCharacter(state, character, today).length;
  return pending == 0 ? '今日已完成' : '$pending 个待办';
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.progress,
      this.showProgress = true,
      this.compact = false});
  final String label;
  final String value;
  final double progress;
  final bool showProgress;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.all(compact ? 9 : 13),
      decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(compact ? 10 : 7)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 10.5 : 12,
            color: AppTheme.muted,
          ),
        ),
        SizedBox(height: compact ? 4 : 7),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: compact ? 17 : 20,
                fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        if (showProgress) ...[
          SizedBox(height: compact ? 6 : 9),
          ProgressLine(value: progress)
        ] else if (compact)
          const SizedBox(height: 11),
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
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(7)),
      child: Column(
        children: tasks.map((task) {
          final linkedTasks = state.tasksForTemplate(task.templateId);
          final canCompleteForMultipleCharacters = linkedTasks.length > 1;
          final count = task.hasQuantityTarget
              ? task.quantityCompletedOn(date)
              : task.countInRange(
                  taskPeriodStart(task, date), taskPeriodEnd(task, date));
          final checked = task.isCompletedOn(date);
          final expiry = taskExpiryStatus(task, date);
          final expiringSoon = expiry == TaskExpiryStatus.expiringSoon;
          final overdue = expiry == TaskExpiryStatus.overdue;
          final alertColor = overdue
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.warningDark
                  : AppTheme.warning;
          return Column(
            children: [
              ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
                leading: task.hasQuantityTarget
                    ? _QuantityStepper(
                        value: count,
                        target: task.targetQuantity!,
                        onDecrement: count == 0
                            ? null
                            : () => state.adjustTaskQuantity(
                                  task,
                                  delta: -1,
                                  date: date,
                                ),
                        onIncrement: count >= task.targetQuantity!
                            ? null
                            : () => state.adjustTaskQuantity(
                                  task,
                                  delta: 1,
                                  date: date,
                                ),
                        onSetValue: (value) => state.setTaskQuantity(
                          task,
                          value: value,
                          date: date,
                        ),
                      )
                    : TaskCheck(
                        checked: checked, onTap: () => state.toggleTask(task)),
                title: Text(task.title,
                    style: TextStyle(
                        fontSize: 14,
                        decoration: checked ? TextDecoration.lineThrough : null,
                        color: checked
                            ? AppTheme.muted
                            : expiringSoon || overdue
                                ? alertColor
                                : Theme.of(context).colorScheme.onSurface)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    task.hasQuantityTarget
                        ? Text(
                            '$count / ${task.targetQuantity} 数量 · ${task.frequency.label}',
                            style: TextStyle(
                                fontSize: 11,
                                color: expiringSoon || overdue
                                    ? alertColor
                                    : AppTheme.muted))
                        : task.isCountTask
                            ? InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () => _editTaskCount(
                                  context,
                                  state,
                                  task,
                                  count,
                                  date,
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    '$count / ${task.targetCount} 行为次数 · ${task.frequency.label}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: expiringSoon || overdue
                                            ? alertColor
                                            : AppTheme.muted),
                                  ),
                                ),
                              )
                            : Text(_taskMeta(task, date),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: expiringSoon || overdue
                                        ? alertColor
                                        : AppTheme.muted)),
                    if (task.tags.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      TaskTags(tags: task.tags, compact: true),
                    ],
                  ],
                ),
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
                    if (showPeriod &&
                        (task.isCountTask || task.hasQuantityTarget))
                      SizedBox(
                        width: 64,
                        child: ProgressLine(
                          value: count /
                              (task.hasQuantityTarget
                                  ? task.targetQuantity!
                                  : task.targetCount),
                        ),
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
                              onTap: () => state.toggleSubtask(task, subtask,
                                  date: date),
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

  Future<void> _editTaskCount(
    BuildContext context,
    AppState state,
    TaskRecord task,
    int value,
    DateTime date,
  ) async {
    final controller = TextEditingController(text: '$value');
    final nextValue = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑当前行为次数'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: '当前次数（0-${task.targetCount}）'),
          onSubmitted: (text) {
            final parsed = int.tryParse(text.trim());
            if (parsed != null) Navigator.pop(dialogContext, parsed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null) Navigator.pop(dialogContext, parsed);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nextValue != null) {
      await state.setTaskCount(task, value: nextValue, date: date);
    }
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.target,
    required this.onDecrement,
    required this.onIncrement,
    this.onSetValue,
  });

  final int value;
  final int target;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final ValueChanged<int>? onSetValue;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepeatingIconButton(
            tooltip: '减少 1，长按可连续减少',
            onPressed: onDecrement,
            icon: Icons.remove_circle_outline,
            size: 18,
          ),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onSetValue == null ? null : () => _editValue(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
              child: Text('$value/$target',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
          RepeatingIconButton(
            tooltip: '记录 1 个，长按可连续增加',
            onPressed: onIncrement,
            icon: Icons.add_circle_outline,
            size: 18,
          ),
        ],
      );

  Future<void> _editValue(BuildContext context) async {
    final controller = TextEditingController(text: '$value');
    final nextValue = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑当前数量'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: '当前数量（0-$target）'),
          onSubmitted: (text) {
            final parsed = int.tryParse(text.trim());
            if (parsed != null) Navigator.pop(dialogContext, parsed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null) Navigator.pop(dialogContext, parsed);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nextValue != null) onSetValue?.call(nextValue);
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
    final expiry = taskExpiryStatus(task, date);
    parts.add(switch (expiry) {
      TaskExpiryStatus.overdue =>
        '${task.dueDate!.month}/${task.dueDate!.day} 已逾期',
      TaskExpiryStatus.expiringSoon =>
        '${task.dueDate!.month}/${task.dueDate!.day} 即将过期',
      TaskExpiryStatus.normal => dueLabel(task.dueDate),
    });
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

class _AllDoneState extends StatelessWidget {
  const _AllDoneState();

  @override
  Widget build(BuildContext context) => const Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.done_all, size: 42, color: AppTheme.accent),
              SizedBox(height: 12),
              Text('今天的任务都完成了',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text('有新的待办或进入下一个周期时，角色会重新显示',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ],
          ),
        ),
      );
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
