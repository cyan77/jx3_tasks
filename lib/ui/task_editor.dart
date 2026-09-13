import 'package:flutter/material.dart';

import '../models/task_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'widgets/common.dart';

Future<void> showTaskEditor(
  BuildContext context,
  AppState state, {
  TaskRecord? task,
  bool syncAll = false,
  bool createInInbox = false,
}) async {
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _TaskEditor(
          state: state,
          task: task,
          syncAll: syncAll,
          createInInbox: createInInbox));
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
  const _TaskEditor({
    required this.state,
    this.task,
    this.syncAll = false,
    this.createInInbox = false,
  });
  final AppState state;
  final TaskRecord? task;
  final bool syncAll;
  final bool createInInbox;
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
  late final List<_SubtaskDraft> subtaskDrafts;
  int subtaskSequence = 0;
  bool assignExisting = false;
  String? existingTemplateId;
  String? validationMessage;

  bool get isEditing => widget.task != null;
  bool get isInboxEditing => widget.task?.isInbox ?? false;
  String get editorTitle {
    if (widget.createInInbox) return '记录到收集箱';
    if (isInboxEditing) return '整理收集箱任务';
    if (isEditing) {
      return widget.syncAll ? '编辑所有角色的任务' : '仅编辑当前角色任务';
    }
    return assignExisting ? '分配已有任务' : '新建任务';
  }

  String get saveLabel {
    if (widget.createInInbox) return '放入收集箱';
    if (isInboxEditing && selected.isNotEmpty) return '分配并移出收集箱';
    if (isEditing) return '保存修改';
    return assignExisting ? '分配任务' : '创建任务';
  }

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
    subtaskDrafts = [
      for (final subtask in task?.subtasks ?? const <TaskSubtask>[])
        _SubtaskDraft(
          id: subtask.id,
          controller: TextEditingController(text: subtask.title),
        ),
    ];
    selected = task == null
        ? {
            if (!widget.createInInbox &&
                widget.state.selectedCharacterId != null)
              widget.state.selectedCharacterId!
          }
        : task.isInbox
            ? <String>{}
            : !widget.syncAll
            ? {task.characterId}
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
                      child: Text(editorTitle,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20))
                ]),
                const SizedBox(height: 14),
                if (!isEditing && !widget.createInInbox)
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
                      autofocus: !isEditing,
                      decoration: const InputDecoration(
                          labelText: '任务名称',
                          hintText: '例如：大战、茶馆、门派周常')),
                if (validationMessage != null) ...[
                  const SizedBox(height: 9),
                  Text(validationMessage!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xffb94a48))),
                ],
                if (!widget.createInInbox &&
                    (!isEditing || widget.syncAll || isInboxEditing)) ...[
                  const SizedBox(height: 18),
                  const Text('关联角色',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (availableCharacters.isNotEmpty)
                    Wrap(spacing: 4, runSpacing: 0, children: [
                      _characterAction(
                          label: '全选', onPressed: _selectAllCharacters),
                      _characterAction(
                          label: '全不选', onPressed: _clearCharacters),
                      _characterAction(
                          label: '反选', onPressed: _invertCharacters),
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
                ] else if (isEditing && !isInboxEditing) ...[
                  const SizedBox(height: 12),
                  const Text('本次修改不会影响其他角色',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                ],
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
                  if (!widget.createInInbox &&
                      (!isInboxEditing || selected.isNotEmpty)) ...[
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
                    ],
                    if (frequency == TaskFrequency.weekly ||
                        frequency == TaskFrequency.weeklyCount) ...[
                      const SizedBox(height: 10),
                      Text(
                          frequency == TaskFrequency.weekly
                              ? '每周在哪几天显示（不选则按创建当天）'
                              : '计划完成日期（不选则本周任意几天完成）',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.muted)),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
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
                  ] else if (isInboxEditing) ...[
                    const SizedBox(height: 12),
                    const Text(
                        '选择至少一个当前游戏角色后，即可设置周期和截止日期；不选择则继续留在收集箱。',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.muted)),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('子任务',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      TextButton.icon(
                        onPressed: _addSubtask,
                        icon: const Icon(Icons.add, size: 17),
                        label: const Text('添加子任务'),
                      ),
                    ],
                  ),
                  ...subtaskDrafts.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: entry.value.controller,
                                decoration: InputDecoration(
                                  labelText: '子任务 ${entry.key + 1}',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '删除子任务',
                              onPressed: () => _removeSubtask(entry.key),
                              icon: const Icon(Icons.delete_outline, size: 19),
                            ),
                          ],
                        ),
                      )),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '备注（可选）')),
                ],
                const SizedBox(height: 18),
                if (isEditing) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _deleteTask,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xffb94a48),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(widget.syncAll
                              ? '删除所有角色任务'
                              : '删除任务'),
                        ),
                      ),
                      if (!isInboxEditing) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _moveToInbox,
                            icon: const Icon(Icons.move_to_inbox_outlined,
                                size: 18),
                            label: Text(widget.syncAll
                                ? '全部移到收集箱'
                                : '移到收集箱'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: assignExisting && existingTask == null
                            ? null
                            : _save,
                        child: Text(saveLabel)))
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
    if (assignExisting) {
      final task = existingTask;
      if (task == null) {
        _showValidation('请选择一个已有任务');
        return;
      }
      if (selected.isEmpty) {
        _showValidation('请至少选择一个尚未分配的角色');
        return;
      }
      await widget.state.assignExistingTask(
          source: task, characterIds: Set.of(selected));
      if (mounted) Navigator.pop(context);
      return;
    }

    final title = titleController.text.trim();
    if (title.isEmpty) {
      _showValidation('请填写任务名称');
      return;
    }
    if (widget.createInInbox) {
      await widget.state.addInboxTask(
        title: title,
        subtasks: _subtasks(),
        note: noteController.text.trim(),
      );
    } else if (isInboxEditing) {
      if (selected.isEmpty) {
        await widget.state.updateInboxTask(
          source: widget.task!,
          title: title,
          subtasks: _subtasks(),
          note: noteController.text.trim(),
        );
      } else {
        await widget.state.assignInboxTask(
          source: widget.task!,
          title: title,
          characterIds: Set.of(selected),
          frequency: frequency,
          dueDate: dueDate,
          targetCount: targetCount,
          weeklyDays: weeklyDays.toList()..sort(),
          subtasks: _subtasks(),
          note: noteController.text.trim(),
        );
      }
    } else if (isEditing) {
      if (selected.isEmpty) {
        _showValidation('请至少选择一个角色');
        return;
      }
      if (widget.syncAll) {
        await widget.state.updateTaskTemplate(
          source: widget.task!,
          title: title,
          characterIds: Set.of(selected),
          frequency: frequency,
          dueDate: dueDate,
          targetCount: targetCount,
          weeklyDays: weeklyDays.toList()..sort(),
          subtasks: _subtasks(),
          note: noteController.text.trim(),
        );
      } else {
        await widget.state.updateTaskRecord(
          source: widget.task!,
          title: title,
          frequency: frequency,
          dueDate: dueDate,
          targetCount: targetCount,
          weeklyDays: weeklyDays.toList()..sort(),
          subtasks: _subtasks(),
          note: noteController.text.trim(),
        );
      }
    } else {
      if (selected.isEmpty) {
        _showValidation('请至少选择一个角色');
        return;
      }
      await widget.state.addTask(
        title: title,
        characterIds: selected.toList(),
        frequency: frequency,
        dueDate: dueDate,
        targetCount: targetCount,
        weeklyDays: weeklyDays.toList()..sort(),
        subtasks: _subtasks(),
        note: noteController.text.trim());
    }
    if (mounted) Navigator.pop(context);
  }

  void _showValidation(String message) {
    if (!mounted) return;
    setState(() => validationMessage = message);
  }

  Future<void> _deleteTask() async {
    final task = widget.task;
    if (task == null) return;
    final allLinked = widget.syncAll && !task.isInbox;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除任务？'),
        content: Text(allLinked
            ? '将删除所有已分配角色的“${task.title}”，完成记录也会一并删除。'
            : '将删除“${task.title}”，完成记录也会一并删除。'),
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
    await widget.state.deleteTask(task, allLinked: allLinked);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _moveToInbox() async {
    final task = widget.task;
    if (task == null || task.isInbox) return;
    final allLinked = widget.syncAll;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移到收集箱？'),
        content: Text(allLinked
            ? '所有已分配角色的“${task.title}”将合并为一条收集箱任务，原有计划和完成记录会清除。'
            : '“${task.title}”将取消当前角色的分配并进入收集箱，原有计划和完成记录会清除。'),
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
    await widget.state.moveTaskToInbox(task, allLinked: allLinked);
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

  void _addSubtask() {
    setState(() {
      subtaskDrafts.add(_SubtaskDraft(
        id: 'subtask-${DateTime.now().microsecondsSinceEpoch}-${subtaskSequence++}',
        controller: TextEditingController(),
      ));
    });
  }

  void _removeSubtask(int index) {
    setState(() {
      subtaskDrafts.removeAt(index).controller.dispose();
    });
  }

  List<TaskSubtask> _subtasks() => subtaskDrafts
      .where((draft) => draft.controller.text.trim().isNotEmpty)
      .map((draft) =>
          TaskSubtask(id: draft.id, title: draft.controller.text.trim()))
      .toList();

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
    for (final draft in subtaskDrafts) {
      draft.controller.dispose();
    }
    super.dispose();
  }
}

class _SubtaskDraft {
  const _SubtaskDraft({required this.id, required this.controller});
  final String id;
  final TextEditingController controller;
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
