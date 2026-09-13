import 'package:flutter/material.dart';

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
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          children: [
            PageHeader(
              title: '收集箱',
              subtitle:
                  '${state.selectedGame?.name ?? '当前游戏'} · 先记下来，之后再分配角色、设置周期和截止日期',
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
    final details = <String>['未分配角色', '未设置计划'];
    if (task.subtasks.isNotEmpty) details.add('${task.subtasks.length} 个子任务');
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.line),
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
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(details.join(' · '),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.muted)),
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
