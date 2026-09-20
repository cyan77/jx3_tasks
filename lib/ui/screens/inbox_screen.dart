import 'package:flutter/material.dart';

import '../../models/task_expiry.dart';
import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../task_editor.dart';
import '../widgets/common.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({required this.state, super.key});

  final AppState state;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final selectedTaskIds = <String>{};

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 800;
    final tasks = [...state.inboxTasks]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final visibleIds = tasks.map((task) => task.id).toSet();
    selectedTaskIds.removeWhere((id) => !visibleIds.contains(id));
    final selectionMode = selectedTaskIds.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: double.infinity),
        child: Column(
          children: [
            PageHeader(
              title: '收集箱',
              subtitle: selectionMode
                  ? '已选 ${selectedTaskIds.length} 项'
                  : '全部游戏 · 未分配角色的任务，可提前设置周期和截止日期',
              action: FilledButton.icon(
                onPressed: () =>
                    showTaskEditor(context, state, createInInbox: true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('快速记录'),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: tasks.isEmpty
                        ? const _EmptyInbox()
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              4,
                              24,
                              selectionMode ? (desktop ? 92 : 172) : 32,
                            ),
                            itemCount: tasks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              final selected =
                                  selectedTaskIds.contains(task.id);
                              return _InboxTaskCard(
                                state: state,
                                task: task,
                                selected: selected,
                                selectionMode: selectionMode,
                                onSelect: () => _setSelected(
                                  task.id,
                                  !selected,
                                ),
                              );
                            },
                          ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: desktop ? 12 : 82,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      reverseDuration: const Duration(milliseconds: 160),
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                          reverseCurve: Curves.easeInCubic,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.16, 0),
                              end: Offset.zero,
                            ).animate(curved),
                            child: child,
                          ),
                        );
                      },
                      child: selectionMode
                          ? _InboxSelectionBar(
                              key: const ValueKey(
                                  'inbox-selection-actions'),
                              selectedCount: selectedTaskIds.length,
                              allVisibleSelected: visibleIds.isNotEmpty &&
                                  visibleIds.every(selectedTaskIds.contains),
                              onToggleAll: () => _toggleAll(visibleIds),
                              onClear: () =>
                                  setState(selectedTaskIds.clear),
                              onAssign: _assignSelected,
                              onArchive: _archiveSelected,
                              onDelete: _deleteSelected,
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('inbox-selection-empty'),
                            ),
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

  void _setSelected(String taskId, bool selected) {
    setState(() {
      selected ? selectedTaskIds.add(taskId) : selectedTaskIds.remove(taskId);
    });
  }

  void _toggleAll(Set<String> visibleIds) {
    setState(() {
      if (visibleIds.isNotEmpty &&
          visibleIds.every(selectedTaskIds.contains)) {
        selectedTaskIds.removeAll(visibleIds);
      } else {
        selectedTaskIds.addAll(visibleIds);
      }
    });
  }

  List<TaskRecord> get _selectedTasks => state.store.tasks
      .where((task) => selectedTaskIds.contains(task.id) && task.isInbox)
      .toList();

  Future<void> _assignSelected() async {
    final tasks = _selectedTasks;
    if (tasks.isEmpty) return;
    if (tasks.length == 1) {
      await showTaskEditor(context, state, task: tasks.single);
      if (mounted) setState(selectedTaskIds.clear);
      return;
    }

    final gameIds =
        tasks.map((task) => task.inboxGameId).whereType<String>().toSet();
    if (gameIds.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('批量分配时请选择同一个游戏的任务')),
      );
      return;
    }

    final characterIds = await _showCharacterAssignmentDialog(
      gameIds.single,
      tasks.map((task) => task.templateId).toSet(),
    );
    if (characterIds == null || characterIds.isEmpty) return;

    final taskCountBefore = state.store.tasks.length;
    final skipped = await state.assignTaskTemplatesToCharacters(
      templateIds: tasks.map((task) => task.templateId).toSet(),
      characterIds: characterIds,
    );
    final assignedCount = state.store.tasks.length - taskCountBefore;
    if (!mounted) return;
    setState(selectedTaskIds.clear);
    final message = assignedCount == 0
        ? skipped.isNotEmpty
            ? '所选收集箱任务尚未设置周期，暂时无法分配'
            : '所选角色已经拥有这些任务'
        : skipped.isEmpty
            ? '已新增 $assignedCount 条角色任务'
            : '已新增 $assignedCount 条角色任务；'
                '${skipped.length} 项任务尚未设置周期';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Set<String>?> _showCharacterAssignmentDialog(
    String gameId,
    Set<String> templateIds,
  ) {
    final selected = <String>{};
    final characters = state.store.characters.where((character) {
      if (character.archived || character.gameId != gameId) return false;
      return templateIds.any((templateId) => !state.store.tasks.any(
            (task) =>
                task.templateId == templateId &&
                task.characterId == character.id &&
                !task.isInbox,
          ));
    }).toList();

    return showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.all(16),
          title: const Text('批量分配任务'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.sizeOf(context).height * 0.55,
            ),
            child: characters.isEmpty
                ? const Text('当前游戏中的角色都已分配所选任务')
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: characters
                          .map((character) => FilterChip(
                                label: Text(character.name),
                                selected: selected.contains(character.id),
                                onSelected: (value) => setDialogState(() {
                                  value
                                      ? selected.add(character.id)
                                      : selected.remove(character.id);
                                }),
                              ))
                          .toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, Set.of(selected)),
              child: const Text('分配'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _archiveSelected() async {
    final templateIds =
        _selectedTasks.map((task) => task.templateId).toSet();
    await state.setTaskTemplatesArchived(templateIds, archived: true);
    if (mounted) setState(selectedTaskIds.clear);
  }

  Future<void> _deleteSelected() async {
    final tasks = _selectedTasks;
    if (tasks.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tasks.length == 1 ? '删除任务？' : '批量删除任务？'),
        content: Text(tasks.length == 1
            ? '将永久删除这条收集箱任务。'
            : '将永久删除选中的 ${tasks.length} 条收集箱任务。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffb94a48),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final task in tasks) {
      await state.deleteTask(task);
    }
    if (mounted) setState(selectedTaskIds.clear);
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined,
                  size: 42, color: AppTheme.muted.withAlpha(150)),
              const SizedBox(height: 12),
              const Text('收集箱是空的',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              const Text('还没想好分给谁、什么时候做，也可以先记录。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ],
          ),
        ),
      );
}

