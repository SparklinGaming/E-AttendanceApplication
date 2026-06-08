import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'employee_list.dart';
import 'attendance_records.dart';
import 'admin_settings.dart';
import 'leave_management.dart';
import 'analytics_dashboard.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFFFFD95A),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              // Root auth listener handles navigation.
            },
          ),
        ],
      ),
      body: AnalyticsDashboard(
        bottomWidget: _buildQuickActions(context),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildActionCard(
              context,
              icon: Icons.history,
              label: 'Attendance',
              color: Colors.green,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceRecordsPage())),
            ),
            _buildActionCard(
              context,
              icon: Icons.receipt_long,
              label: 'Requests',
              color: Colors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminMailBoxPage())),
            ),
            _buildActionCard(
              context,
              icon: Icons.settings,
              label: 'Settings',
              color: Colors.blueGrey,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsPage())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}
