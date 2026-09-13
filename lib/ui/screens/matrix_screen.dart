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
  String query = '';

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
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
        action: SizedBox(
          width: 230,
          child: TextField(
            controller: searchController,
            onChanged: (value) => setState(() => query = value.trim()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: '搜索任务',
            ),
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
                                                      task, DateTime.now()),
                                                  taskPeriodEnd(
                                                      task, DateTime.now())) >=
                                              task.targetCount
                                          : task.isCompletedOn(DateTime.now()));
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
                                                      ? const Color(0xffe5f1ee)
                                                      : Colors.white,
                                                  border: Border.all(
                                                      color: done
                                                          ? AppTheme.accent
                                                          : AppTheme.line),
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
    super.dispose();
  }
}
