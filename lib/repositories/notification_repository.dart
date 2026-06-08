import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> addNotification(String title, String message) {
    return _firestore.collection('notifications').add({
      'title': title,
      'message': message,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getNotifications() {
    return _firestore
        .collection('notifications')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserNotifications(String uid) {
    return _firestore
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  Future<void> deleteNotification(String docId) {
    return _firestore.collection('notifications').doc(docId).delete();
  }
}
