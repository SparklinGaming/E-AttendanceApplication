import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../repositories/shift_repository.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ShiftRepository _shiftRepository = ShiftRepository();

  String get _todayDate => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<Map<String, dynamic>> getDashboardData() async {
    final results = await Future.wait([
      _getAttendanceStats(),
      _getLeaveStats(),
      _getOvertimeStats(),
      _getShiftStats(),
      _getForecastStats(),
    ]);

    return {
      'attendance': results[0],
      'leave': results[1],
      'overtime': results[2],
      'shift': results[3],
      'forecast': results[4],
    };
  }

  Future<Map<String, dynamic>> _getAttendanceStats() async {
    // 1. Total employees
    final usersSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();
    int totalEmployees = usersSnapshot.size;

    List<Map<String, dynamic>> allEmployees = usersSnapshot.docs
        .map((d) => {'uid': d.id, 'name': d.data()['name'] ?? 'Unknown'})
        .toList();

    // 2. Attendance today
    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isEqualTo: _todayDate)
        .where('type', isEqualTo: 'in')
        .get();

    List<Map<String, dynamic>> presentUsers = [];
    List<Map<String, dynamic>> lateUsers = [];
    Set<String> presentUids = {};

    // 3. Late calculation
    final assignments = await _shiftRepository.getDailyAssignments(_todayDate);
    final shifts = await _shiftRepository.getShiftDefinitions();

    for (var doc in attendanceSnapshot.docs) {
      final uid = doc['uid'];
      final name = (doc.data() as Map<String, dynamic>).containsKey('name') ? doc['name'] : 'Unknown';
      final timestamp = doc['timestamp'] as Timestamp;
      final checkInTime = timestamp.toDate();

      presentUids.add(uid);
      presentUsers.add({
        'uid': uid,
        'name': name,
        'time': DateFormat('HH:mm').format(checkInTime)
      });

      final shiftId = assignments[uid];
      ShiftDefinition? shiftDef;
      if (shiftId != null) {
        try {
          shiftDef = shifts.firstWhere((s) => s.id == shiftId);
        } catch (_) {}
      }

      int startHour = shiftDef?.startHour ?? 8;
      int startMinute = shiftDef?.startMinute ?? 0;

      // Compare time
      if (checkInTime.hour > startHour ||
          (checkInTime.hour == startHour && checkInTime.minute > startMinute)) {
        lateUsers.add({
          'uid': uid,
          'name': name,
          'time': DateFormat('HH:mm').format(checkInTime)
        });
      }
    }

    List<Map<String, dynamic>> absentUsers = allEmployees
        .where((emp) => !presentUids.contains(emp['uid']))
        .toList();

    double attendancePercent =
        totalEmployees > 0 ? (presentUsers.length / totalEmployees) * 100 : 0.0;

    return {
      'totalEmployees': totalEmployees,
      'presentToday': presentUsers.length,
      'absentToday': absentUsers.length,
      'lateCount': lateUsers.length,
      'attendancePercentage': attendancePercent,
      'presentUsers': presentUsers,
      'absentUsers': absentUsers,
      'lateUsers': lateUsers,
    };
  }

  Future<Map<String, dynamic>> _getLeaveStats() async {
    final leavesSnapshot = await _firestore.collection('leaves').get();

    int totalRequests = leavesSnapshot.size;
    int approved = 0;
    int pending = 0;
    int permissionCount = 0;

    for (var doc in leavesSnapshot.docs) {
      final data = doc.data();
      final status = data['status']?.toString().toLowerCase() ?? '';
      final type = data['type']?.toString().toLowerCase() ?? '';

      if (status == 'approved') approved++;
      if (status == 'pending') pending++;

      if (type.contains('permission') ||
          type.contains('izin') ||
          type.contains('sick') ||
          type.contains('sakit')) {
        permissionCount++;
      }
    }

    return {
      'totalRequests': totalRequests,
      'approved': approved,
      'pending': pending,
      'permissionCount': permissionCount,
    };
  }

  Future<Map<String, dynamic>> _getOvertimeStats() async {
    // Mock collection since it might not exist yet
    int totalSubmissions = 0;
    int approved = 0;
    int totalHours = 0;

    try {
      final overtimeSnapshot = await _firestore.collection('overtimes').get();
      totalSubmissions = overtimeSnapshot.size;
      for (var doc in overtimeSnapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase() ?? '';
        if (status == 'approved') {
          approved++;
          totalHours += (data['duration_hours'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (e) {
      // ignore if collection doesn't exist
    }

    return {
      'totalSubmissions': totalSubmissions,
      'approved': approved,
      'totalHours': totalHours,
    };
  }

  Future<Map<String, dynamic>> _getShiftStats() async {
    final assignments = await _shiftRepository.getDailyAssignments(_todayDate);
    final shifts = await _shiftRepository.getShiftDefinitions();

    final usersSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    int totalScheduled = assignments.length;
    int totalEmployees = usersSnapshot.size;
    int withoutShift =
        (totalEmployees - totalScheduled).clamp(0, totalEmployees);

    Map<String, int> employeesPerShift = {};
    for (var shift in shifts) {
      employeesPerShift[shift.name] = 0;
    }

    for (var shiftId in assignments.values) {
      try {
        final shift = shifts.firstWhere((s) => s.id == shiftId);
        employeesPerShift[shift.name] = (employeesPerShift[shift.name] ?? 0) + 1;
      } catch (_) {}
    }

    return {
      'totalScheduled': totalScheduled,
      'employeesPerShift': employeesPerShift,
      'withoutShift': withoutShift,
    };
  }

  Future<Map<String, dynamic>> _getForecastStats() async {
    // Generate simple moving average for past 7 days
    List<int> pastAttendance = [];
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      String dateStr = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('date', isEqualTo: dateStr)
          .where('type', isEqualTo: 'in')
          .get();
      pastAttendance.add(attendanceSnapshot.size);
    }

    double avgAttendance = pastAttendance.isNotEmpty
        ? pastAttendance.reduce((a, b) => a + b) / pastAttendance.length
        : 0;

    int lastVal = pastAttendance.isNotEmpty ? pastAttendance.last : 0;

    return {
      'past7Days': pastAttendance,
      'estimatedTrend':
          avgAttendance > lastVal ? 'Decreasing' : 'Increasing',
      'weeklyPrediction': avgAttendance.round(),
    };
  }
}
