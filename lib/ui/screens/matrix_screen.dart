import 'package:flutter/material.dart';

import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class MatrixScreen extends StatefulWidget {
  const MatrixScreen({required this.state, super.key});
  final AppState state;

  @override
  State<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends State<MatrixScreen> {
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();
  String query = '';
  bool searchExpanded = false;

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final taskDate = state.currentTaskDate;
    final templates = <String, List<TaskRecord>>{};
    for (final task in state.tasks) {
      templates.putIfAbsent(task.templateId, () => []).add(task);
    }
    final visibleTemplates = templates.values
        .where((tasks) => query.isEmpty ||
            tasks.any((task) =>
                task.title.toLowerCase().contains(query.toLowerCase())))
        .toList()
      ..sort((a, b) => a.first.title.compareTo(b.first.title));
    return Column(children: [
      PageHeader(
        title: '任务',
        subtitle: '横向查看每个角色的完成情况',
        titleAction: SizedBox(
          width: searchExpanded ? 230 : 40,
          child: searchExpanded
              ? TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  onChanged: (value) =>
                      setState(() => query = value.trim()),
                  decoration: InputDecoration(
                    hintText: '搜索任务',
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
      Expanded(
          child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: DataTable(
                      headingRowHeight: 40,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 58,
                      columnSpacing: 28,
                      horizontalMargin: 0,
                      headingTextStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.muted),
                      columns: [
                        const DataColumn(label: Text('任务')),
                        ...state.characters.map((character) => DataColumn(
                                label: Row(children: [
                              CharacterAvatar(character: character, size: 24),
                              const SizedBox(width: 6),
                              Text(character.name)
                            ])))
                      ],
                      rows: visibleTemplates
                          .map((templateTasks) => DataRow(cells: [
                                DataCell(Text(templateTasks.first.title,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600))),
                                ...state.characters.map((character) {
                                  final task = state
                                      .tasksForCharacter(character.id)
                                      .where((item) =>
                                          item.templateId ==
                                          templateTasks.first.templateId)
                                      .firstOrNull;
                                  final done = task != null &&
                                      (task.isCountTask
                                          ? task.countInRange(
                                                  taskPeriodStart(
                                                      task, taskDate),
                                                  taskPeriodEnd(
                                                      task, taskDate)) >=
                                              task.targetCount
                                          : task.isCompletedOn(taskDate));
                                  return DataCell(task == null
                                      ? const Text('—',
                                          style:
                                              TextStyle(color: AppTheme.muted))
                                      : InkWell(
                                          onTap: () => state.toggleTask(task),
                                          child: Container(
                                              width: 28,
                                              height: 28,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                  color: done
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primaryContainer
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .surface,
                                                  border: Border.all(
                                                      color: done
                                                          ? AppTheme.accent
                                                          : Theme.of(context)
                                                              .colorScheme
                                                              .outlineVariant),
                                                  borderRadius:
                                                      BorderRadius.circular(5)),
                                              child: Icon(
                                                  done
                                                      ? Icons.check
                                                      : Icons.remove,
                                                  size: 16,
                                                  color: done
                                                      ? AppTheme.accent
                                                      : AppTheme.muted))));
                                })
                              ]))
                          .toList()))))
    ]);
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
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
}
