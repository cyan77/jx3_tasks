import 'package:flutter/material.dart';

import '../../models/task_expiry.dart';
import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../task_editor.dart';
import '../widgets/common.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final tasks = [...state.inboxTasks]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: double.infinity),
        child: Column(
          children: [
            PageHeader(
              title: '收集箱',
              subtitle:
                  '${state.selectedGame?.name ?? '当前游戏'} · 未分配角色的任务，可提前设置周期和截止日期',
              action: FilledButton.icon(
                onPressed: () =>
                    showTaskEditor(context, state, createInInbox: true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('快速记录'),
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? const _EmptyInbox()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _InboxTaskCard(state: state, task: tasks[index]),
                    ),
            ),
          ],
        ),
      ),
    );
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

class _InboxTaskCard extends StatelessWidget {
  const _InboxTaskCard({required this.state, required this.task});

  final AppState state;
  final TaskRecord task;

  @override
  Widget build(BuildContext context) {
    final expiry = taskExpiryStatus(task, state.currentTaskDate);
    final alertColor = expiry == TaskExpiryStatus.overdue
        ? Theme.of(context).colorScheme.error
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
      '未分配角色',
      task.hasConfiguredFrequency ? task.frequency.label : '未设置周期',
      deadline,
    ];
    if (task.subtasks.isNotEmpty) details.add('${task.subtasks.length} 个子任务');
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: expiry == TaskExpiryStatus.normal
                ? Theme.of(context).colorScheme.outlineVariant
                : alertColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showTaskEditor(context, state, task: task),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.inbox_outlined,
                  size: 21, color: AppTheme.accent),
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
              const Icon(Icons.chevron_right, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}
