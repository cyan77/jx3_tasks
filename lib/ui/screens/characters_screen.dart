import 'package:flutter/material.dart';

import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../task_editor.dart';
import '../widgets/common.dart';

class CharactersScreen extends StatelessWidget {
  const CharactersScreen({required this.state, super.key});

  final AppState state;

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
                action: FilledButton.icon(
                  onPressed: () => showCharacterEditor(context, state),
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('添加角色'),
                ),
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
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _GameCharacterSection extends StatelessWidget {
  const _GameCharacterSection({
    required this.state,
    required this.game,
    required this.characters,
  });

  final AppState state;
  final Game game;
  final List<Character> characters;

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
  });

  final AppState state;
  final Game game;
  final Character character;

  @override
  Widget build(BuildContext context) {
    final tasks = state.store.tasks
        .where((task) => task.characterId == character.id)
        .toList();
    final week = startOfWeek(DateTime.now());
    final progress =
        state.progressFor(tasks, week, week.add(const Duration(days: 7)));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line),
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
                      character.account.isEmpty ? '账号未设置' : character.account,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
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
              TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4)),
                onPressed: () {
                  state.selectGame(game.id);
                  state.selectCharacter(character.id);
                  Navigator.pop(context);
                  state.setTab(0);
                },
                child: const Text('查看待办', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
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
