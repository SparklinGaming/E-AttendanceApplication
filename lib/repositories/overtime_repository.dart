import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Represents an overtime request.
class OvertimeRequest {
  final String? docId;
  final String uid;
  final String name;
  final String date; // yyyy-MM-dd
  final String shiftStart; // HH:mm
  final String shiftEnd; // HH:mm
  final DateTime overtimeStart;
  final DateTime overtimeEnd;
  final double breakHours; // usually 0 for overtime
  final double durationHours; // calculated: (end - start - break)
  final String compensationType; // 'upah_lembur' or 'replacement_off'
  final String notes;
  final String? attachmentUrl;
  final String status; // Pending, Approved, Rejected
  final Timestamp? createdAt;

  OvertimeRequest({
    this.docId,
    required this.uid,
    required this.name,
    required this.date,
    required this.shiftStart,
    required this.shiftEnd,
    required this.overtimeStart,
    required this.overtimeEnd,
    this.breakHours = 0,
    required this.durationHours,
    required this.compensationType,
    this.notes = '',
    this.attachmentUrl,
    this.status = 'Pending',
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'date': date,
        'shift_start': shiftStart,
        'shift_end': shiftEnd,
        'overtime_start': Timestamp.fromDate(overtimeStart),
        'overtime_end': Timestamp.fromDate(overtimeEnd),
        'break_hours': breakHours,
        'duration_hours': durationHours,
        'compensation_type': compensationType,
        'notes': notes,
        'attachment_url': attachmentUrl,
        'status': status,
        'created_at': createdAt ?? FieldValue.serverTimestamp(),
      };

  factory OvertimeRequest.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return OvertimeRequest(
      docId: doc.id,
      uid: d['uid'] ?? '',
      name: d['name'] ?? '',
      date: d['date'] ?? '',
      shiftStart: d['shift_start'] ?? '',
      shiftEnd: d['shift_end'] ?? '',
      overtimeStart: (d['overtime_start'] as Timestamp).toDate(),
      overtimeEnd: (d['overtime_end'] as Timestamp).toDate(),
      breakHours: (d['break_hours'] ?? 0).toDouble(),
      durationHours: (d['duration_hours'] ?? 0).toDouble(),
      compensationType: d['compensation_type'] ?? 'upah_lembur',
      notes: d['notes'] ?? '',
      attachmentUrl: d['attachment_url'],
      status: d['status'] ?? 'Pending',
      createdAt: d['created_at'] as Timestamp?,
    );
  }
}

/// Repository for overtime requests.
class OvertimeRepository {
  OvertimeRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference get _collection =>
      _firestore.collection('overtime_requests');

  // ── Submit overtime request ───────────────────────────────────────

  Future<void> submitOvertime(OvertimeRequest request) async {
    await _collection.add(request.toMap());

    await _firestore.collection('notifications').add({
      'title': 'Overtime Request',
      'message':
          '${request.name} mengajukan lembur ${request.durationHours.toStringAsFixed(1)} jam pada ${request.date}',
      'created_at': FieldValue.serverTimestamp(),
      'target': 'admin',
    });
  }

  // ── Upload attachment ─────────────────────────────────────────────

  Future<String> uploadAttachment(String uid, File file) async {
    final ref = _storage
        .ref()
        .child('overtime_attachments')
        .child('${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  // ── Employee: get own requests ────────────────────────────────────

  Stream<QuerySnapshot> getUserOvertimeStream(String uid) {
    return _collection
        .where('uid', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // ── Admin: get pending overtime requests ──────────────────────────

  Stream<QuerySnapshot> getPendingOvertime() {
    return _collection
        .where('status', isEqualTo: 'Pending')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getAllOvertime() {
    return _collection.orderBy('created_at', descending: true).snapshots();
  }

  // ── Admin: approve / reject ───────────────────────────────────────

  Future<void> updateStatus(String docId, String status, String uid) async {
    await _collection.doc(docId).update({'status': status});

    await _firestore.collection('notifications').add({
      'title': 'Overtime $status',
      'message': 'Pengajuan lembur Anda telah $status.',
      'created_at': FieldValue.serverTimestamp(),
      'uid': uid,
    });
  }
}
