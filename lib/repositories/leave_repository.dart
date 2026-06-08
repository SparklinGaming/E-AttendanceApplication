import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRepository {
  LeaveRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> submitRequest(
    String uid,
    String type,
    String date,
    String reason,
  ) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final name = userDoc.exists && userDoc.data() != null
        ? userDoc.data()!['name']
        : 'Unknown';

    await _firestore.collection('leaves').add({
      'uid': uid,
      'name': name,
      'type': type,
      'date': date,
      'reason': reason,
      'status': 'Pending',
      'timestamp': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('notifications').add({
      'title': 'New Request',
      'message': '$name requested $type for $date',
      'created_at': FieldValue.serverTimestamp(),
      'target': 'admin',
    });
  }

  Stream<QuerySnapshot> getPendingLeaves() {
    return _firestore
        .collection('leaves')
        .where('status', isEqualTo: 'Pending')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getAllLeaves() {
    return _firestore
        .collection('leaves')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> updateRequestStatus(
    String docId,
    String status,
    String uid,
    String type,
  ) async {
    await _firestore.collection('leaves').doc(docId).update({
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('notifications').add({
      'title': 'Request Updated',
      'message': 'Your $type request has been $status.',
      'created_at': FieldValue.serverTimestamp(),
      'uid': uid,
    });
  }

  Future<void> deleteLeave(String docId) {
    return _firestore.collection('leaves').doc(docId).delete();
  }
}
