import 'package:flutter/material.dart';

import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../game_editor.dart';
import '../widgets/common.dart';

class GameManagementScreen extends StatelessWidget {
  const GameManagementScreen({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (context, child) => Scaffold(
          appBar: AppBar(title: const Text('游戏管理')),
          body: Column(
            children: [
              PageHeader(
                title: '游戏列表',
                subtitle: '不同游戏的任务和角色相互独立',
                action: FilledButton.icon(
                  onPressed: () => showGameEditor(context, state),
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('添加游戏'),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: state.games.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final game = state.games[index];
                    final selected = state.selectedGameId == game.id;
                    final characterCount = state.store.characters
                        .where((character) => character.gameId == game.id)
                        .length;
                    return Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color:
                                selected ? Color(game.color) : AppTheme.line),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Color(game.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(game.name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  '$characterCount 个角色${selected ? ' · 当前游戏' : ''}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.muted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '切换到此游戏',
                            onPressed: () {
                              state.selectGame(game.id);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.login, size: 18),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await showGameEditor(context, state,
                                    game: game);
                              } else if (value == 'delete') {
                                await _confirmDelete(context, state, game);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('编辑游戏')),
                              if (state.games.length > 1)
                                const PopupMenuItem(
                                    value: 'delete', child: Text('删除游戏')),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}

Future<void> _confirmDelete(
    BuildContext context, AppState state, Game game) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除游戏？'),
      content: Text('删除“${game.name}”后，该游戏下的角色、任务和完成记录都会被删除。'),
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
  if (confirmed == true) await state.deleteGame(game);
}
