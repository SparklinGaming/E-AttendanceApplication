import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/current_user_provider.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/shift_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../utils/stats_helper.dart';
import '../home/home.dart';
import '../schedule/schedule.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AttendanceRepository _attendanceRepository = AttendanceRepository();
  final SettingsRepository _settingsRepository = SettingsRepository();
  final UserRepository _userRepository = UserRepository();
  final ShiftRepository _shiftRepository = ShiftRepository();
  final StatsHelper _statsHelper = StatsHelper();
  final AuthService _authService = AuthService();
  bool _isUploading = false;

  List<QueryDocumentSnapshot> _sortedDocs(List<QueryDocumentSnapshot> docs) {
    // Sort by timestamp descending
    final sorted = List<QueryDocumentSnapshot>.from(docs);
    sorted.sort(
      (a, b) => (b['timestamp'] as Timestamp).compareTo(
        a['timestamp'] as Timestamp,
      ),
    );
    return sorted;
  }

  Future<void> _changeProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (contex) => AlertDialog(
        title: const Text('Change Profile Picture'),
        content: const Text('Choose an image source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (source == null) return;

    final XFile? pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (!mounted || pickedFile == null) return;
    setState(() => _isUploading = true);
    try {
      final File imageFile = File(pickedFile.path);
      final currentUserProvider = context.read<CurrentUserProvider>();
      final uid = currentUserProvider.uid;
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not logged in.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final String downloadUrl =
          await _userRepository.uploadProfilePicture(uid, imageFile);
      await _userRepository.updateUserProfile(
        uid,
        photoUrl: downloadUrl,
      );
      await currentUserProvider.refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<CurrentUserProvider>().user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String uid = user.uid;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Color(0xffFFD95A),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: 2,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black54,
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
                break;
              case 1:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SchedulePage()),
                );
                break;
              case 2:
                break; // Already on Profile
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'schedule',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'profile'),
          ],
        ),
        body: FutureBuilder<
            (
              Map<String, dynamic>? config,
              ShiftDefinition? shift,
            )>(
          future: () async {
            final config = await _settingsRepository.getFullWorkConfig();
            final String todayStr =
                DateFormat('yyyy-MM-dd').format(DateTime.now());
            final shift =
                await _shiftRepository.getEmployeeShift(uid, todayStr);
            return (config, shift);
          }(),
          builder: (context, settingsSnapshot) {
            if (settingsSnapshot.hasError) {
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
                        'Failed to load work configuration',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${settingsSnapshot.error}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!settingsSnapshot.hasData || settingsSnapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final config = settingsSnapshot.data!.$1;
            final shift = settingsSnapshot.data!.$2;
            final workSettings = config != null
                ? Map<String, int>.from({
                    for (final k in [
                      'start_hour',
                      'start_minute',
                      'end_hour',
                      'end_minute'
                    ])
                      if (config[k] != null) k: config[k] as int,
                  })
                : null;
            final List<int> workingDays =
                (config?['working_days'] as List<dynamic>?)?.cast<int>() ??
                    [1, 2, 3, 4, 5];
            final List<String> holidays =
                (config?['holidays'] as List<dynamic>?)?.cast<String>() ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: _attendanceRepository.getUserAttendanceStream(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                final sortedDocs = _sortedDocs(docs);
                final stats = _statsHelper.calculateStats(
                  docs,
                  workSettings: workSettings,
                  workingDays: workingDays,
                  holidays: holidays,
                  shift: shift,
                );
                final weeklyData = _statsHelper.calculateWeeklyDataDetailed(
                  docs,
                  workingDays: workingDays,
                  holidays: holidays,
                );
                final int present = stats['present'] ?? 0;
                final int late = stats['late'] ?? 0;
                final int absence = stats['absence'] ?? 0;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      _buildProfileHeader(uid),
                      const SizedBox(height: 30),

                      // Attendance Stats Box
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xffC07F00),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Absence', absence.toString()),
                            _buildVerticalDivider(),
                            _buildStatItem('Present', present.toString()),
                            _buildVerticalDivider(),
                            _buildStatItem('Late', late.toString()),
                          ],
                        ),
                      ),

                      // Leave Balance
                      _LeaveBalanceCard(uid: uid),

                      // Late Warning
                      if (late > 3)
                        Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.warning, color: Colors.red),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Warning: You have been late more than 3 times this month!',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Chart Section
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        height: 200,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            const Text("Weekly Work Hours",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Expanded(
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: 12,
                                  barTouchData: BarTouchData(enabled: false),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          return Text([
                                            "M",
                                            "T",
                                            "W",
                                            "T",
                                            "F",
                                            "S",
                                            "S"
                                          ][value.toInt() % 7]);
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    topTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    rightTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                  ),
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  barGroups: weeklyData
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) => BarChartGroupData(
                                          x: e.key,
                                          barRods: [
                                            BarChartRodData(
                                              toY: e.value.hours,
                                              color: e.value.isHoliday
                                                  ? Colors.red
                                                  : Colors.orange,
                                              width: 14,
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Recent Activity (last 10, current month)
                      _buildRecentActivity(sortedDocs),

                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _logout,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xfffff3cd),
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.red),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Log Out',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.red,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Helper: Profile Header
  Widget _buildProfileHeader(String uid) {
    return FutureBuilder<DocumentSnapshot>(
      future: _userRepository.getUserDocument(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError || (!snapshot.hasData && snapshot.connectionState != ConnectionState.waiting)) {
          return const Column(
            children: [
              SizedBox(height: 20),
              Icon(Icons.person, size: 80, color: Colors.grey),
              SizedBox(height: 8),
              Text('Failed to load profile',
                  style: TextStyle(color: Colors.grey)),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final String name = data?['name'] ?? 'User';
        final String role = data?['role'] ?? 'Employee';
        final String email = data?['email'] ?? '';
        final String? photoUrl = data?['photoUrl'] as String?;

        return Column(
          children: [
            // ✅ New: profile photo with camera edit button
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.orange[100],
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                      ? NetworkImage(photoUrl)
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.orange,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUploading ? null : _changeProfilePicture,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              role.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            Text(
              email,
              style: const TextStyle(fontSize: 14, color: Colors.black45),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.white30);
  }

  Widget _buildRecentActivity(List<QueryDocumentSnapshot> docs) {
    const int maxItems = 10;
    // Filter to current month only
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final monthDocs = docs
        .where((doc) {
          final date = doc['date'] as String?;
          return date != null && date.startsWith(currentMonth);
        })
        .toList();
    final limitedDocs =
        monthDocs.length > maxItems ? monthDocs.sublist(0, maxItems) : monthDocs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              const Icon(Icons.history_outlined, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (monthDocs.length > maxItems)
                Text(
                  'Last $maxItems',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (limitedDocs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'No activity this month.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...limitedDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final bool isCheckIn = data['type'] == 'in';
            final Timestamp timeStamp = data['timestamp'];
            final String date =
                DateFormat('dd MMM yyyy').format(timeStamp.toDate());
            final String time =
                DateFormat('HH:mm').format(timeStamp.toDate());

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: (isCheckIn ? Colors.green : Colors.red)
                      .withAlpha((0.15 * 255).round()),
                  child: Icon(
                    isCheckIn ? Icons.login : Icons.logout,
                    size: 16,
                    color: isCheckIn ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(isCheckIn ? 'Check In' : 'Check Out',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(date, style: const TextStyle(fontSize: 12)),
                trailing: Text(
                  time,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Displays remaining leave balance for the current employee.
class _LeaveBalanceCard extends StatelessWidget {
  const _LeaveBalanceCard({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: UserRepository().getLeaveBalance(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final balance = snapshot.data!;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.beach_access, color: Colors.teal, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Leave Balance',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _balanceChip(
                    Icons.event,
                    'Annual',
                    '${balance['annual'] ?? 0} days',
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _balanceChip(
                    Icons.star_border,
                    'Special Leave',
                    '${balance['special'] ?? 0} used',
                    Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  _balanceChip(
                    Icons.medical_services,
                    'Sick',
                    '${balance['sick'] ?? 0} used',
                    Colors.red,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _balanceChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
