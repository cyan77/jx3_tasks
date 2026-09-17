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
  bool preselectCurrentCharacter = true,
}) async {
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _TaskEditor(
          state: state,
          task: task,
          syncAll: syncAll,
          createInInbox: createInInbox,
          preselectCurrentCharacter: preselectCurrentCharacter));
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
    this.preselectCurrentCharacter = true,
  });
  final AppState state;
  final TaskRecord? task;
  final bool syncAll;
  final bool createInInbox;
  final bool preselectCurrentCharacter;
  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController titleController;
  late final TextEditingController noteController;
  late final Set<String> selected;
  late TaskFrequency frequency;
  late bool frequencyConfigured;
  DateTime? startDate;
  DateTime? dueDate;
  late int targetCount;
  late final Set<int> weeklyDays;
  late final List<_SubtaskDraft> subtaskDrafts;
  int subtaskSequence = 0;
  bool assignExisting = false;
  String? existingTemplateId;
  String? selectedEditorGameId;
  String? validationMessage;
  bool saving = false;

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
    if (!assignExisting && selected.isEmpty) return '放入收集箱';
    return assignExisting ? '分配任务' : '创建任务';
  }

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    selectedEditorGameId = task == null
        ? widget.state.selectedGameId ?? widget.state.games.firstOrNull?.id
        : task.isInbox
            ? task.inboxGameId
            : widget.state.store.characters
                .where((character) => character.id == task.characterId)
                .firstOrNull
                ?.gameId;
    titleController = TextEditingController(text: task?.title ?? '');
    noteController = TextEditingController(text: task?.note ?? '');
    frequency = task?.frequency ?? TaskFrequency.daily;
    frequencyConfigured = task == null
        ? !widget.createInInbox
        : task.hasConfiguredFrequency;
    startDate = task?.startDate;
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
                widget.preselectCurrentCharacter &&
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
    for (final task in widget.state.store.tasks.where((task) =>
        !task.archived &&
        !task.isInbox &&
        widget.state.gameForTask(task)?.id == editorGameId)) {
      byTemplate.putIfAbsent(task.templateId, () => task);
    }
    return byTemplate.values.where((task) {
      final assignedIds = widget.state
          .tasksForTemplate(task.templateId)
          .map((item) => item.characterId)
          .toSet();
      return editorCharacters
          .any((character) => !assignedIds.contains(character.id));
    }).toList();
  }

  TaskRecord? get existingTask => existingTasks
      .where((task) => task.templateId == existingTemplateId)
      .firstOrNull;

  String? get editorGameId {
    return selectedEditorGameId;
  }

  List<Character> get editorCharacters => widget.state.store.characters
      .where((character) =>
          !character.archived && character.gameId == editorGameId)
      .toList();

  List<Character> get availableCharacters {
    final task = existingTask;
    if (!assignExisting) return editorCharacters;
    if (task == null) return const [];
    final assignedIds = widget.state
        .tasksForTemplate(task.templateId)
        .map((item) => item.characterId)
        .toSet();
    return editorCharacters
        .where((character) => !assignedIds.contains(character.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height -
                MediaQuery.paddingOf(context).top -
                12,
          ),
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
                if (!isEditing &&
                    (widget.createInInbox ||
                        !widget.preselectCurrentCharacter)) ...[
                  _editorDropdown<String>(
                    value: selectedEditorGameId,
                    label: '所属游戏',
                    items: widget.state.games
                        .map((game) => DropdownMenuItem(
                              value: game.id,
                              child: Text(game.name),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() {
                      selectedEditorGameId = value;
                      selected.clear();
                      existingTemplateId = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                ],
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
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text('没有可以继续分配的任务',
                          style:
                              TextStyle(fontSize: 12, color: AppTheme.muted)),
                    )
                  else
                    _editorDropdown<String>(
                      value: existingTemplateId,
                      label: '选择已有任务',
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
                  if (widget.createInInbox || isInboxEditing) ...[
                    const SizedBox(height: 18),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('设置周期',
                          style: TextStyle(fontSize: 13)),
                      subtitle: const Text('可选；不设置也可以留在收集箱',
                          style:
                              TextStyle(fontSize: 11, color: AppTheme.muted)),
                      value: frequencyConfigured,
                      onChanged: (value) =>
                          setState(() => frequencyConfigured = value),
                    ),
                  ],
                  if ((!widget.createInInbox && !isInboxEditing) ||
                      frequencyConfigured) ...[
                    if (!widget.createInInbox && !isInboxEditing)
                      const SizedBox(height: 18),
                    _editorDropdown<TaskFrequency>(
                      value: frequency,
                      label: '周期',
                      items: TaskFrequency.values
                          .map((item) => DropdownMenuItem(
                              value: item, child: Text(item.label)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => frequency = value);
                      },
                    ),
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(
                            onPressed: () => setState(() => targetCount++),
                            icon: const Icon(Icons.add_circle_outline,
                                size: 19))
                      ]),
                    ],
                    if (frequency == TaskFrequency.weekly ||
                        frequency == TaskFrequency.weeklyCount) ...[
                      const SizedBox(height: 10),
                      Text(
                          frequency == TaskFrequency.weekly
                              ? '每周在哪几天显示（不选则按开始当天）'
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
                  ],
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.play_circle_outline,
                        size: 19, color: AppTheme.muted),
                    title: const Text('开始日期',
                        style: TextStyle(fontSize: 13)),
                    subtitle: Text(
                        startDate == null
                            ? '不设置；分配角色当天开始'
                            : dueLabel(startDate),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.muted)),
                    trailing: TextButton(
                        onPressed: _pickStartDate,
                        child: Text(startDate == null ? '选择' : '修改')),
                  ),
                  if (startDate != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => startDate = null),
                        child: const Text('按分配日期开始'),
                      ),
                    ),
                  const SizedBox(height: 4),
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
                  if (isInboxEditing && selected.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                        frequencyConfigured
                            ? '保存后会分配给所选角色，并移出收集箱。'
                            : '分配给角色前需要先设置周期。',
                        style:
                            const TextStyle(fontSize: 12, color: AppTheme.muted)),
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
                        onPressed: saving ? null : _submit,
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(saveLabel)))
              ])))));

  Widget _editorDropdown<T>({
    required T? value,
    required String label,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final menuColor =
        Color.lerp(scheme.surface, scheme.primaryContainer, 0.30)!;
    return LayoutBuilder(
      builder: (context, constraints) => InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            menuWidth: constraints.maxWidth,
            elevation: 0,
            dropdownColor: menuColor,
            borderRadius: BorderRadius.circular(12),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: scheme.onSurface,
            ),
            icon: const Icon(Icons.expand_more, size: 18),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

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
    final now = DateTime.now();
    final editorGame = widget.state.games
        .where((game) => game.id == editorGameId)
        .firstOrNull;
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDate: dueDate ?? editorGame?.taskDayAt(now) ?? now);
    if (date != null) setState(() => dueDate = date);
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final editorGame = widget.state.games
        .where((game) => game.id == editorGameId)
        .firstOrNull;
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDate: startDate ?? editorGame?.taskDayAt(now) ?? now);
    if (date != null) setState(() => startDate = date);
  }

  Future<void> _submit() async {
    if (saving) return;
    setState(() {
      saving = true;
      validationMessage = null;
    });
    try {
      await _save();
    } catch (error) {
      if (mounted) {
        setState(() {
          validationMessage = '保存失败，请重试：$error';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
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
    if (startDate != null &&
        dueDate != null &&
        startOfDay(dueDate!).isBefore(startOfDay(startDate!))) {
      _showValidation('截止日期不能早于开始日期');
      return;
    }
    if (widget.createInInbox) {
      await widget.state.addInboxTask(
        title: title,
        gameId: editorGameId,
        frequency: frequencyConfigured ? frequency : null,
        startDate: startDate,
        dueDate: dueDate,
        targetCount: targetCount,
        weeklyDays: weeklyDays.toList()..sort(),
        subtasks: _subtasks(),
        note: noteController.text.trim(),
      );
    } else if (isInboxEditing) {
      if (selected.isEmpty) {
        await widget.state.updateInboxTask(
          source: widget.task!,
          title: title,
          frequency: frequencyConfigured ? frequency : null,
          startDate: startDate,
          dueDate: dueDate,
          targetCount: targetCount,
          weeklyDays: weeklyDays.toList()..sort(),
          subtasks: _subtasks(),
          note: noteController.text.trim(),
        );
      } else {
        if (!frequencyConfigured) {
          _showValidation('分配给角色前请先设置周期');
          return;
        }
        await widget.state.assignInboxTask(
          source: widget.task!,
          title: title,
          characterIds: Set.of(selected),
          frequency: frequency,
          startDate: startDate,
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
          startDate: startDate,
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
          startDate: startDate,
          dueDate: dueDate,
          targetCount: targetCount,
          weeklyDays: weeklyDays.toList()..sort(),
          subtasks: _subtasks(),
          note: noteController.text.trim(),
        );
      }
    } else {
      if (selected.isEmpty) {
        await widget.state.addInboxTask(
          title: title,
          gameId: editorGameId,
          frequency: frequency,
          startDate: startDate,
          dueDate: dueDate,
          targetCount: targetCount,
          weeklyDays: weeklyDays.toList()..sort(),
          subtasks: _subtasks(),
          note: noteController.text.trim(),
        );
      } else {
        await widget.state.addTask(
          title: title,
          characterIds: selected.toList(),
          frequency: frequency,
          startDate: startDate,
          dueDate: dueDate,
          targetCount: targetCount,
          weeklyDays: weeklyDays.toList()..sort(),
          subtasks: _subtasks(),
          note: noteController.text.trim());
      }
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
            ? '所有已分配角色的“${task.title}”将合并为一条收集箱任务，保留周期和截止日期，完成记录会清除。'
            : '“${task.title}”将取消当前角色的分配并进入收集箱，保留周期和截止日期，完成记录会清除。'),
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
      if (!value &&
          selectedCharacterId != null &&
          editorCharacters
              .any((character) => character.id == selectedCharacterId)) {
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
  final controllers = <String, TextEditingController>{};
  final choiceValues = <String, String?>{};
  final multiValues = <String, Set<String>>{};
  final booleanValues = <String, bool>{};
  String? selectedGameId;
  String? validationMessage;

  Game? get selectedGame => widget.state.games
      .where((item) => item.id == selectedGameId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    nameController.text = widget.character?.name ?? '';
    accountController.text = widget.character?.account ?? '';
    selectedGameId = widget.character?.gameId ??
        widget.state.selectedGameId ??
        widget.state.games.firstOrNull?.id;
    _prepareFields();
  }

  void _prepareFields() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    controllers.clear();
    choiceValues.clear();
    multiValues.clear();
    booleanValues.clear();
    final values = selectedGameId == widget.character?.gameId
        ? widget.character?.metadataValues ?? const <String, String>{}
        : const <String, String>{};
    for (final field in selectedGame?.metadataFields ??
        const <GameMetadataField>[]) {
      final value = values[field.id] ?? '';
      switch (field.type) {
        case MetadataFieldType.choice:
          choiceValues[field.id] =
              field.options.contains(value) ? value : null;
          break;
        case MetadataFieldType.multiChoice:
          multiValues[field.id] = value
              .split('\n')
              .where(field.options.contains)
              .toSet();
          break;
        case MetadataFieldType.boolean:
          booleanValues[field.id] = value == 'true';
          break;
        default:
          controllers[field.id] = TextEditingController(text: value);
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.character == null ? '添加角色' : '编辑角色',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      _prepareFields();
                    });
                  },
                ),
                for (final field in selectedGame?.metadataFields ??
                    const <GameMetadataField>[]) ...[
                  const SizedBox(height: 12),
                  _fieldEditor(field),
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

  Widget _fieldEditor(GameMetadataField field) {
    switch (field.type) {
      case MetadataFieldType.choice:
        return DropdownButtonFormField<String?>(
          initialValue: choiceValues[field.id],
          decoration: InputDecoration(labelText: field.name),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('未设置')),
            ...field.options.map((option) => DropdownMenuItem<String?>(
                  value: option,
                  child: Text(option),
                )),
          ],
          onChanged: (value) =>
              setState(() => choiceValues[field.id] = value),
        );
      case MetadataFieldType.multiChoice:
        final selected = multiValues.putIfAbsent(field.id, () => <String>{});
        return InputDecorator(
          decoration: InputDecoration(labelText: field.name),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: field.options
                .map((option) => FilterChip(
                      label: Text(option),
                      selected: selected.contains(option),
                      onSelected: (enabled) => setState(() {
                        if (enabled) {
                          selected.add(option);
                        } else {
                          selected.remove(option);
                        }
                      }),
                    ))
                .toList(),
          ),
        );
      case MetadataFieldType.boolean:
        return SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(field.name, style: const TextStyle(fontSize: 13)),
          value: booleanValues[field.id] ?? false,
          onChanged: (value) =>
              setState(() => booleanValues[field.id] = value),
        );
      case MetadataFieldType.date:
        return _pickerField(
          field,
          icon: Icons.calendar_today_outlined,
          hint: '未设置日期',
          onPressed: () => _pickDate(field),
        );
      case MetadataFieldType.time:
        return _pickerField(
          field,
          icon: Icons.schedule_outlined,
          hint: '未设置时间',
          onPressed: () => _pickTime(field),
        );
      case MetadataFieldType.multiline:
        return TextField(
          controller: controllers[field.id],
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(labelText: field.name),
        );
      case MetadataFieldType.number:
        return TextField(
          controller: controllers[field.id],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(labelText: field.name, hintText: '请输入数字'),
        );
      case MetadataFieldType.url:
        return TextField(
          controller: controllers[field.id],
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
              labelText: field.name, hintText: 'https://example.com'),
        );
      case MetadataFieldType.text:
        return TextField(
          controller: controllers[field.id],
          decoration: InputDecoration(labelText: field.name),
        );
    }
  }

  Widget _pickerField(
    GameMetadataField field, {
    required IconData icon,
    required String hint,
    required VoidCallback onPressed,
  }) {
    final value = controllers[field.id]?.text ?? '';
    return InputDecorator(
      decoration: InputDecoration(labelText: field.name),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(value.isEmpty ? hint : value)),
          TextButton(onPressed: onPressed, child: const Text('选择')),
          if (value.isNotEmpty)
            IconButton(
              tooltip: '清除',
              onPressed: () => setState(() => controllers[field.id]?.clear()),
              icon: const Icon(Icons.close, size: 17),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate(GameMetadataField field) async {
    final controller = controllers[field.id]!;
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => controller.text = dateKey(value));
  }

  Future<void> _pickTime(GameMetadataField field) async {
    final controller = controllers[field.id]!;
    final parts = controller.text.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0)
        : TimeOfDay.now();
    final value =
        await showTimePicker(context: context, initialTime: initial);
    if (value != null) {
      setState(() => controller.text =
          '${twoDigits(value.hour)}:${twoDigits(value.minute)}');
    }
  }

  Future<void> _save() async {
    final name = nameController.text.trim();
    final account = accountController.text.trim();
    if (name.isEmpty || account.isEmpty || selectedGameId == null) {
      setState(() => validationMessage = '请填写角色名称、账号并选择所属游戏');
      return;
    }
    final values = <String, String>{};
    for (final field in selectedGame?.metadataFields ??
        const <GameMetadataField>[]) {
      final value = switch (field.type) {
        MetadataFieldType.choice => choiceValues[field.id] ?? '',
        MetadataFieldType.multiChoice =>
          (multiValues[field.id] ?? const <String>{}).join('\n'),
        MetadataFieldType.boolean =>
          (booleanValues[field.id] ?? false).toString(),
        _ => controllers[field.id]?.text.trim() ?? '',
      };
      if (field.type == MetadataFieldType.number &&
          value.isNotEmpty &&
          num.tryParse(value) == null) {
        setState(() => validationMessage = '“${field.name}”需要填写数字');
        return;
      }
      if (field.type == MetadataFieldType.url && value.isNotEmpty) {
        final uri = Uri.tryParse(value);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
          setState(() => validationMessage = '“${field.name}”需要填写完整链接');
          return;
        }
      }
      if (value.isNotEmpty) values[field.id] = value;
    }
    final legacyOccupation =
        values[legacyOccupationMetadataField.id] ?? '';
    if (widget.character == null) {
      await widget.state.addCharacter(
        name: name,
        account: account,
        occupation: legacyOccupation,
        gameId: selectedGameId!,
        metadataValues: values,
      );
    } else {
      await widget.state.updateCharacter(
        character: widget.character!,
        gameId: selectedGameId!,
        account: account,
        name: name,
        occupation: legacyOccupation,
        metadataValues: values,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    nameController.dispose();
    accountController.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
