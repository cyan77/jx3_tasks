import 'package:flutter/material.dart';

import '../../models/task_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class MatrixScreen extends StatelessWidget {
  const MatrixScreen({required this.state, super.key});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final titles = state.tasks.map((task) => task.title).toSet().toList();
    return Column(children: [
      PageHeader(title: '任务', subtitle: '横向查看每个角色的完成情况'),
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
                      rows: titles
                          .map((title) => DataRow(cells: [
                                DataCell(Text(title,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600))),
                                ...state.characters.map((character) {
                                  final task = state
                                      .tasksForCharacter(character.id)
                                      .where((item) => item.title == title)
                                      .firstOrNull;
                                  final done = task != null &&
                                      (task.isCountTask
                                          ? task.countInRange(
                                                  taskPeriodStart(
                                                      task, DateTime.now()),
                                                  taskPeriodEnd(
                                                      task, DateTime.now())) >=
                                              task.targetCount
                                          : task.isDoneOn(DateTime.now()));
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
}
