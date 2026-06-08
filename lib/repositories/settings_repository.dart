import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SettingsRepository {
  SettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ── Work timing ──────────────────────────────────────────────────────

  Future<void> setWorkSettings(TimeOfDay start, TimeOfDay end) {
    return _firestore.collection('settings').doc('work_timing').set({
      'start_hour': start.hour,
      'start_minute': start.minute,
      'end_hour': end.hour,
      'end_minute': end.minute,
    }, SetOptions(merge: true));
  }

  Future<Map<String, int>?> getWorkSettings() async {
    final doc =
        await _firestore.collection('settings').doc('work_timing').get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;

    return {
      'start_hour': data['start_hour'],
      'start_minute': data['start_minute'],
      'end_hour': data['end_hour'],
      'end_minute': data['end_minute'],
    };
  }

  // ── Working days (1 = Monday … 7 = Sunday) ───────────────────────────

  Future<void> setWorkingDays(List<int> days) {
    return _firestore.collection('settings').doc('work_timing').set({
      'working_days': days,
    }, SetOptions(merge: true));
  }

  Future<List<int>> getWorkingDays() async {
    final doc =
        await _firestore.collection('settings').doc('work_timing').get();
    final data = doc.data();
    if (!doc.exists || data == null || data['working_days'] == null) {
      // Default: Monday–Friday
      return [1, 2, 3, 4, 5];
    }
    return List<int>.from(data['working_days']);
  }

  // ── National holidays ────────────────────────────────────────────────

  Future<void> setHolidays(List<String> dates) {
    return _firestore
        .collection('settings')
        .doc('holidays')
        .set({'dates': dates});
  }

  Future<List<String>> getHolidays() async {
    final doc = await _firestore.collection('settings').doc('holidays').get();
    final data = doc.data();
    if (!doc.exists || data == null || data['dates'] == null) return [];
    return List<String>.from(data['dates']);
  }

  // ── Combined config (convenience) ────────────────────────────────────

  /// Fetches work timing, working days and holidays in one go.
  Future<Map<String, dynamic>?> getFullWorkConfig() async {
    final timingDoc =
        await _firestore.collection('settings').doc('work_timing').get();
    final holidayDoc =
        await _firestore.collection('settings').doc('holidays').get();

    final timing = timingDoc.data();
    if (!timingDoc.exists || timing == null) return null;

    final holidaysData = holidayDoc.data();
    final List<String> holidays = (holidayDoc.exists &&
            holidaysData != null &&
            holidaysData['dates'] != null)
        ? List<String>.from(holidaysData['dates'])
        : [];

    final List<int> workingDays = (timing['working_days'] != null)
        ? List<int>.from(timing['working_days'])
        : [1, 2, 3, 4, 5];

    return {
      'start_hour': timing['start_hour'],
      'start_minute': timing['start_minute'],
      'end_hour': timing['end_hour'],
      'end_minute': timing['end_minute'],
      'working_days': workingDays,
      'holidays': holidays,
    };
  }
}
