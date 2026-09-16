import 'package:flutter/material.dart';

import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../task_editor.dart';
import '../widgets/common.dart';

enum _CompletionFilter { all, incomplete, partial, complete }

enum _TemplateCompletion { unassigned, incomplete, partial, complete }

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
  String? gameFilterId;
  String? characterFilterId;
  _CompletionFilter completionFilter = _CompletionFilter.all;

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final templates = <String, List<TaskRecord>>{};
    for (final task in state.store.tasks) {
      templates.putIfAbsent(task.templateId, () => []).add(task);
    }
    selectedTemplateIds.removeWhere((id) => !templates.containsKey(id));
    final visibleTemplates = templates.values.where((tasks) {
      if (!_matchesGame(tasks) ||
          !_matchesCharacter(tasks) ||
          !_matchesCompletion(tasks)) {
        return false;
      }
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
        subtitle:
            '显示 ${visibleTemplates.length} / ${templates.length} 项 · 可单选或多选管理',
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _FilterBar(
            games: state.games,
            characters: _filterCharacters,
            gameId: gameFilterId,
            characterId: characterFilterId,
            completion: completionFilter,
            onGameChanged: (value) => setState(() {
              gameFilterId = value;
              selectedTemplateIds.clear();
              if (characterFilterId != null &&
                  characterFilterId != _FilterBar.inboxValue &&
                  !_filterCharacters.any(
                      (character) => character.id == characterFilterId)) {
                characterFilterId = null;
              }
            }),
            onCharacterChanged: (value) => setState(() {
              characterFilterId = value;
              selectedTemplateIds.clear();
            }),
            onCompletionChanged: (value) => setState(() {
              completionFilter = value;
              selectedTemplateIds.clear();
            }),
            onReset: _hasActiveFilters ? _resetFilters : null,
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
          onMoveToInbox:
              selectedCount == 0 ? null : _moveSelectedToInbox,
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
            ? const _EmptyTasks()
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
                    gameName: _gameNameFor(tasks),
                    completion: _completionFor(tasks),
                    selected: selectedTemplateIds.contains(templateId),
                    onSelected: (value) => _setSelected(templateId, value),
                    onEdit: () => showTaskEditor(
                      context,
                      state,
                      task: tasks.first,
                      syncAll: !tasks.first.isInbox,
                    ),
                    onMoveToInbox: () =>
                        _moveTemplatesToInbox({templateId}),
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

  List<Character> get _filterCharacters => state.store.characters
      .where((character) =>
          gameFilterId == null || character.gameId == gameFilterId)
      .toList();

  bool get _hasActiveFilters => gameFilterId != null ||
      characterFilterId != null ||
      completionFilter != _CompletionFilter.all;

  String? _gameIdFor(List<TaskRecord> tasks) {
    final task = tasks.first;
    if (task.isInbox) return task.inboxGameId;
    return state.store.characters
        .where((character) => character.id == task.characterId)
        .firstOrNull
        ?.gameId;
  }

  String _gameNameFor(List<TaskRecord> tasks) {
    final gameId = _gameIdFor(tasks);
    return state.games
            .where((game) => game.id == gameId)
            .firstOrNull
            ?.name ??
        '未知游戏';
  }

  _TemplateCompletion _completionFor(List<TaskRecord> tasks) {
    final assigned = tasks.where((task) => !task.isInbox).toList();
    if (assigned.isEmpty) return _TemplateCompletion.unassigned;
    final completed = assigned
        .where((task) => task.isCompletedOn(state.taskDateFor(task)))
        .length;
    if (completed == 0) return _TemplateCompletion.incomplete;
    if (completed == assigned.length) return _TemplateCompletion.complete;
    return _TemplateCompletion.partial;
  }

  bool _matchesGame(List<TaskRecord> tasks) =>
      gameFilterId == null || _gameIdFor(tasks) == gameFilterId;

  bool _matchesCharacter(List<TaskRecord> tasks) {
    if (characterFilterId == null) return true;
    if (characterFilterId == _FilterBar.inboxValue) {
      return tasks.any((task) => task.isInbox);
    }
    return tasks.any((task) => task.characterId == characterFilterId);
  }

  bool _matchesCompletion(List<TaskRecord> tasks) {
    final completion = _completionFor(tasks);
    return switch (completionFilter) {
      _CompletionFilter.all => true,
      _CompletionFilter.incomplete =>
        completion == _TemplateCompletion.incomplete,
      _CompletionFilter.partial => completion == _TemplateCompletion.partial,
      _CompletionFilter.complete => completion == _TemplateCompletion.complete,
    };
  }

  void _resetFilters() => setState(() {
        gameFilterId = null;
        characterFilterId = null;
        completionFilter = _CompletionFilter.all;
        selectedTemplateIds.clear();
      });

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
      final task = state.store.tasks
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
    final selectedTasks = selectedTemplateIds
        .map((templateId) => state.store.tasks
            .where((task) => task.templateId == templateId)
            .firstOrNull)
        .whereType<TaskRecord>()
        .toList();
    final gameIds = selectedTasks
        .map((task) => _gameIdFor([task]))
        .whereType<String>()
        .toSet();
    if (gameIds.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('批量分配时请选择同一个游戏的任务')),
      );
      return;
    }
    final characterIds = await _showCharacterAssignmentDialog(gameIds.single);
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

  Future<Set<String>?> _showCharacterAssignmentDialog(String gameId) async {
    final selected = <String>{};
    final characters = state.store.characters
        .where((character) =>
            !character.archived && character.gameId == gameId)
        .toList();
    return showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('批量追加分配角色'),
          content: SizedBox(
            width: 420,
            child: characters.isEmpty
                ? const Text('当前游戏没有可分配的角色')
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

  Future<void> _deleteSelected() =>
      _deleteTemplates(Set.of(selectedTemplateIds));

  Future<void> _moveSelectedToInbox() =>
      _moveTemplatesToInbox(Set.of(selectedTemplateIds));

  Future<void> _moveTemplatesToInbox(Set<String> templateIds) async {
    final assignedTemplateIds = templateIds.where((templateId) => state
        .store.tasks
        .any((task) => task.templateId == templateId && !task.isInbox)).toSet();
    if (assignedTemplateIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所选任务已经在收集箱中')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(assignedTemplateIds.length == 1
            ? '移到收集箱？'
            : '批量移到收集箱？'),
        content: Text(
          '将取消 ${assignedTemplateIds.length} 项任务的全部角色分配，保留任务设置并清除完成记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移到收集箱'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final templateId in assignedTemplateIds) {
      final task = state.store.tasks
          .where((item) => item.templateId == templateId && !item.isInbox)
          .firstOrNull;
      if (task != null) await state.moveTaskToInbox(task, allLinked: true);
    }
    if (mounted) {
      setState(() => selectedTemplateIds.removeAll(assignedTemplateIds));
    }
  }

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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.games,
    required this.characters,
    required this.gameId,
    required this.characterId,
    required this.completion,
    required this.onGameChanged,
    required this.onCharacterChanged,
    required this.onCompletionChanged,
    required this.onReset,
  });

  static const inboxValue = '__inbox__';
  static const allGamesValue = '__all_games__';
  static const allCharactersValue = '__all_characters__';
  final List<Game> games;
  final List<Character> characters;
  final String? gameId;
  final String? characterId;
  final _CompletionFilter completion;
  final ValueChanged<String?> onGameChanged;
  final ValueChanged<String?> onCharacterChanged;
  final ValueChanged<_CompletionFilter> onCompletionChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _FilterDropdown<String>(
            tooltip: '按游戏筛选',
            value: gameId ?? allGamesValue,
            items: [
              const DropdownMenuItem(
                  value: allGamesValue, child: Text('全部游戏')),
              ...games.map((game) =>
                  DropdownMenuItem(value: game.id, child: Text(game.name))),
            ],
            onChanged: (value) => onGameChanged(
                value == allGamesValue ? null : value),
          ),
          _FilterDropdown<String>(
            tooltip: '按角色筛选',
            value: characterId ?? allCharactersValue,
            items: [
              const DropdownMenuItem(
                  value: allCharactersValue, child: Text('全部角色')),
              const DropdownMenuItem(
                  value: inboxValue, child: Text('收集箱 / 未分配')),
              ...characters.map((character) => DropdownMenuItem(
                  value: character.id, child: Text(character.name))),
            ],
            onChanged: (value) => onCharacterChanged(
                value == allCharactersValue ? null : value),
          ),
          _FilterDropdown<_CompletionFilter>(
            tooltip: '按完成状态筛选',
            value: completion,
            items: const [
              DropdownMenuItem(
                  value: _CompletionFilter.all, child: Text('全部状态')),
              DropdownMenuItem(
                  value: _CompletionFilter.incomplete, child: Text('未完成')),
              DropdownMenuItem(
                  value: _CompletionFilter.partial, child: Text('部分完成')),
              DropdownMenuItem(
                  value: _CompletionFilter.complete, child: Text('已完成')),
            ],
            onChanged: (value) {
              if (value != null) onCompletionChanged(value);
            },
          ),
          if (onReset != null)
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: const Text('清除筛选'),
            ),
        ],
      );
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.tooltip,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String tooltip;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Container(
          constraints: const BoxConstraints(minWidth: 132),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(7),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              icon: const Icon(Icons.expand_more,
                  size: 16, color: AppTheme.muted),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      );
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedCount,
    required this.allVisibleSelected,
    required this.onToggleAll,
    required this.onClear,
    required this.onAssign,
    required this.onMoveToInbox,
    required this.onDelete,
    required this.onCreate,
  });

  final int selectedCount;
  final bool allVisibleSelected;
  final VoidCallback onToggleAll;
  final VoidCallback? onClear;
  final VoidCallback? onAssign;
  final VoidCallback? onMoveToInbox;
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
            onPressed: onMoveToInbox,
            icon: const Icon(Icons.move_to_inbox_outlined, size: 17),
            label: const Text('移到收集箱'),
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
    required this.gameName,
    required this.completion,
    required this.selected,
    required this.onSelected,
    required this.onEdit,
    required this.onMoveToInbox,
    required this.onDelete,
  });

  final List<TaskRecord> tasks;
  final List<Character> characters;
  final String gameName;
  final _TemplateCompletion completion;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onEdit;
  final VoidCallback onMoveToInbox;
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
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusChip(
                        icon: Icons.sports_esports_outlined,
                        label: gameName,
                      ),
                      _CompletionChip(completion: completion),
                      Text(details.join(' · '),
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.muted)),
                    ],
                  ),
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
                if (value == 'inbox') onMoveToInbox();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑与管理分配')),
                PopupMenuItem(value: 'inbox', child: Text('移到收集箱')),
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

class _CompletionChip extends StatelessWidget {
  const _CompletionChip({required this.completion});
  final _TemplateCompletion completion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (completion) {
      _TemplateCompletion.unassigned =>
        ('未分配', Icons.inbox_outlined, AppTheme.muted),
      _TemplateCompletion.incomplete =>
        ('未完成', Icons.radio_button_unchecked, scheme.onSurfaceVariant),
      _TemplateCompletion.partial =>
        ('部分完成', Icons.timelapse_outlined, scheme.tertiary),
      _TemplateCompletion.complete =>
        ('已完成', Icons.check_circle_outline, scheme.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ]),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          '没有符合搜索或筛选条件的任务',
          style: const TextStyle(color: AppTheme.muted),
        ),
      );
}
