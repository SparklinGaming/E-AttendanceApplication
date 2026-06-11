import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceRepository {
  AttendanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String get _todayDate => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> checkIn(String uid,
      {String? notes, double? latitude, double? longitude}) async {
    final now = DateTime.now();
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final name = userDoc.data()?['name'] ?? 'Unknown';

    await _firestore.collection('attendance').add({
      'uid': uid,
      'name': name,
      'date': _todayDate,
      'type': 'in',
      'notes': notes,
      'timestamp': Timestamp.fromDate(now),
      if (latitude != null && longitude != null) ...{
        'latitude': latitude,
        'longitude': longitude,
      },
    });
  }

  Future<void> checkOut(String uid, {String? notes}) async {
    final now = DateTime.now();
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final name = userDoc.data()?['name'] ?? 'Unknown';

    await _firestore.collection('attendance').add({
      'uid': uid,
      'name': name,
      'date': _todayDate,
      'type': 'out',
      'notes': notes,
      'timestamp': Timestamp.fromDate(now),
    });
  }

  Stream<QuerySnapshot> getUserAttendanceStream(String uid) {
    return _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot> getAttendanceRecords(String? date) {
    Query query = _firestore
        .collection('attendance')
        .orderBy('timestamp', descending: true);
    if (date != null) {
      query = query.where('date', isEqualTo: date);
    }
    return query.snapshots();
  }

  Future<Map<String, int>> getDashboardStats() async {
    final usersSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isEqualTo: _todayDate)
        .where('type', isEqualTo: 'in')
        .get();

    final presentUserIds =
        attendanceSnapshot.docs.map((doc) => doc['uid']).toSet();

    return {
      'totalEmployees': usersSnapshot.size,
      'presentToday': presentUserIds.length,
    };
  }
}
