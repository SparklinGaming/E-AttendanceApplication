import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single shift definition.
class ShiftDefinition {
  final String id;
  final String name;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const ShiftDefinition({
    required this.id,
    required this.name,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'start_hour': startHour,
        'start_minute': startMinute,
        'end_hour': endHour,
        'end_minute': endMinute,
      };

  factory ShiftDefinition.fromMap(Map<String, dynamic> map) {
    return ShiftDefinition(
      id: map['id'] as String,
      name: map['name'] as String,
      startHour: map['start_hour'] as int,
      startMinute: map['start_minute'] as int,
      endHour: map['end_hour'] as int,
      endMinute: map['end_minute'] as int,
    );
  }

  ShiftDefinition copyWith({
    String? id,
    String? name,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) {
    return ShiftDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  /// Whether the shift spans midnight (end time < start time).
  bool get isOvernight =>
      endHour < startHour || (endHour == startHour && endMinute < startMinute);

  String formatTime() {
    final start =
        '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
    final end =
        '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  /// Returns start time as 'HH:mm' string.
  String formatStart() =>
      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';

  /// Returns end time as 'HH:mm' string.
  String formatEnd() =>
      '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
}

/// Repository for shift definitions and daily employee assignments.
class ShiftRepository {
  ShiftRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ── Shift definitions ───────────────────────────────────────────────

  Future<void> saveShiftDefinitions(List<ShiftDefinition> shifts) {
    return _firestore.collection('settings').doc('shifts').set({
      'definitions': shifts.map((s) => s.toMap()).toList(),
    });
  }

  Future<List<ShiftDefinition>> getShiftDefinitions() async {
    final doc = await _firestore.collection('settings').doc('shifts').get();
    final data = doc.data();
    if (!doc.exists || data == null || data['definitions'] == null) {
      return _defaultShifts();
    }
    final list = List<Map<String, dynamic>>.from(
      (data['definitions'] as List).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    return list.map((m) => ShiftDefinition.fromMap(m)).toList();
  }

  List<ShiftDefinition> _defaultShifts() => [
        const ShiftDefinition(
          id: 'morning',
          name: 'Pagi',
          startHour: 6,
          startMinute: 0,
          endHour: 14,
          endMinute: 0,
        ),
        const ShiftDefinition(
          id: 'afternoon',
          name: 'Siang',
          startHour: 14,
          startMinute: 0,
          endHour: 22,
          endMinute: 0,
        ),
        const ShiftDefinition(
          id: 'night',
          name: 'Malam',
          startHour: 22,
          startMinute: 0,
          endHour: 6,
          endMinute: 0,
        ),
      ];

  // ── Daily shift assignments ─────────────────────────────────────────

  /// dateStr in yyyy-MM-dd format
  Future<void> setDailyAssignments(
    String dateStr,
    Map<String, String> assignments, // uid → shiftId
  ) {
    return _firestore.collection('shift_assignments').doc(dateStr).set({
      'date': dateStr,
      'assignments': assignments,
    });
  }

  /// Returns uid → shiftId map for the given date.
  Future<Map<String, String>> getDailyAssignments(String dateStr) async {
    final doc =
        await _firestore.collection('shift_assignments').doc(dateStr).get();
    final data = doc.data();
    if (!doc.exists || data == null || data['assignments'] == null) {
      return {};
    }
    return Map<String, String>.from(data['assignments'] as Map);
  }

  /// Get the shift definition assigned to a specific employee on a date.
  /// Returns null if no assignment exists.
  Future<ShiftDefinition?> getEmployeeShift(
    String uid,
    String dateStr,
  ) async {
    final assignments = await getDailyAssignments(dateStr);
    final shiftId = assignments[uid];
    if (shiftId == null) return null;
    final shifts = await getShiftDefinitions();
    try {
      return shifts.firstWhere((s) => s.id == shiftId);
    } catch (_) {
      return null;
    }
  }

  /// Stream of assignments for a date range (useful for schedule views).
  Stream<QuerySnapshot> getAssignmentsStream(String dateStr) {
    return _firestore
        .collection('shift_assignments')
        .where('date', isEqualTo: dateStr)
        .snapshots();
  }
}
