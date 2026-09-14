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
  late List<GameMetadataField> fields;

  @override
  void initState() {
    super.initState();
    controller.text = widget.game?.name ?? '';
    final minutes = widget.game?.dailyResetMinutes ?? 0;
    resetTime = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    fields = [...?widget.game?.metadataFields];
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.game == null ? '添加游戏' : '编辑游戏'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '游戏名称',
                    hintText: '例如：剑网3、崩坏：星穹铁道',
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined, size: 20),
                  title: const Text('每日任务截止/刷新时间',
                      style: TextStyle(fontSize: 13)),
                  subtitle: Text('每天 ${_timeLabel(resetTime)} 开始新的一天',
                      style: const TextStyle(fontSize: 11)),
                  trailing: TextButton(
                    onPressed: _pickResetTime,
                    child: Text(_timeLabel(resetTime)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text('角色元数据',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    TextButton.icon(
                      onPressed: _editField,
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text('添加字段'),
                    ),
                  ],
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('例如门派、心法、服务器或等级；角色录入时会按这里的格式填写。',
                      style: TextStyle(fontSize: 11)),
                ),
                for (final field in fields)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(field.name),
                    subtitle: Text((field.type == MetadataFieldType.choice ||
                                field.type == MetadataFieldType.multiChoice)
                        ? '${field.type.label} · ${field.options.join('、')}'
                        : field.type.label),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: '编辑',
                          onPressed: () => _editField(field),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                        IconButton(
                          tooltip: '删除',
                          onPressed: () => _deleteField(field),
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      );

  Future<void> _editField([GameMetadataField? source]) async {
    final name = TextEditingController(text: source?.name ?? '');
    final options =
        TextEditingController(text: source?.options.join('\n') ?? '');
    var type = source?.type ?? MetadataFieldType.text;
    final result = await showDialog<GameMetadataField>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(source == null ? '添加元数据字段' : '编辑元数据字段'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: '字段名称')),
                const SizedBox(height: 12),
                DropdownButtonFormField<MetadataFieldType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: '值的格式'),
                  items: MetadataFieldType.values
                      .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => type = value!),
                ),
                if (type == MetadataFieldType.choice ||
                    type == MetadataFieldType.multiChoice) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: options,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '选项',
                      hintText: '每行一个，例如：\n奶歌\n花间',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final fieldName = name.text.trim();
                final values = options.text
                    .split(RegExp(r'[,，\n]'))
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .toList();
                if (fieldName.isEmpty ||
                    fields.any((item) => item.id != source?.id && item.name == fieldName) ||
                    ((type == MetadataFieldType.choice ||
                            type == MetadataFieldType.multiChoice) &&
                        values.isEmpty)) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  GameMetadataField(
                    id: source?.id ?? 'metadata-${DateTime.now().microsecondsSinceEpoch}',
                    name: fieldName,
                    type: type,
                    options: type == MetadataFieldType.choice ||
                            type == MetadataFieldType.multiChoice
                        ? values
                        : const [],
                  ),
                );
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    options.dispose();
    if (result == null) return;
    setState(() {
      final index = fields.indexWhere((item) => item.id == result.id);
      if (index < 0) {
        fields.add(result);
      } else {
        fields[index] = result;
      }
    });
  }

  Future<void> _deleteField(GameMetadataField field) async {
    final hasValues = widget.state.store.characters.any((character) =>
        character.gameId == widget.game?.id &&
        (character.metadataValues[field.id]?.isNotEmpty ?? false));
    if (hasValues) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除元数据字段'),
          content: Text('已有角色填写了“${field.name}”，删除后这些值也会移除。确定删除吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => fields.removeWhere((item) => item.id == field.id));
  }

  Future<void> _save() async {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final minutes = resetTime.hour * 60 + resetTime.minute;
    if (widget.game == null) {
      await widget.state.addGame(name,
          dailyResetMinutes: minutes, metadataFields: fields);
    } else {
      await widget.state.updateGame(widget.game!, name,
          dailyResetMinutes: minutes, metadataFields: fields);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickResetTime() async {
    final value = await showTimePicker(context: context, initialTime: resetTime);
    if (value != null) setState(() => resetTime = value);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

String _timeLabel(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
