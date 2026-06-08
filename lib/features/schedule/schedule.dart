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

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final SettingsRepository _settingsRepository = SettingsRepository();
  final ShiftRepository _shiftRepository = ShiftRepository();
  late final Future<Map<String, int>?> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _settingsRepository.getWorkSettings();
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
        body: FutureBuilder<Map<String, int>?>(
          future: _settingsFuture,
          builder: (context, settingsSnapshot) {
            if (settingsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final settings = settingsSnapshot.data;
            final hasSchedule = settings != null;

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time_filled,
                      size: 64, color: Colors.orange),
                  const SizedBox(height: 20),

                  // ── Assigned shift for today (new) ──────────────
                  if (uid != null)
                    FutureBuilder<ShiftDefinition?>(
                      future: _shiftRepository.getEmployeeShift(uid, todayStr),
                      builder: (context, shiftSnap) {
                        final shift = shiftSnap.data;
                        if (shift != null) {
                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _shiftColor(shift.id),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  shift.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                shift.formatTime(),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 20),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                  // ── Default schedule info ──────────────────────
                  Text(
                    hasSchedule ? 'Default Schedule' : 'No Shift Configured',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hasSchedule
                        ? 'Mon - Fri\n${_formatWorkTime(context, settings, 'start')} - ${_formatWorkTime(context, settings, 'end')}'
                        : 'Ask an admin to set work timing first.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
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
                        'Pilih Jenis Pengajuan',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: const Icon(Icons.beach_access, color: Colors.blue),
                        title: const Text('Cuti / Izin (Leave)'),
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
                        leading: const Icon(Icons.schedule, color: Colors.orange),
                        title: const Text('Pengajuan Lembur'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const OvertimeRequestPage()),
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
