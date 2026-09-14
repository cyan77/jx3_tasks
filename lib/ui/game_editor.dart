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
  late TimeOfDay resetTime;

  @override
  void initState() {
    super.initState();
    controller.text = widget.game?.name ?? '';
    final minutes = widget.game?.dailyResetMinutes ?? 0;
    resetTime = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.game == null ? '添加游戏' : '编辑游戏'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '游戏名称',
                hintText: '例如：剑网3、魔兽世界、FF14',
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined, size: 20),
              title: const Text('每日任务截止/刷新时间',
                  style: TextStyle(fontSize: 13)),
              subtitle: Text(
                '每天 ${_timeLabel(resetTime)} 开始新的一天',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: TextButton(
                onPressed: _pickResetTime,
                child: Text(_timeLabel(resetTime)),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '例如设为 07:00，则 07:00 至次日 06:59 计为同一天。',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
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
    final dailyResetMinutes = resetTime.hour * 60 + resetTime.minute;
    if (widget.game == null) {
      await widget.state.addGame(
        name,
        dailyResetMinutes: dailyResetMinutes,
      );
    } else {
      await widget.state.updateGame(
        widget.game!,
        name,
        dailyResetMinutes: dailyResetMinutes,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickResetTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: resetTime,
    );
    if (value != null) setState(() => resetTime = value);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

String _timeLabel(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
