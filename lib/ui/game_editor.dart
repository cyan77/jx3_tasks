import 'package:flutter/material.dart';

import '../models/task_models.dart';
import '../state/app_state.dart';

Future<void> showGameEditor(
  BuildContext context,
  AppState state, {
  Game? game,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _GameEditor(state: state, game: game),
  );
}

class _GameEditor extends StatefulWidget {
  const _GameEditor({required this.state, this.game});

  final AppState state;
  final Game? game;

  @override
  State<_GameEditor> createState() => _GameEditorState();
}

class _GameEditorState extends State<_GameEditor> {
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.text = widget.game?.name ?? '';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.game == null ? '添加游戏' : '编辑游戏'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '游戏名称',
            hintText: '例如：剑网3、魔兽世界、FF14',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      );

  Future<void> _save() async {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    if (widget.game == null) {
      await widget.state.addGame(name);
    } else {
      await widget.state.updateGame(widget.game!, name);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
