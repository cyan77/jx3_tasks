import 'package:flutter/material.dart';

import '../models/task_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'widgets/common.dart';

Future<void> showTaskEditor(
  BuildContext context,
  AppState state, {
  TaskRecord? task,
}) async {
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _TaskEditor(state: state, task: task));
}

Future<void> showCharacterEditor(
  BuildContext context,
  AppState state, {
  Character? character,
}) async {
  await showDialog<void>(
      context: context,
      builder: (_) => _CharacterEditor(state: state, character: character));
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({required this.state, this.task});
  final AppState state;
  final TaskRecord? task;
  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController titleController;
  late final TextEditingController noteController;
  late final Set<String> selected;
  late TaskFrequency frequency;
  DateTime? dueDate;
  late int targetCount;
  late final Set<int> weeklyDays;
  bool assignExisting = false;
  String? existingTemplateId;

  bool get isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    titleController = TextEditingController(text: task?.title ?? '');
    noteController = TextEditingController(text: task?.note ?? '');
    frequency = task?.frequency ?? TaskFrequency.daily;
    dueDate = task?.dueDate;
    targetCount = task?.targetCount ?? 5;
    weeklyDays = {...?task?.weeklyDays};
    selected = task == null
        ? {
            if (widget.state.selectedCharacterId != null)
              widget.state.selectedCharacterId!
          }
        : widget.state
            .tasksForTemplate(task.templateId)
            .map((item) => item.characterId)
            .toSet();
  }

  List<TaskRecord> get existingTasks {
    final byTemplate = <String, TaskRecord>{};
    for (final task in widget.state.tasks) {
      byTemplate.putIfAbsent(task.templateId, () => task);
    }
    return byTemplate.values.where((task) {
      final assignedIds = widget.state
          .tasksForTemplate(task.templateId)
          .map((item) => item.characterId)
          .toSet();
      return widget.state.characters
          .any((character) => !assignedIds.contains(character.id));
    }).toList();
  }

  TaskRecord? get existingTask => existingTasks
      .where((task) => task.templateId == existingTemplateId)
      .firstOrNull;

  List<Character> get availableCharacters {
    final task = existingTask;
    if (!assignExisting) return widget.state.characters;
    if (task == null) return const [];
    final assignedIds = widget.state
        .tasksForTemplate(task.templateId)
        .map((item) => item.characterId)
        .toSet();
    return widget.state.characters
        .where((character) => !assignedIds.contains(character.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Padding(
          padding: EdgeInsets.only(
              left: 22,
              right: 22,
              top: 18,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 18),
          child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(isEditing
                          ? '编辑任务'
                          : assignExisting
                              ? '分配已有任务'
                              : '新建任务',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20))
                ]),
                const SizedBox(height: 14),
                if (!isEditing)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: false,
                          icon: Icon(Icons.add, size: 17),
                          label: Text('新建任务')),
                      ButtonSegment(
                          value: true,
                          icon: Icon(Icons.content_copy_outlined, size: 17),
                          label: Text('分配已有任务')),
                    ],
                    selected: {assignExisting},
                    onSelectionChanged: (value) =>
                        _setAssignExisting(value.first),
                  ),
                const SizedBox(height: 14),
                if (assignExisting) ...[
                  if (existingTasks.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.soft,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text('没有可以继续分配的任务',
                          style:
                              TextStyle(fontSize: 12, color: AppTheme.muted)),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: existingTemplateId,
                      decoration: const InputDecoration(labelText: '选择已有任务'),
                      items: existingTasks
                          .map((task) => DropdownMenuItem(
                                value: task.templateId,
                                child: Text(
                                    '${task.title} · ${task.frequency.label}'),
                              ))
                          .toList(),
                      onChanged: _selectExistingTask,
                    ),
                ] else
                  TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                          labelText: '任务名称',
                          hintText: '例如：大战、茶馆、门派周常')),
                const SizedBox(height: 18),
                const Text('关联角色',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (availableCharacters.isNotEmpty)
                  Wrap(spacing: 4, runSpacing: 0, children: [
                    _characterAction(
                        label: '全选', onPressed: _selectAllCharacters),
                    _characterAction(label: '全不选', onPressed: _clearCharacters),
                    _characterAction(label: '反选', onPressed: _invertCharacters),
                  ]),
                if (availableCharacters.isNotEmpty)
                  const SizedBox(height: 4),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableCharacters
                        .map((character) => FilterChip(
                            label: Text(character.name),
                            selected: selected.contains(character.id),
                            onSelected: (value) => setState(() {
                                  value
                                      ? selected.add(character.id)
                                      : selected.remove(character.id);
                                })))
                        .toList()),
                if (assignExisting && existingTask != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    '将沿用：${existingTask!.frequency.label}'
                    '${existingTask!.dueDate == null ? '' : ' · ${dueLabel(existingTask!.dueDate)}'}'
                    '${existingTask!.isCountTask ? ' · 目标 ${existingTask!.targetCount} 次' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
                if (!assignExisting) ...[
                  const SizedBox(height: 18),
                  DropdownButtonFormField<TaskFrequency>(
                    value: frequency,
                    decoration: const InputDecoration(labelText: '周期'),
                    items: TaskFrequency.values
                        .map((item) => DropdownMenuItem(
                            value: item, child: Text(item.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => frequency = value);
                    }),
                  if (frequency == TaskFrequency.weeklyCount ||
                      frequency == TaskFrequency.monthlyCount) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Text('目标次数', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 16),
                      IconButton(
                          onPressed: targetCount > 1
                              ? () => setState(() => targetCount--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 19)),
                      Text('$targetCount',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(
                          onPressed: () => setState(() => targetCount++),
                          icon:
                              const Icon(Icons.add_circle_outline, size: 19))
                    ]),
                    if (frequency == TaskFrequency.weeklyCount) ...[
                      const SizedBox(height: 10),
                      const Text('可选日期（不选则本周任意几天完成）',
                          style:
                              TextStyle(fontSize: 12, color: AppTheme.muted)),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        children: List.generate(7, (index) {
                          final day = index + 1;
                          const labels = ['一', '二', '三', '四', '五', '六', '日'];
                          return FilterChip(
                            label: Text('周${labels[index]}'),
                            selected: weeklyDays.contains(day),
                            onSelected: (value) => setState(() {
                              value
                                  ? weeklyDays.add(day)
                                  : weeklyDays.remove(day);
                            }),
                          );
                        }),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.event_outlined,
                        size: 19, color: AppTheme.muted),
                    title:
                        const Text('截止日期', style: TextStyle(fontSize: 13)),
                    subtitle: Text(
                        dueDate == null ? '不设置' : dueLabel(dueDate),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.muted)),
                    trailing: TextButton(
                        onPressed: _pickDate,
                        child: Text(dueDate == null ? '选择' : '修改')),
                  ),
                  if (dueDate != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => dueDate = null),
                        child: const Text('清除截止日期'),
                      ),
                    ),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '备注（可选）')),
                ],
                const SizedBox(height: 18),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: assignExisting && existingTask == null
                            ? null
                            : _save,
                        child: Text(isEditing
                            ? '保存修改'
                            : assignExisting
                                ? '分配任务'
                                : '创建任务')))
              ]))));

  Widget _characterAction({
    required String label,
    required VoidCallback onPressed,
  }) =>
      TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text(label, style: const TextStyle(fontSize: 12)));

  void _selectAllCharacters() {
    setState(() {
      selected
        ..clear()
        ..addAll(availableCharacters.map((character) => character.id));
    });
  }

  void _clearCharacters() => setState(selected.clear);

  void _invertCharacters() {
    setState(() {
      final characterIds =
          availableCharacters.map((character) => character.id).toSet();
      final inverted = characterIds.difference(selected);
      selected
        ..clear()
        ..addAll(inverted);
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDate: dueDate ?? DateTime.now());
    if (date != null) setState(() => dueDate = date);
  }

  Future<void> _save() async {
    if (selected.isEmpty) return;
    if (isEditing) {
      if (titleController.text.trim().isEmpty) return;
      await widget.state.updateTaskTemplate(
        source: widget.task!,
        title: titleController.text.trim(),
        characterIds: Set.of(selected),
        frequency: frequency,
        dueDate: dueDate,
        targetCount: targetCount,
        weeklyDays: weeklyDays.toList()..sort(),
        note: noteController.text.trim(),
      );
    } else if (assignExisting) {
      final task = existingTask;
      if (task == null) return;
      await widget.state.assignExistingTask(
          source: task, characterIds: Set.of(selected));
    } else {
      if (titleController.text.trim().isEmpty) return;
      await widget.state.addTask(
        title: titleController.text.trim(),
        characterIds: selected.toList(),
        frequency: frequency,
        dueDate: dueDate,
        targetCount: targetCount,
        weeklyDays: weeklyDays.toList()..sort(),
        note: noteController.text.trim());
    }
    if (mounted) Navigator.pop(context);
  }

  void _setAssignExisting(bool value) {
    setState(() {
      assignExisting = value;
      existingTemplateId = null;
      selected.clear();
      final selectedCharacterId = widget.state.selectedCharacterId;
      if (!value && selectedCharacterId != null) {
        selected.add(selectedCharacterId);
      }
    });
  }

  void _selectExistingTask(String? templateId) {
    setState(() {
      existingTemplateId = templateId;
      selected.clear();
      final selectedCharacterId = widget.state.selectedCharacterId;
      if (selectedCharacterId != null &&
          availableCharacters
              .any((character) => character.id == selectedCharacterId)) {
        selected.add(selectedCharacterId);
      }
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
    super.dispose();
  }
}

class _CharacterEditor extends StatefulWidget {
  const _CharacterEditor({required this.state, this.character});
  final AppState state;
  final Character? character;
  @override
  State<_CharacterEditor> createState() => _CharacterEditorState();
}

class _CharacterEditorState extends State<_CharacterEditor> {
  final nameController = TextEditingController();
  final accountController = TextEditingController();
  final occupationController = TextEditingController();
  String? selectedGameId;
  String? validationMessage;

  @override
  void initState() {
    super.initState();
    nameController.text = widget.character?.name ?? '';
    accountController.text = widget.character?.account ?? '';
    occupationController.text = widget.character?.occupation ?? '';
    selectedGameId = widget.character?.gameId ??
        widget.state.selectedGameId ??
        widget.state.games.firstOrNull?.id;
  }

  bool get needsOccupation {
    final game = widget.state.games
        .where((item) => item.id == selectedGameId)
        .firstOrNull;
    return game?.id == 'game-jx3' || game?.name == '剑网3';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.character == null ? '添加角色' : '编辑角色',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: '角色名称', hintText: '例如：奶歌')),
            const SizedBox(height: 12),
            TextField(
                controller: accountController,
                decoration: const InputDecoration(
                    labelText: '账号', hintText: '例如：主账号 / 小号账号')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                initialValue: selectedGameId,
                decoration: const InputDecoration(labelText: '所属游戏'),
                items: widget.state.games
                    .map((game) => DropdownMenuItem(
                          value: game.id,
                          child: Text(game.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedGameId = value;
                    if (!needsOccupation) occupationController.clear();
                  });
                }),
            if (needsOccupation) ...[
              const SizedBox(height: 12),
              TextField(
                  controller: occupationController,
                  decoration: const InputDecoration(
                      labelText: '职业 / 心法', hintText: '例如：奶歌')),
            ],
            if (validationMessage != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(validationMessage!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xffb94a48))),
              ),
            ],
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(onPressed: _save, child: const Text('保存'))
          ]);

  Future<void> _save() async {
    final name = nameController.text.trim();
    final account = accountController.text.trim();
    if (name.isEmpty || account.isEmpty || selectedGameId == null) {
      setState(() => validationMessage = '请填写角色名称、账号并选择所属游戏');
      return;
    }
    final occupation =
        needsOccupation && occupationController.text.trim().isNotEmpty
            ? occupationController.text.trim()
            : '';
    if (widget.character == null) {
      await widget.state.addCharacter(
          name: name,
          account: account,
          occupation: occupation,
          gameId: selectedGameId!);
    } else {
      await widget.state.updateCharacter(
          character: widget.character!,
          gameId: selectedGameId!,
          account: account,
          name: name,
          occupation: occupation);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    nameController.dispose();
    accountController.dispose();
    occupationController.dispose();
    super.dispose();
  }
}
