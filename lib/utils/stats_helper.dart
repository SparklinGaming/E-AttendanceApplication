import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../repositories/shift_repository.dart';

/// Holds one day's data for the weekly bar chart.
class WeeklyDayData {
  final double hours;
  final bool isHoliday; // true = weekend or national holiday → red bar

  const WeeklyDayData({required this.hours, required this.isHoliday});
}

class StatsHelper {
  // ── Monthly stats ───────────────────────────────────────────────────

  /// [workSettings] may contain start/end times (fallback if no shift).
  /// [shift] overrides start time for late calculation.
  Map<String, dynamic> calculateStats(
    List<QueryDocumentSnapshot> docs, {
    Map<String, int>? workSettings,
    List<int>? workingDays,
    List<String>? holidays,
    ShiftDefinition? shift,
  }) {
    int present = 0;
    int late = 0;

    DateTime now = DateTime.now();
    String currentMonth = DateFormat('yyyy-MM').format(now);

    List<QueryDocumentSnapshot> monthDocs = docs.where((doc) {
      String date = doc['date'];
      return date.startsWith(currentMonth);
    }).toList();

    Set<String> presentDays = {};

    // Use shift start time if assigned, otherwise fall back to global settings
    final int startHour = shift?.startHour ?? workSettings?['start_hour'] ?? 9;
    final int startMinute =
        shift?.startMinute ?? workSettings?['start_minute'] ?? 0;

    for (var doc in monthDocs) {
      if (doc['type'] == 'in') {
        presentDays.add(doc['date']);

        Timestamp ts = doc['timestamp'];
        DateTime dt = ts.toDate();

        if (dt.hour > startHour ||
            (dt.hour == startHour && dt.minute > startMinute)) {
          late++;
        }
      }
    }

    present = presentDays.length;
    final expectedWorkdays = _expectedWorkdaysSoFar(
      now,
      workSettings: workSettings,
      workingDays: workingDays,
      holidays: holidays,
    );
    final absence = expectedWorkdays.difference(presentDays).length;

    return {
      'present': present,
      'late': late,
      'absence': absence,
    };
  }

  Set<String> _expectedWorkdaysSoFar(
    DateTime now, {
    Map<String, int>? workSettings,
    List<int>? workingDays,
    List<String>? holidays,
  }) {
    final expectedDays = <String>{};
    final endHour = workSettings?['end_hour'] ?? 17;
    final endMinute = workSettings?['end_minute'] ?? 0;
    final todayEndTime = DateTime(
      now.year,
      now.month,
      now.day,
      endHour,
      endMinute,
    );
    final lastCompletedDay = now.isAfter(todayEndTime) ? now.day : now.day - 1;

    final wDays = workingDays ?? [1, 2, 3, 4, 5];
    final holidaySet = Set<String>.from(holidays ?? []);

    for (int day = 1; day <= lastCompletedDay; day++) {
      final date = DateTime(now.year, now.month, day);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      if (!wDays.contains(date.weekday)) continue;
      if (holidaySet.contains(dateStr)) continue;

      expectedDays.add(dateStr);
    }
    return expectedDays;
  }

  // ── Weekly chart (legacy, kept for compatibility) ────────────────────

  List<double> calculateWeeklyData(List<QueryDocumentSnapshot> docs) {
    final detailed = calculateWeeklyDataDetailed(docs);
    return detailed.map((d) => d.hours).toList();
  }

  // ── Weekly chart with holiday flag ───────────────────────────────────

  List<WeeklyDayData> calculateWeeklyDataDetailed(
    List<QueryDocumentSnapshot> docs, {
    List<int>? workingDays,
    List<String>? holidays,
  }) {
    DateTime now = DateTime.now();
    // Start from Sunday of the current calendar week
    final sunday = now.subtract(Duration(days: now.weekday % 7));
    final result = <WeeklyDayData>[];
    final wDays = workingDays ?? [1, 2, 3, 4, 5];
    final holidaySet = Set<String>.from(holidays ?? []);

    for (int i = 0; i < 7; i++) {
      DateTime targetDate = sunday.add(Duration(days: i));
      String dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

      final bool isWeekend = !wDays.contains(targetDate.weekday);
      final bool isNationalHoliday = holidaySet.contains(dateStr);
      final bool isHoliday = isWeekend || isNationalHoliday;

      double hours = 0.0;

      var daysDocs = docs.where((d) => d['date'] == dateStr).toList();
      var ins = daysDocs.where((d) => d['type'] == 'in').toList();
      var outs = daysDocs.where((d) => d['type'] == 'out').toList();

      if (ins.isNotEmpty && outs.isNotEmpty) {
        ins.sort(
            (a, b) => (a['timestamp'] as Timestamp).compareTo(b['timestamp']));
        outs.sort(
            (a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp']));

        DateTime inTime = (ins.first['timestamp'] as Timestamp).toDate();
        DateTime outTime = (outs.first['timestamp'] as Timestamp).toDate();

        if (outTime.isAfter(inTime)) {
          double h = outTime.difference(inTime).inMinutes / 60.0;
          hours = h > 12 ? 12 : h;
        }
      }

      result.add(WeeklyDayData(hours: hours, isHoliday: isHoliday));
    }

    return result;
  }

  // ── Check if a check-in is late for a specific shift ────────────────

  /// Returns true if [checkInTime] is after the shift start time.
  /// Falls back to [workSettings] if no shift assigned.
  static bool isLate({
    required DateTime checkInTime,
    ShiftDefinition? shift,
    Map<String, int>? workSettings,
  }) {
    final int startHour = shift?.startHour ?? workSettings?['start_hour'] ?? 9;
    final int startMinute =
        shift?.startMinute ?? workSettings?['start_minute'] ?? 0;

    final threshold = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      startHour,
      startMinute,
    );
    return checkInTime.isAfter(threshold);
  }
}
