import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../repositories/shift_repository.dart';
import 'web_download_stub.dart' if (dart.library.html) 'web_download.dart';

/// Result of a CSV export operation.
class CsvExportResult {
  final bool success;
  final String filePath;
  final String fileName;
  final String? error;

  const CsvExportResult({
    required this.success,
    required this.filePath,
    required this.fileName,
    this.error,
  });
}

class CsvExportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ShiftRepository _shiftRepository = ShiftRepository();

  /// Escape a string for safe CSV output (handles commas, quotes, newlines).
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Convert a list of rows (each row is a list of strings) to CSV content.
  String _buildCsv(List<List<String>> rows) {
    return rows.map((row) => row.map(_escapeCsv).join(',')).join('\n');
  }

  /// Save [content] to permanent local storage.
  /// Uses external storage (accessible) when available, falls back to app docs.
  /// Returns the full path of the saved file.
  Future<String> saveFileLocally(String content, String fileName) async {
    // Prefer external storage — accessible via ADB / Device File Explorer
    Directory baseDir;
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        baseDir = extDir;
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final exportDir = Directory('${baseDir.path}/EAttendExports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File('${exportDir.path}/$fileName');
    await file.writeAsString(content);
    return file.path;
  }

  /// Build CSV content, save to permanent local storage, and return the result.
  /// No share sheet is opened — the caller decides what to do with the file.
  Future<CsvExportResult> _buildAndSave(String content, String fileName) async {
    try {
      if (kIsWeb) {
        downloadCsvWebLocally(content, fileName);
        return CsvExportResult(
          success: true,
          filePath: 'Web Download ($fileName)',
          fileName: fileName,
        );
      }

      final localPath = await saveFileLocally(content, fileName);

      return CsvExportResult(
        success: true,
        filePath: localPath,
        fileName: fileName,
      );
    } catch (e) {
      return CsvExportResult(
        success: false,
        filePath: '',
        fileName: fileName,
        error: e.toString(),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 1. DAILY ATTENDANCE RECAP
  // ─────────────────────────────────────────────────────────────────────

  /// Export attendance for a specific date (defaults to today).
  /// Columns: Employee Name, Check In, Check Out, Status, Late (Y/N)
  Future<CsvExportResult> exportDailyAttendance({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

    // 1. Get all employees
    final usersSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    final Map<String, String> employeeNames = {};
    for (var doc in usersSnapshot.docs) {
      employeeNames[doc.id] = doc.data()['name'] ?? 'Unknown';
    }

    // 2. Get all attendance for this date
    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isEqualTo: dateStr)
        .get();

    // Group by uid → { checkIn, checkOut, checkInTime, checkOutTime }
    final Map<String, Map<String, dynamic>> attendanceMap = {};
    for (var doc in attendanceSnapshot.docs) {
      final data = doc.data();
      final uid = data['uid'] as String;
      final type = data['type'] as String;
      final ts = (data['timestamp'] as Timestamp).toDate();
      final timeStr = DateFormat('HH:mm').format(ts);

      attendanceMap.putIfAbsent(uid, () => {});
      if (type == 'in') {
        attendanceMap[uid]!['checkIn'] = timeStr;
        attendanceMap[uid]!['checkInTime'] = ts;
      } else if (type == 'out') {
        attendanceMap[uid]!['checkOut'] = timeStr;
        attendanceMap[uid]!['checkOutTime'] = ts;
      }
    }

    // 3. Get shift data for late calculation
    final assignments = await _shiftRepository.getDailyAssignments(dateStr);
    final shifts = await _shiftRepository.getShiftDefinitions();

    // 4. Build CSV
    final rows = <List<String>>[];
    rows.add(
        ['No', 'Employee Name', 'Check In', 'Check Out', 'Status', 'Late']);

    int no = 1;
    for (final entry in employeeNames.entries) {
      final uid = entry.key;
      final name = entry.value;
      final record = attendanceMap[uid];
      final status = record != null ? 'Present' : 'Absent';
      final checkIn = record?['checkIn'] ?? '-';
      final checkOut = record?['checkOut'] ?? '-';

      // Late determination
      String late = '-';
      if (record != null && record['checkInTime'] != null) {
        final checkInTime = record['checkInTime'] as DateTime;
        final shiftId = assignments[uid];

        int startHour = 8;
        int startMinute = 0;
        if (shiftId != null) {
          try {
            final shift = shifts.firstWhere((s) => s.id == shiftId);
            startHour = shift.startHour;
            startMinute = shift.startMinute;
          } catch (_) {}
        }

        if (checkInTime.hour > startHour ||
            (checkInTime.hour == startHour &&
                checkInTime.minute > startMinute)) {
          late = 'Yes';
        } else {
          late = 'No';
        }
      }

      rows.add([
        no.toString(),
        name,
        checkIn,
        checkOut,
        status,
        late,
      ]);
      no++;
    }

    // Summary row
    final presentCount = attendanceMap.length;
    final absentCount = employeeNames.length - presentCount;
    rows.add([]);
    rows.add(['SUMMARY', '', '', '', '', '']);
    rows.add(['Total Employees', employeeNames.length.toString()]);
    rows.add(['Present', presentCount.toString()]);
    rows.add(['Absent', absentCount.toString()]);

    final csv = _buildCsv(rows);
    return _buildAndSave(csv, 'attendance_$dateStr.csv');
  }

  // ─────────────────────────────────────────────────────────────────────
  // 2. MONTHLY ATTENDANCE RECAP
  // ─────────────────────────────────────────────────────────────────────

  /// Export attendance summary for a specific month (defaults to current).
  /// Columns: Employee Name, Total Present, Total Absent, Total Late, Leave Days
  Future<CsvExportResult> exportMonthlyAttendance(
      {int? year, int? month}) async {
    final now = DateTime.now();
    final targetYear = year ?? now.year;
    final targetMonth = month ?? now.month;
    final monthPrefix =
        DateFormat('yyyy-MM').format(DateTime(targetYear, targetMonth));
    final monthLabel =
        DateFormat('MMMM yyyy').format(DateTime(targetYear, targetMonth));

    // 1. Get all employees
    final usersSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    final List<Map<String, dynamic>> employees = [];
    for (var doc in usersSnapshot.docs) {
      employees.add({'uid': doc.id, 'name': doc.data()['name'] ?? 'Unknown'});
    }

    // 2. Get all attendance for this month
    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: '$monthPrefix-01')
        .where('date', isLessThanOrEqualTo: '$monthPrefix-31')
        .get();

    // 3. Get all leaves for this month
    final leavesSnapshot = await _firestore
        .collection('leaves')
        .where('date', isGreaterThanOrEqualTo: '$monthPrefix-01')
        .where('date', isLessThanOrEqualTo: '$monthPrefix-31')
        .get();

    // Process attendance per employee
    final Map<String, Set<String>> presentDays = {};
    final Map<String, Set<String>> lateDays = {};
    final Map<String, int> leaveCount = {};

    for (var doc in attendanceSnapshot.docs) {
      final data = doc.data();
      final uid = data['uid'] as String;
      final date = data['date'] as String;
      final type = data['type'] as String;

      if (type == 'in') {
        presentDays.putIfAbsent(uid, () => {}).add(date);
      }
    }

    // Count approved leaves per employee
    for (var doc in leavesSnapshot.docs) {
      final data = doc.data();
      final uid = data['uid'] as String;
      final status = data['status']?.toString().toLowerCase() ?? '';
      if (status == 'approved') {
        leaveCount[uid] = (leaveCount[uid] ?? 0) + 1;
      }
    }

    // Get shift data for late calculation
    final shifts = await _shiftRepository.getShiftDefinitions();

    // Calculate late days
    for (var doc in attendanceSnapshot.docs) {
      final data = doc.data();
      final uid = data['uid'] as String;
      final type = data['type'] as String;
      if (type != 'in') continue;

      final date = data['date'] as String;
      final ts = (data['timestamp'] as Timestamp).toDate();

      // Try to find if this employee has a shift
      final assignments = await _shiftRepository.getDailyAssignments(date);
      final shiftId = assignments[uid];
      int startHour = 8;
      int startMinute = 0;
      if (shiftId != null) {
        try {
          final shift = shifts.firstWhere((s) => s.id == shiftId);
          startHour = shift.startHour;
          startMinute = shift.startMinute;
        } catch (_) {}
      }

      if (ts.hour > startHour ||
          (ts.hour == startHour && ts.minute > startMinute)) {
        lateDays.putIfAbsent(uid, () => {}).add(date);
      }
    }

    // Calculate working days in month (weekdays only)
    int workingDays = 0;
    final daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(targetYear, targetMonth, d);
      if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
        workingDays++;
      }
    }

    // Build CSV
    final rows = <List<String>>[];
    rows.add([
      'No',
      'Employee Name',
      'Working Days',
      'Present',
      'Absent',
      'Late Days',
      'Leave Days',
      'Attendance %',
    ]);

    int no = 1;
    for (final emp in employees) {
      final uid = emp['uid'];
      final name = emp['name'];
      final totalPresent = presentDays[uid]?.length ?? 0;
      final totalLate = lateDays[uid]?.length ?? 0;
      final totalLeave = leaveCount[uid] ?? 0;
      final absent = workingDays - totalPresent;
      final percentage = workingDays > 0
          ? ((totalPresent / workingDays) * 100).toStringAsFixed(1)
          : '0.0';

      rows.add([
        no.toString(),
        name,
        workingDays.toString(),
        totalPresent.toString(),
        absent.toString(),
        totalLate.toString(),
        totalLeave.toString(),
        '$percentage%',
      ]);
      no++;
    }

    rows.add([]);
    rows.add(['SUMMARY', '', '', '', '', '', '', '']);
    rows.add(['Month', monthLabel]);
    rows.add(['Working Days', workingDays.toString()]);
    rows.add(['Total Employees', employees.length.toString()]);

    final csv = _buildCsv(rows);
    return _buildAndSave(csv, 'attendance_$monthPrefix.csv');
  }

  // ─────────────────────────────────────────────────────────────────────
  // 3. LEAVE DATA EXPORT
  // ─────────────────────────────────────────────────────────────────────

  /// Export all leave / permission requests.
  /// Columns: Employee Name, Type, Date, Reason, Status, Submitted
  Future<CsvExportResult> exportLeaves() async {
    final leavesSnapshot = await _firestore
        .collection('leaves')
        .orderBy('timestamp', descending: true)
        .get();

    final rows = <List<String>>[];
    rows.add([
      'No',
      'Employee Name',
      'Type',
      'Date',
      'Reason',
      'Status',
      'Submitted',
    ]);

    int no = 1;
    for (var doc in leavesSnapshot.docs) {
      final data = doc.data();
      final name = data['name'] ?? 'Unknown';
      final type = data['type'] ?? '-';
      final date = data['date'] ?? '-';
      final reason = data['reason'] ?? '-';
      final status = data['status'] ?? '-';

      String submitted = '-';
      if (data['timestamp'] is Timestamp) {
        submitted = DateFormat('dd MMM yyyy HH:mm')
            .format((data['timestamp'] as Timestamp).toDate());
      }

      rows.add([
        no.toString(),
        name,
        type,
        date,
        reason,
        status,
        submitted,
      ]);
      no++;
    }

    final csv = _buildCsv(rows);
    return _buildAndSave(csv, 'leaves_export.csv');
  }

  // ─────────────────────────────────────────────────────────────────────
  // 4. FULL COMPANY REPORT (single comprehensive file)
  // ─────────────────────────────────────────────────────────────────────

  /// Export a comprehensive company attendance report for a given month.
  /// Combines employee info, attendance matrix, and leave summary.
  Future<CsvExportResult> exportFullReport({int? year, int? month}) async {
    final now = DateTime.now();
    final targetYear = year ?? now.year;
    final targetMonth = month ?? now.month;
    final monthPrefix =
        DateFormat('yyyy-MM').format(DateTime(targetYear, targetMonth));
    final monthLabel =
        DateFormat('MMMM yyyy').format(DateTime(targetYear, targetMonth));

    // Calculate working days
    final daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final List<int> workingDayNumbers = [];
    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(targetYear, targetMonth, d);
      if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
        workingDayNumbers.add(d);
      }
    }

    // Get employees
    final usersSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    final List<Map<String, dynamic>> employees = [];
    for (var doc in usersSnapshot.docs) {
      employees.add({'uid': doc.id, 'name': doc.data()['name'] ?? 'Unknown'});
    }

    // Get attendance for the month
    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: '$monthPrefix-01')
        .where('date', isLessThanOrEqualTo: '$monthPrefix-31')
        .get();

    // Build attendance matrix: uid → { date → 'present' | 'late' | 'absent' }
    final Map<String, Map<String, String>> attendanceMatrix = {};
    for (var doc in attendanceSnapshot.docs) {
      final data = doc.data();
      final uid = data['uid'] as String;
      final date = data['date'] as String;
      final type = data['type'] as String;

      if (type == 'in') {
        attendanceMatrix.putIfAbsent(uid, () => {});
        attendanceMatrix[uid]![date] =
            'Present'; // Default, may be overridden to Late
      }
    }

    // Mark late days
    final shifts = await _shiftRepository.getShiftDefinitions();
    for (var doc in attendanceSnapshot.docs) {
      final data = doc.data();
      if (data['type'] != 'in') continue;
      final uid = data['uid'] as String;
      final date = data['date'] as String;
      final ts = (data['timestamp'] as Timestamp).toDate();

      final assignments = await _shiftRepository.getDailyAssignments(date);
      final shiftId = assignments[uid];
      int startHour = 8, startMinute = 0;
      if (shiftId != null) {
        try {
          final shift = shifts.firstWhere((s) => s.id == shiftId);
          startHour = shift.startHour;
          startMinute = shift.startMinute;
        } catch (_) {}
      }

      if (ts.hour > startHour ||
          (ts.hour == startHour && ts.minute > startMinute)) {
        if (attendanceMatrix[uid]?.containsKey(date) ?? false) {
          attendanceMatrix[uid]![date] = 'Late';
        }
      }
    }

    // Build CSV with attendance matrix (one column per working day)
    final rows = <List<String>>[];

    // Header row
    final header = <String>['No', 'Employee Name'];
    for (final d in workingDayNumbers) {
      header.add('Day $d');
    }
    header.addAll(['Present', 'Absent', 'Late', 'Attendance %']);
    rows.add(header);

    int no = 1;
    for (final emp in employees) {
      final uid = emp['uid'];
      final name = emp['name'];
      final row = <String>[no.toString(), name];

      int presentCount = 0;
      int lateCount = 0;

      for (final d in workingDayNumbers) {
        final dateStr = '$monthPrefix-${d.toString().padLeft(2, '0')}';
        final status = attendanceMatrix[uid]?[dateStr] ?? 'Absent';
        row.add(status);
        if (status == 'Present') presentCount++;
        if (status == 'Late') lateCount++;
      }

      final absentCount = workingDayNumbers.length - presentCount - lateCount;
      final percentage = workingDayNumbers.isNotEmpty
          ? ((presentCount / workingDayNumbers.length) * 100).toStringAsFixed(1)
          : '0.0';

      row.addAll([
        presentCount.toString(),
        absentCount.toString(),
        lateCount.toString(),
        '$percentage%',
      ]);
      rows.add(row);
      no++;
    }

    // Footer summary
    rows.add([]);
    rows.add(['REPORT SUMMARY']);
    rows.add(['Month', monthLabel]);
    rows.add(['Working Days', workingDayNumbers.length.toString()]);
    rows.add(['Total Employees', employees.length.toString()]);

    final csv = _buildCsv(rows);
    return _buildAndSave(csv, 'eattend_report_$monthPrefix.csv');
  }
}