class _InboxSelectionBar extends StatelessWidget {
  const _InboxSelectionBar({
    required this.selectedCount,
    required this.allVisibleSelected,
    required this.onToggleAll,
    required this.onClear,
    required this.onAssign,
    required this.onArchive,
    required this.onDelete,
    super.key,
  });

  final int selectedCount;
  final bool allVisibleSelected;
  final VoidCallback onToggleAll;
  final VoidCallback onClear;
  final VoidCallback onAssign;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: onToggleAll,
        icon: Icon(
          allVisibleSelected
              ? Icons.deselect_outlined
              : Icons.select_all_outlined,
          size: 17,
        ),
        label: Text(allVisibleSelected ? '取消全选' : '全选'),
      ),
      Text('已选 $selectedCount 项',
          style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
      TextButton(onPressed: onClear, child: const Text('退出')),
      OutlinedButton.icon(
        onPressed: onAssign,
        icon: const Icon(Icons.person_add_alt_outlined, size: 17),
        label: Text(selectedCount == 1 ? '分配任务' : '批量分配'),
      ),
      OutlinedButton.icon(
        onPressed: onArchive,
        icon: const Icon(Icons.archive_outlined, size: 17),
        label: const Text('归档'),
      ),
      OutlinedButton.icon(
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline, size: 17),
        label: const Text('删除'),
      ),
    ];
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 0,
      color: scheme.surface.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 58,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                actions[index],
                if (index < actions.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxTaskCard extends StatelessWidget {
  const _InboxTaskCard({
    required this.state,
    required this.task,
    required this.selected,
    required this.selectionMode,
    required this.onSelect,
  });

  final AppState state;
  final TaskRecord task;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final expiry = taskExpiryStatus(task, state.taskDateFor(task));
    final scheme = Theme.of(context).colorScheme;
    final alertColor = expiry == TaskExpiryStatus.overdue
        ? scheme.error
        : Theme.of(context).brightness == Brightness.dark
            ? AppTheme.warningDark
            : AppTheme.warning;
    final deadline = switch (expiry) {
      TaskExpiryStatus.overdue =>
        '${task.dueDate!.month}/${task.dueDate!.day} 已逾期',
      TaskExpiryStatus.expiringSoon =>
        '${task.dueDate!.month}/${task.dueDate!.day} 即将过期',
      TaskExpiryStatus.normal =>
        task.dueDate == null ? '未设置截止日期' : dueLabel(task.dueDate),
    };
    final details = <String>[
      state.gameForTask(task)?.name ?? '未知游戏',
      '未分配角色',
      task.hasConfiguredFrequency ? task.frequency.label : '未设置周期',
      deadline,
    ];
    if (task.subtasks.isNotEmpty) {
      details.add('${task.subtasks.length} 个子任务');
    }
    final cardColor =
        selected ? scheme.primaryContainer.withValues(alpha: 0.82) : scheme.surface;
    final borderColor = selected
        ? scheme.primary
        : expiry == TaskExpiryStatus.normal
            ? scheme.outlineVariant
            : alertColor;
    return Material(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onLongPress: onSelect,
        onTap: selectionMode
            ? onSelect
            : () => showTaskEditor(context, state, task: task),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.inbox_outlined,
                key: selected
                    ? ValueKey('selected-inbox-task-${task.id}')
                    : null,
                size: 21,
                color: selected ? scheme.primary : AppTheme.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: expiry == TaskExpiryStatus.normal
                                ? null
                                : alertColor)),
                    const SizedBox(height: 4),
                    Text(details.join(' · '),
                        style: TextStyle(
                            fontSize: 11,
                            color: expiry == TaskExpiryStatus.normal
                                ? AppTheme.muted
                                : alertColor)),
                    if (task.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      TaskTags(tags: task.tags, compact: true),
                    ],
                    if (task.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(task.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.muted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!selectionMode)
                const Icon(Icons.chevron_right, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}
