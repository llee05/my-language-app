/// Calculates the current streak from study-event timestamps.
///
/// Multiple events on the same local calendar day count once. A streak remains
/// current until the end of the day after the learner last studied, allowing
/// the learner to extend yesterday's streak by studying today.
int calculateCurrentStudyStreak({
  required Iterable<DateTime> studiedAt,
  required DateTime now,
}) {
  DateTime localDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DateTime previousDay(DateTime value) =>
      DateTime(value.year, value.month, value.day - 1);

  final today = localDay(now);
  final studyDays = studiedAt
      .map(localDay)
      .where((day) => !day.isAfter(today))
      .toSet();
  var cursor = studyDays.contains(today) ? today : previousDay(today);
  var streak = 0;

  while (studyDays.contains(cursor)) {
    streak++;
    cursor = previousDay(cursor);
  }

  return streak;
}
