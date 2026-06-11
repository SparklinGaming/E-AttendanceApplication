import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/current_user_provider.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/shift_repository.dart';
import '../home/home.dart';
import '../profile/profile.dart';
import '../requests/request_form.dart';
import '../requests/overtime_request.dart';
import '../requests/request_history.dart';
import '../requests/issue_report.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final SettingsRepository _settingsRepository = SettingsRepository();
  final ShiftRepository _shiftRepository = ShiftRepository();

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<CurrentUserProvider>().uid;
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xffFFD95A),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
                break;
              case 1:
                // Already on Schedule
                break;
              case 2:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              backgroundColor: Color.fromARGB(0, 0, 0, 0),
              label: 'home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'schedule',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'profile'),
          ],
          selectedItemColor: Colors.black,
        ),
        appBar: AppBar(title: const Text('Schedule'), centerTitle: true),
        body: FutureBuilder<
            (
              ShiftDefinition? shift,
              Map<String, int>? settings,
            )>(
          future: () async {
            final shift = uid != null
                ? await _shiftRepository.getEmployeeShift(uid, todayStr)
                : null;
            final settings = await _settingsRepository.getWorkSettings();
            return (shift, settings);
          }(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load schedule',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final shift = snapshot.data!.$1;
            final settings = snapshot.data!.$2;
            final hasDefaultSchedule = settings != null;

            // ── Show assigned shift (if any) ────────────────────
            if (shift != null) {
              final dayName = DateFormat('EEEE').format(DateTime.now());
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time_filled,
                        size: 64, color: Colors.orange),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: _shiftColor(shift.id),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        shift.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      shift.formatTime(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Today: $dayName',
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              );
            }

            // ── No assigned shift → show default schedule ──────
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time_filled,
                      size: 64, color: Colors.orange),
                  const SizedBox(height: 20),
                  Text(
                    hasDefaultSchedule
                        ? 'Default Schedule'
                        : 'No Schedule Configured',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (hasDefaultSchedule)
                    Text(
                      'Mon - Fri\n${_formatWorkTime(context, settings, 'start')} - ${_formatWorkTime(context, settings, 'end')}',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black54),
                    )
                  else
                    const Text(
                      'Ask an admin to set work timing first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Choose Request Type',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        leading:
                            const Icon(Icons.beach_access, color: Colors.blue),
                        title: const Text('Leave / Permission'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const RequestFormPage()),
                          );
                        },
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.schedule, color: Colors.orange),
                        title: const Text('Overtime Request'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const OvertimeRequestPage()),
                          );
                        },
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.error_outline, color: Colors.red),
                        title: const Text('Report Issue'),
                        subtitle: const Text('For store-related concerns'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const IssueReportPage()),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.history, color: Colors.grey),
                        title: const Text('My Requests History'),
                        subtitle: const Text('View status of your requests'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const RequestHistoryPage()),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
          label: const Text("Request"),
          icon: const Icon(Icons.add),
          backgroundColor: Colors.blue,
        ),
      ),
    );
  }

  String _formatWorkTime(
    BuildContext context,
    Map<String, int> settings,
    String prefix,
  ) {
    final time = TimeOfDay(
      hour: settings['${prefix}_hour'] ?? 0,
      minute: settings['${prefix}_minute'] ?? 0,
    );
    return time.format(context);
  }

  Color _shiftColor(String id) {
    switch (id) {
      case 'morning':
        return const Color(0xFF4CAF50);
      case 'afternoon':
        return const Color(0xFFFF9800);
      case 'night':
        return const Color(0xFF2196F3);
      default:
        return Colors.teal;
    }
  }
}
