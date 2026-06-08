import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/settings_repository.dart';

class AttendanceRecordsPage extends StatefulWidget {
  const AttendanceRecordsPage({super.key});

  @override
  State<AttendanceRecordsPage> createState() => _AttendanceRecordsPageState();
}

class _AttendanceRecordsPageState extends State<AttendanceRecordsPage> {
  final AttendanceRepository _attendanceRepository = AttendanceRepository();
  final SettingsRepository _settingsRepository = SettingsRepository();
  String? _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate != null
          ? DateTime.parse(_selectedDate!)
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Logs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _selectedDate = null),
            ),
        ],
      ),
      body: FutureBuilder<Map<String, int>?>(
          future: _settingsRepository.getWorkSettings(),
          builder: (context, settingsSnapshot) {
            final settings = settingsSnapshot.data;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _selectedDate != null
                        ? 'Date: $_selectedDate'
                        : 'Showing All History',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _attendanceRepository
                        .getAttendanceRecords(_selectedDate),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text('No records for this date.'));
                      }

                      return ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var data = snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;
                          bool isCheckIn = data['type'] == 'in';
                          Timestamp ts = data['timestamp'];
                          DateTime dt = ts.toDate();
                          String time = DateFormat('hh:mm a').format(dt);
                          String name = data['name'] ?? 'Unknown User';

                          // Status Logic
                          String statusLabel = '';
                          Color statusColor = Colors.grey;

                          if (settings != null) {
                            if (isCheckIn) {
                              DateTime startTime = DateTime(
                                  dt.year,
                                  dt.month,
                                  dt.day,
                                  settings['start_hour']!,
                                  settings['start_minute']!);

                              // Check strict equality or after
                              if (dt.isAfter(startTime)) {
                                statusLabel = 'Late Check In';
                                statusColor = Colors.orange;
                              } else {
                                statusLabel = 'On Time';
                                statusColor = Colors.green;
                              }
                            } else {
                              // Check Out Logic
                              DateTime endTime = DateTime(
                                  dt.year,
                                  dt.month,
                                  dt.day,
                                  settings['end_hour']!,
                                  settings['end_minute']!);
                              if (dt.isAfter(endTime)) {
                                statusLabel = 'Late Check Out (Overtime)';
                                statusColor = Colors.blue;
                              } else if (dt.isBefore(endTime)) {
                                statusLabel = 'Early Leave';
                                statusColor = Colors.red;
                              } else {
                                statusLabel = 'On Time';
                                statusColor = Colors.green;
                              }
                            }
                          }

                          return ListTile(
                            leading: Icon(
                              isCheckIn ? Icons.login : Icons.logout,
                              color: isCheckIn ? Colors.green : Colors.red,
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${isCheckIn ? "Check In" : "Check Out"} at $time'),
                                if (statusLabel.isNotEmpty)
                                  Text(statusLabel,
                                      style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                              ],
                            ),
                            trailing: Text(time,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }),
    );
  }
}
