import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Represents an issue/report submitted by a store employee.
class IssueReport {
  final String? docId;
  final String uid;
  final String name;
  final String category;
  final String description;
  final String? attachmentUrl;
  final String status; // Pending, Seen, Resolved
  final Timestamp? createdAt;

  IssueReport({
    this.docId,
    required this.uid,
    required this.name,
    required this.category,
    required this.description,
    this.attachmentUrl,
    this.status = 'Pending',
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'category': category,
        'description': description,
        'attachment_url': attachmentUrl,
        'status': status,
        'created_at': createdAt ?? FieldValue.serverTimestamp(),
      };

  factory IssueReport.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return IssueReport(
      docId: doc.id,
      uid: d['uid'] ?? '',
      name: d['name'] ?? '',
      category: d['category'] ?? '',
      description: d['description'] ?? '',
      attachmentUrl: d['attachment_url'],
      status: d['status'] ?? 'Pending',
      createdAt: d['created_at'] as Timestamp?,
    );
  }
}

/// Repository for employee issue reports.
class IssueRepository {
  IssueRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference get _collection =>
      _firestore.collection('issue_reports');

  /// Submit a new issue report.
  Future<void> submitIssue(IssueReport issue) async {
    await _collection.add(issue.toMap());

    await _firestore.collection('notifications').add({
      'title': 'New Issue Report',
      'message':
          '${issue.name} reported: ${issue.category} — ${issue.description.length > 80 ? '${issue.description.substring(0, 80)}...' : issue.description}',
      'created_at': FieldValue.serverTimestamp(),
      'target': 'admin',
    });
  }

  /// Upload an attachment image.
  Future<String> uploadAttachment(String uid, File file) async {
    final ref = _storage
        .ref()
        .child('issue_attachments')
        .child('${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  /// Stream the current employee's own reports.
  Stream<QuerySnapshot> getUserIssuesStream(String uid) {
    return _collection
        .where('uid', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Admin: get all pending reports.
  Stream<QuerySnapshot> getPendingIssues() {
    return _collection
        .where('status', isEqualTo: 'Pending')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Admin: get all reports.
  Stream<QuerySnapshot> getAllIssues() {
    return _collection.orderBy('created_at', descending: true).snapshots();
  }

  /// Admin: update report status.
  Future<void> updateStatus(String docId, String status, String uid) async {
    await _collection.doc(docId).update({'status': status});

    await _firestore.collection('notifications').add({
      'title': 'Issue Report $status',
      'message': 'Your issue report has been marked as $status.',
      'created_at': FieldValue.serverTimestamp(),
      'uid': uid,
    });
  }
}
