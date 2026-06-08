import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/current_user_provider.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/shift_repository.dart';
import '../../utils/stats_helper.dart';
import '../notifications/notification.dart';
import '../profile/profile.dart';
import '../schedule/schedule.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AttendanceRepository _attendanceRepository = AttendanceRepository();
  final SettingsRepository _settingsRepository = SettingsRepository();
  final ShiftRepository _shiftRepository = ShiftRepository();

  int _selectedIndex = 0; // ✅ Fixed: track selected nav bar index

  void _onNavTap(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SchedulePage()),
        ).then((_) {
          if (!mounted) return;
          setState(() => _selectedIndex = 0);
        });
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        ).then((_) {
          if (!mounted) return;
          setState(() => _selectedIndex = 0);
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<CurrentUserProvider>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String uid = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xffFFD95A),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex, // ✅ Fixed: highlights active tab
        onTap: _onNavTap,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black45,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      appBar: AppBar(
        // title: const Text('Home'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xffFFD95A),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _attendanceRepository.getUserAttendanceStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          List<QueryDocumentSnapshot> allDocs = snapshot.data?.docs ?? [];

          // Sort descending by timestamp
          allDocs.sort((a, b) {
            Timestamp tA = a['timestamp'];
            Timestamp tB = b['timestamp'];
            return tB.compareTo(tA);
          });

          // Filter today's records
          String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
          List<QueryDocumentSnapshot> todayDocs =
              allDocs.where((doc) => doc['date'] == todayDate).toList();

          List<QueryDocumentSnapshot> ins =
              todayDocs.where((d) => d['type'] == 'in').toList();
          List<QueryDocumentSnapshot> outs =
              todayDocs.where((d) => d['type'] == 'out').toList();

          String? checkInTime;
          String? checkOutTime;
          DateTime? checkInTimestamp;

          if (ins.isNotEmpty) {
            Timestamp ts = ins.last['timestamp'];
            checkInTimestamp = ts.toDate();
            checkInTime = DateFormat('hh:mm a').format(checkInTimestamp);
          }

          if (outs.isNotEmpty) {
            Timestamp ts = outs.first['timestamp'];
            checkOutTime = DateFormat('hh:mm a').format(ts.toDate());
          }

          String lastType =
              todayDocs.isNotEmpty ? todayDocs.first['type'] : 'out';

          return Column(
            children: [
              _buildHeader(),
              _buildCheckInOutCard(
                checkInTime,
                checkOutTime,
                lastType == 'out',
                checkInDateTime: checkInTimestamp,
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: _buildRecentActivity(allDocs),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final currentUser = context.watch<CurrentUserProvider>();
    final photoUrl = currentUser.photoUrl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${currentUser.displayName} 👋', // ✅ Fixed: shows real name
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(DateTime.now()),
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                ).then((_) {
                  if (!mounted) return;
                  context.read<CurrentUserProvider>().refreshProfile();
                  setState(() => _selectedIndex = 0);
                }),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.black12,
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? const Icon(Icons.person, color: Colors.black54)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationPage(),
                  ),
                ),
                child: const Icon(
                  Icons.notifications,
                  size: 28,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInOutCard(
    String? checkInTime,
    String? checkOutTime,
    bool showCheckInButton, {
    DateTime? checkInDateTime,
  }) {
    final uid = context.read<CurrentUserProvider>().uid;
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return FutureBuilder<
        (
          Map<String, int>? settings,
          ShiftDefinition? shift,
        )>(
      future: () async {
        final settings = await _settingsRepository.getWorkSettings();
        final shift = (uid != null)
            ? await _shiftRepository.getEmployeeShift(uid, todayStr)
            : null;
        return (settings, shift);
      }(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final settings = snapshot.data!.$1;
        final shift = snapshot.data!.$2;

        DateTime now = DateTime.now();

        // Use shift start time if assigned, else global settings
        final int startHour = shift?.startHour ?? settings?['start_hour'] ?? 9;
        final int startMinute =
            shift?.startMinute ?? settings?['start_minute'] ?? 0;

        final DateTime startTime = DateTime(
          now.year,
          now.month,
          now.day,
          startHour,
          startMinute,
        );

        bool isNowLate = now.isAfter(startTime);

        bool wasLateCheckIn = false;
        if (checkInDateTime != null) {
          final threshold = DateTime(
            checkInDateTime.year,
            checkInDateTime.month,
            checkInDateTime.day,
            startHour,
            startMinute,
          );
          wasLateCheckIn = checkInDateTime.isAfter(threshold);
        }

        String checkInStatus = '';
        if (checkInTime != null) {
          checkInStatus = wasLateCheckIn ? 'Late' : 'Present';
        }

        // Shift pill label
        final shiftLabel = shift?.name;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              if (shiftLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: _shiftColor(shift!.id),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Shift: $shiftLabel  (${shift.formatTime()})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _buildCheckCard(
                      isNowLate && showCheckInButton
                          ? 'Late Check In'
                          : 'Check In',
                      checkInTime ?? '--:--',
                      checkInStatus,
                      wasLateCheckIn && !showCheckInButton
                          ? Colors.orange[100]
                          : (isNowLate && showCheckInButton
                              ? Colors.orange[100]
                              : Colors.green[100]),
                      showCheckInButton
                          ? (isNowLate ? 'Late Check In' : 'Check In')
                          : null,
                      () => _showAttendanceDialog('Check In'),
                      isLate: isNowLate && showCheckInButton,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCheckCard(
                      'Check Out',
                      checkOutTime ?? '--:--',
                      checkOutTime != null ? 'Completed' : '',
                      Colors.red[100],
                      !showCheckInButton ? 'Check Out' : null,
                      () => _showAttendanceDialog('Check Out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

  Future<bool> _isWithinCheckInWindow(ShiftDefinition? shift) async {
    final settings = await _settingsRepository.getWorkSettings();
    final int startHour = shift?.startHour ?? settings?['start_hour'] ?? 9;
    final int startMinute =
        shift?.startMinute ?? settings?['start_minute'] ?? 0;

    DateTime now = DateTime.now();
    DateTime startTime = DateTime(
      now.year,
      now.month,
      now.day,
      startHour,
      startMinute,
    );
    DateTime windowStart = startTime.subtract(const Duration(minutes: 30));
    return now.isAfter(windowStart) || now.isAtSameMomentAs(windowStart);
  }

  Future<void> _showAttendanceDialog(String type) async {
    if (type == 'Check In') {
      final uid = context.read<CurrentUserProvider>().uid;
      final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      ShiftDefinition? shift;
      if (uid != null) {
        shift = await _shiftRepository.getEmployeeShift(uid, todayStr);
      }
      final withinWindow = await _isWithinCheckInWindow(shift);
      if (!withinWindow) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check-in is only allowed 30 minutes before your shift start time.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final TextEditingController notesController = TextEditingController();
    if (!mounted) return;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(type),
            content: TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Add Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final notes = notesController.text.trim();
                  Navigator.of(dialogContext).pop();
                  try {
                    final uid = context.read<CurrentUserProvider>().uid;
                    if (uid == null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You are not logged in.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (type == 'Check In') {
                      await _attendanceRepository.checkIn(uid, notes: notes);
                    } else {
                      await _attendanceRepository.checkOut(uid, notes: notes);
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$type Successful!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );
    } finally {
      notesController.dispose();
    }
  }

  Widget _buildCheckCard(
    String title,
    String time,
    String status,
    Color? color,
    String? buttonText,
    VoidCallback? onPressed, {
    bool isLate = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                title.contains('Check In') ? Icons.login : Icons.logout,
                color: Colors.black54,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            time,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(status, style: const TextStyle(fontSize: 12)),
          if (buttonText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: title.contains('Check In')
                        ? Colors.green[200]
                        : Colors.red[200],
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(buttonText, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<QueryDocumentSnapshot> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history_outlined),
            SizedBox(width: 8),
            Text(
              'Recent Activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: docs.isEmpty
              ? const Center(child: Text('No activity yet.'))
              : ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> data =
                        docs[index].data() as Map<String, dynamic>;
                    bool isCheckIn = data['type'] == 'in';
                    String time = DateFormat(
                      'hh:mm a',
                    ).format((data['timestamp'] as Timestamp).toDate());
                    return _buildRecentActivityRow(
                      isCheckIn: isCheckIn,
                      time: time,
                      date: data['date'] ?? '',
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityRow({
    required bool isCheckIn,
    required String time,
    required String date,
  }) {
    final icon = isCheckIn ? Icons.arrow_forward : Icons.arrow_back;
    final iconColor = isCheckIn ? Colors.green : Colors.red;
    final title = isCheckIn ? 'Check In' : 'Check Out';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withAlpha((0.15 * 255).round()),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
