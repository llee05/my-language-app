/// Summary of saved review activity for one Monday-to-Sunday week.
///
/// Per-day arrays are ordered Monday through Sunday so index 0 is always the
/// week's start and index 6 is always its end.
class WeeklyProgressReport {
  const WeeklyProgressReport({
    this.weekStart,
    this.xpByDay = const [0, 0, 0, 0, 0, 0, 0],
    this.reviewsByDay = const [0, 0, 0, 0, 0, 0, 0],
    this.correctByDay = const [0, 0, 0, 0, 0, 0, 0],
  });

  /// Local midnight on the Monday that starts the reported week, or null when
  /// a report carries no saved data.
  final DateTime? weekStart;

  final List<int> xpByDay;
  final List<int> reviewsByDay;
  final List<int> correctByDay;

  /// Local midnight on the Sunday that ends the reported week.
  DateTime? get weekEnd =>
      weekStart?.add(const Duration(days: DateTime.daysPerWeek - 1));

  int get totalXp => xpByDay.fold(0, (total, xp) => total + xp);

  int get reviewCount => reviewsByDay.fold(0, (total, n) => total + n);

  int get correctReviewCount => correctByDay.fold(0, (total, n) => total + n);

  double get accuracy =>
      reviewCount == 0 ? 0 : correctReviewCount / reviewCount;

  int get activeDays => reviewsByDay.where((n) => n > 0).length;

  /// Index into the Monday-first day arrays of the highest-XP day, or null
  /// when nothing was studied. Ties keep the earlier day.
  int? get bestDayIndex {
    var bestIndex = -1;
    var bestXp = 0;
    for (var index = 0; index < xpByDay.length; index++) {
      if (xpByDay[index] > bestXp) {
        bestIndex = index;
        bestXp = xpByDay[index];
      }
    }
    return bestIndex < 0 ? null : bestIndex;
  }
}
