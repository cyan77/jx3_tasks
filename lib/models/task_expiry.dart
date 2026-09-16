import 'task_models.dart';

enum TaskExpiryStatus { normal, expiringSoon, overdue }

/// Returns the urgency of an unfinished one-time task.
///
/// "Expiring soon" means fewer than seven calendar days remain, or there is
/// no China rest day from [currentDate] (inclusive) to the day before the
/// deadline. Published holiday schedules override ordinary weekends; years
/// without published data fall back to Saturday and Sunday.
TaskExpiryStatus taskExpiryStatus(TaskRecord task, DateTime currentDate) {
  if (task.frequency != TaskFrequency.once ||
      task.dueDate == null ||
      task.isCompletedOn(currentDate)) {
    return TaskExpiryStatus.normal;
  }
  final current = startOfDay(currentDate);
  final deadline = startOfDay(task.dueDate!);
  if (deadline.isBefore(current)) return TaskExpiryStatus.overdue;
  if (deadline.difference(current).inDays < 7) {
    return TaskExpiryStatus.expiringSoon;
  }

  for (var day = current;
      day.isBefore(deadline);
      day = day.add(const Duration(days: 1))) {
    if (isChinaRestDay(day)) return TaskExpiryStatus.normal;
  }
  return TaskExpiryStatus.expiringSoon;
}

bool isChinaRestDay(DateTime date) {
  final key = dateKey(date);
  if (_chinaAdjustedWorkdays.contains(key)) return false;
  if (_chinaPublicHolidayBreaks.contains(key)) return true;
  return date.weekday == DateTime.saturday ||
      date.weekday == DateTime.sunday;
}

// 国务院办公厅 2026 年部分节假日安排。周末包含在连续放假区间内，
// 单独列出的调休补班日优先视为工作日。
const _chinaPublicHolidayBreaks = <String>{
  '2026-01-01', '2026-01-02', '2026-01-03',
  '2026-02-15', '2026-02-16', '2026-02-17', '2026-02-18',
  '2026-02-19', '2026-02-20', '2026-02-21', '2026-02-22',
  '2026-02-23',
  '2026-04-04', '2026-04-05', '2026-04-06',
  '2026-05-01', '2026-05-02', '2026-05-03', '2026-05-04',
  '2026-05-05',
  '2026-06-19', '2026-06-20', '2026-06-21',
  '2026-09-25', '2026-09-26', '2026-09-27',
  '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04',
  '2026-10-05', '2026-10-06', '2026-10-07',
};

const _chinaAdjustedWorkdays = <String>{
  '2026-01-04',
  '2026-02-14',
  '2026-02-28',
  '2026-05-09',
  '2026-09-20',
  '2026-10-10',
};
