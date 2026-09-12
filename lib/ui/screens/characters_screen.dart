import 'package:flutter/material.dart';

import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../task_editor.dart';
import '../widgets/common.dart';

class CharactersScreen extends StatefulWidget {
  const CharactersScreen({required this.state, super.key});

  final AppState state;

  @override
  State<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends State<CharactersScreen> {
  final Set<String> _selectedIds = {};
  bool _batchMode = false;

  AppState get state => widget.state;

  List<Character> get _visibleCharacters => state.store.characters
      .where((character) => !character.archived)
      .toList();

  void _setBatchMode(bool enabled) {
    setState(() {
      _batchMode = enabled;
      if (!enabled) _selectedIds.clear();
    });
  }

  void _toggleCharacter(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _selectAll() {
    setState(() {
      final visibleIds = _visibleCharacters.map((item) => item.id).toSet();
      if (_selectedIds.containsAll(visibleIds)) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(visibleIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (context, child) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(title: const Text('角色管理')),
          body: Column(
            children: [
              PageHeader(
                title: '角色列表',
                subtitle: '按游戏管理角色，每个角色拥有独立的任务完成记录',
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_batchMode) ...[
                      OutlinedButton.icon(
                        onPressed: () => _setBatchMode(true),
                        icon: const Icon(Icons.checklist, size: 17),
                        label: const Text('批量管理'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => showCharacterEditor(context, state),
                        icon: const Icon(Icons.add, size: 17),
                        label: const Text('添加角色'),
                      ),
                    ] else
                      TextButton(
                        onPressed: () => _setBatchMode(false),
                        child: const Text('退出批量管理'),
                      ),
                  ],
                ),
              ),
              if (_batchMode)
                _BatchToolbar(
                  selectedCount: _selectedIds.length,
                  allSelected: _visibleCharacters.isNotEmpty &&
                      _selectedIds.length == _visibleCharacters.length,
                  onSelectAll: _selectAll,
                  onArchive: _selectedIds.isEmpty ? null : _archiveSelected,
                  onDelete: _selectedIds.isEmpty ? null : _deleteSelected,
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    children: [
                      for (final game in state.games)
                        _GameCharacterSection(
                          state: state,
                          game: game,
                          characters: state.store.characters
                              .where((character) =>
                                  character.gameId == game.id &&
                                  !character.archived)
                              .toList(),
                          batchMode: _batchMode,
                          selectedIds: _selectedIds,
                          onToggle: _toggleCharacter,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _archiveSelected() async {
    final count = _selectedIds.length;
    await state.archiveCharacters(Set.of(_selectedIds));
    if (!mounted) return;
    _setBatchMode(false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已归档 $count 个角色')));
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('永久删除所选角色'),
        content: Text('确定删除所选的 $count 个角色吗？这些角色的任务和完成记录也会一并删除，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffb94a48)),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await state.deleteCharacters(Set.of(_selectedIds));
    if (!mounted) return;
    _setBatchMode(false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已删除 $count 个角色')));
  }
}

class _BatchToolbar extends StatelessWidget {
  const _BatchToolbar({
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onArchive,
    required this.onDelete,
  });

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xfff7f9f9),
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Text('已选择 $selectedCount 个',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onSelectAll,
              child: Text(allSelected ? '取消全选' : '全选'),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onArchive,
              icon: const Icon(Icons.archive_outlined, size: 17),
              label: const Text('归档'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onDelete,
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffb94a48)),
              icon: const Icon(Icons.delete_outline, size: 17),
              label: const Text('删除'),
            ),
          ],
        ),
      );
}

class _GameCharacterSection extends StatelessWidget {
  const _GameCharacterSection({
    required this.state,
    required this.game,
    required this.characters,
    required this.batchMode,
    required this.selectedIds,
    required this.onToggle,
  });

  final AppState state;
  final Game game;
  final List<Character> characters;
  final bool batchMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const gap = 10.0;
          const minimumCardWidth = 180.0;
          final desiredColumns =
              (constraints.maxWidth / (minimumCardWidth + gap)).floor();
          final columns = desiredColumns.clamp(1, 3).toInt();
          final cardWidth =
              (constraints.maxWidth - gap * (columns - 1)) / columns;

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Color(game.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(game.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text('${characters.length} 个角色',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 10),
                if (characters.isEmpty)
                  const Text('还没有角色，可点击右上角添加角色。',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted))
                else
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final character in characters)
                        SizedBox(
                          width: cardWidth,
                          child: _CharacterCard(
                            state: state,
                            game: game,
                            character: character,
                            batchMode: batchMode,
                            selected: selectedIds.contains(character.id),
                            onToggle: () => onToggle(character.id),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          );
        },
      );
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.state,
    required this.game,
    required this.character,
    required this.batchMode,
    required this.selected,
    required this.onToggle,
  });

  final AppState state;
  final Game game;
  final Character character;
  final bool batchMode;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tasks = state.store.tasks
        .where((task) => task.characterId == character.id)
        .toList();
    final week = startOfWeek(DateTime.now());
    final progress =
        state.progressFor(tasks, week, week.add(const Duration(days: 7)));

    return InkWell(
      onTap: batchMode ? onToggle : null,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffeef6f4) : Colors.white,
          border: Border.all(color: selected ? AppTheme.accent : AppTheme.line),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CharacterAvatar(character: character, size: 36),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(character.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        character.account.isEmpty
                            ? '账号未设置'
                            : character.account,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                if (batchMode)
                  Checkbox(value: selected, onChanged: (_) => onToggle())
                else
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await showCharacterEditor(context, state,
                            character: character);
                      } else if (value == 'archive') {
                        await state.archiveCharacter(character);
                      } else if (value == 'delete') {
                        await _confirmDelete(context, state, character);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑角色')),
                      PopupMenuItem(value: 'archive', child: Text('归档角色')),
                      PopupMenuItem(value: 'delete', child: Text('永久删除')),
                    ],
                  ),
              ],
            ),
            if (character.occupation.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text('职业：${character.occupation}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
            ],
            const SizedBox(height: 10),
            ProgressLine(value: progress),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '本周 ${(progress * 100).round()}% · ${tasks.length} 个任务',
                    style: const TextStyle(fontSize: 10, color: AppTheme.muted),
                  ),
                ),
                if (!batchMode)
                  TextButton(
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4)),
                    onPressed: () {
                      state.selectGame(game.id);
                      state.selectCharacter(character.id);
                      Navigator.pop(context);
                      state.setTab(0);
                    },
                    child:
                        const Text('查看待办', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(
    BuildContext context, AppState state, Character character) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('永久删除角色'),
      content: Text('确定删除“${character.name}”吗？该角色的任务和完成记录也会一并删除，此操作无法撤销。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xffb94a48)),
          child: const Text('确认删除'),
        ),
      ],
    ),
  );
  if (confirmed == true) await state.deleteCharacter(character);
}
