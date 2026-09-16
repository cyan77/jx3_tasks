import 'package:flutter/material.dart';

import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../task_editor.dart';
import '../widgets/common.dart';

class MatrixScreen extends StatefulWidget {
  const MatrixScreen({required this.state, super.key});
  final AppState state;

  @override
  State<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends State<MatrixScreen> {
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();
  final selectedTemplateIds = <String>{};
  String query = '';
  bool searchExpanded = false;

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final templates = <String, List<TaskRecord>>{};
    for (final task in state.allTasksForSelectedGame) {
      templates.putIfAbsent(task.templateId, () => []).add(task);
    }
    selectedTemplateIds.removeWhere((id) => !templates.containsKey(id));
    final visibleTemplates = templates.values.where((tasks) {
      if (query.isEmpty) return true;
      final normalized = query.toLowerCase();
      final characterNames = _charactersFor(tasks)
          .map((character) => character.name.toLowerCase());
      return tasks.first.title.toLowerCase().contains(normalized) ||
          characterNames.any((name) => name.contains(normalized));
    }).toList()
      ..sort((a, b) => a.first.title.compareTo(b.first.title));
    final visibleIds = visibleTemplates
        .map((tasks) => tasks.first.templateId)
        .toSet();
    final selectedCount = selectedTemplateIds.length;

    return Column(children: [
      PageHeader(
        title: '全部任务',
        subtitle: '${templates.length} 项任务 · 可单选或多选管理',
        titleAction: SizedBox(
          width: searchExpanded ? 230 : 40,
          child: searchExpanded
              ? TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  onChanged: (value) => setState(() => query = value.trim()),
                  decoration: InputDecoration(
                    hintText: '搜索任务或角色',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: IconButton(
                      tooltip: '关闭搜索',
                      onPressed: _closeSearch,
                      icon: const Icon(Icons.close, size: 17),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: '搜索任务',
                  onPressed: _openSearch,
                  icon: const Icon(Icons.search, size: 20),
                ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _SelectionBar(
          selectedCount: selectedCount,
          allVisibleSelected: visibleIds.isNotEmpty &&
              visibleIds.every(selectedTemplateIds.contains),
          onToggleAll: () => _toggleAll(visibleIds),
          onClear: selectedCount == 0
              ? null
              : () => setState(selectedTemplateIds.clear),
          onAssign: selectedCount == 0 ? null : _assignSelected,
          onDelete: selectedCount == 0 ? null : _deleteSelected,
          onCreate: () => showTaskEditor(
            context,
            state,
            preselectCurrentCharacter: false,
          ),
        ),
      ),
      Expanded(
        child: visibleTemplates.isEmpty
            ? _EmptyTasks(hasQuery: query.isNotEmpty)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                itemCount: visibleTemplates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tasks = visibleTemplates[index];
                  final templateId = tasks.first.templateId;
                  return _TaskManagementTile(
                    tasks: tasks,
                    characters: _charactersFor(tasks),
                    selected: selectedTemplateIds.contains(templateId),
                    onSelected: (value) => _setSelected(templateId, value),
                    onEdit: () => showTaskEditor(
                      context,
                      state,
                      task: tasks.first,
                      syncAll: !tasks.first.isInbox,
                    ),
                    onDelete: () => _deleteTemplates({templateId}),
                  );
                },
              ),
      ),
    ]);
  }

  List<Character> _charactersFor(List<TaskRecord> tasks) {
    final ids = tasks.map((task) => task.characterId).toSet();
    return state.store.characters
        .where((character) => ids.contains(character.id))
        .toList();
  }

  void _setSelected(String templateId, bool value) {
    setState(() {
      value
          ? selectedTemplateIds.add(templateId)
          : selectedTemplateIds.remove(templateId);
    });
  }

  void _toggleAll(Set<String> visibleIds) {
    setState(() {
      if (visibleIds.isNotEmpty &&
          visibleIds.every(selectedTemplateIds.contains)) {
        selectedTemplateIds.removeAll(visibleIds);
      } else {
        selectedTemplateIds.addAll(visibleIds);
      }
    });
  }

  Future<void> _assignSelected() async {
    if (selectedTemplateIds.length == 1) {
      final templateId = selectedTemplateIds.single;
      final task = state.allTasksForSelectedGame
          .where((item) => item.templateId == templateId)
          .firstOrNull;
      if (task != null) {
        await showTaskEditor(
          context,
          state,
          task: task,
          syncAll: !task.isInbox,
        );
      }
      return;
    }
    final characterIds = await _showCharacterAssignmentDialog();
    if (characterIds == null || characterIds.isEmpty) return;
    final skipped = await state.assignTaskTemplatesToCharacters(
      templateIds: Set.of(selectedTemplateIds),
      characterIds: characterIds,
    );
    if (!mounted) return;
    setState(selectedTemplateIds.clear);
    final message = skipped.isEmpty
        ? '已批量分配任务'
        : '已分配可用任务；${skipped.length} 项收集箱任务尚未设置周期';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Set<String>?> _showCharacterAssignmentDialog() async {
    final selected = <String>{};
    return showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('批量追加分配角色'),
          content: SizedBox(
            width: 420,
            child: state.characters.isEmpty
                ? const Text('当前游戏没有可分配的角色')
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.characters
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

  Future<void> _deleteSelected() =>
      _deleteTemplates(Set.of(selectedTemplateIds));

  Future<void> _deleteTemplates(Set<String> templateIds) async {
    if (templateIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(templateIds.length == 1 ? '删除任务？' : '批量删除任务？'),
        content: Text(templateIds.length == 1
            ? '将删除该任务的全部角色分配和完成记录。'
            : '将删除选中的 ${templateIds.length} 项任务、全部角色分配和完成记录。'),
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
    for (final templateId in templateIds) {
      final task = state.store.tasks
          .where((item) => item.templateId == templateId)
          .firstOrNull;
      if (task != null) await state.deleteTask(task, allLinked: !task.isInbox);
    }
    if (mounted) setState(() => selectedTemplateIds.removeAll(templateIds));
  }

  void _openSearch() {
    setState(() => searchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    searchController.clear();
    searchFocusNode.unfocus();
    setState(() {
      query = '';
      searchExpanded = false;
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedCount,
    required this.allVisibleSelected,
    required this.onToggleAll,
    required this.onClear,
    required this.onAssign,
    required this.onDelete,
    required this.onCreate,
  });

  final int selectedCount;
  final bool allVisibleSelected;
  final VoidCallback onToggleAll;
  final VoidCallback? onClear;
  final VoidCallback? onAssign;
  final VoidCallback? onDelete;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
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
          if (selectedCount > 0)
            Text('已选 $selectedCount 项',
                style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          if (selectedCount > 0)
            TextButton(onPressed: onClear, child: const Text('清除选择')),
          OutlinedButton.icon(
            onPressed: onAssign,
            icon: const Icon(Icons.person_add_alt_outlined, size: 17),
            label: Text(selectedCount == 1 ? '管理分配' : '批量分配'),
          ),
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 17),
            label: const Text('删除'),
          ),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('新建任务'),
          ),
        ],
      );
}

class _TaskManagementTile extends StatelessWidget {
  const _TaskManagementTile({
    required this.tasks,
    required this.characters,
    required this.selected,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TaskRecord> tasks;
  final List<Character> characters;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final task = tasks.first;
    final scheme = Theme.of(context).colorScheme;
    final details = <String>[
      task.hasConfiguredFrequency ? task.frequency.label : '未设置周期',
      if (task.startDate != null) '开始 ${dueLabel(task.startDate)}',
      if (task.dueDate != null) dueLabel(task.dueDate),
      if (task.isCountTask) '目标 ${task.targetCount} 次',
    ];
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.45)
          : scheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelected(!selected),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onSelected(value ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(details.join(' · '),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.muted)),
                  const SizedBox(height: 8),
                  if (task.isInbox)
                    const _StatusChip(
                      icon: Icons.inbox_outlined,
                      label: '收集箱 · 未分配角色',
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: characters
                          .map((character) =>
                              _CharacterChip(character: character))
                          .toList(),
                    ),
                  if (task.note.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(task.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.muted)),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '任务操作',
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑与管理分配')),
                PopupMenuItem(value: 'delete', child: Text('删除任务')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _CharacterChip extends StatelessWidget {
  const _CharacterChip({required this.character});
  final Character character;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CharacterAvatar(character: character, size: 18),
          const SizedBox(width: 5),
          Text(character.name, style: const TextStyle(fontSize: 11)),
          if (character.archived) ...[
            const SizedBox(width: 4),
            const Text('已归档',
                style: TextStyle(fontSize: 9, color: AppTheme.muted)),
          ],
        ]),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppTheme.muted),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
        ]),
      );
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          hasQuery ? '没有符合搜索条件的任务' : '还没有任务',
          style: const TextStyle(color: AppTheme.muted),
        ),
      );
}
