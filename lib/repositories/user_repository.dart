import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserRepository {
  UserRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<DocumentSnapshot> getUserDocument(String uid) {
    return _firestore.collection('users').doc(uid).get();
  }

  Stream<QuerySnapshot> getEmployees() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .snapshots();
  }

  Future<void> deleteEmployee(String uid) {
    return _firestore.collection('users').doc(uid).delete();
  }

  Future<void> createUserDoc(
    String uid,
    String email,
    String name,
    String role,
  ) {
    return _firestore.collection('users').doc(uid).set({
      'email': email,
      'name': name,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserProfile(
    String uid, {
    String? name,
    String? photoUrl,
  }) async {
    final updateData = <String, dynamic>{};
    if (name != null) updateData['name'] = name;
    if (photoUrl != null) updateData['photoUrl'] = photoUrl;
    if (updateData.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updateData);
    }
  }

  Future<String> uploadProfilePicture(String uid, File imageFile) async {
    final ref = _storage.ref().child('profile_pictures').child('$uid.jpg');
    await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  // ── Leave Balance ─────────────────────────────────────────────────────

  Future<Map<String, int>> getLeaveBalance(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null || data['leave_balance'] == null) {
      // Defaults:
      // annual: 12 days remaining (counts down when used)
      // special: counts up from 0 when used
      // sick: counts up from 0 when used
      return {'annual': 12, 'special': 0, 'sick': 0};
    }
    return Map<String, int>.from(data['leave_balance']);
  }

  Future<void> setLeaveBalance(String uid, Map<String, int> balance) async {
    await _firestore.collection('users').doc(uid).update({
      'leave_balance': balance,
    });
  }
}
