import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/auth_service.dart';
import '../../services/csv_export_service.dart';
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
  final CsvExportService _csvExportService = CsvExportService();

  void _showExportMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Export Data',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Choose what to export as CSV',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),
              _exportOption(
                icon: Icons.today,
                label: 'Daily Attendance',
                subtitle: 'Today\'s check-in/out recap',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(ctx);
                  _exportDaily();
                },
              ),
              const SizedBox(height: 8),
              _exportOption(
                icon: Icons.calendar_month,
                label: 'Monthly Attendance',
                subtitle: 'Per-employee summary this month',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(ctx);
                  _exportMonthly();
                },
              ),
              const SizedBox(height: 8),
              _exportOption(
                icon: Icons.receipt_long,
                label: 'Leave / Permission Data',
                subtitle: 'All leave requests',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(ctx);
                  _exportLeaves();
                },
              ),
              const SizedBox(height: 8),
              _exportOption(
                icon: Icons.assessment,
                label: 'Full Company Report',
                subtitle: 'Complete matrix with daily status per employee',
                color: Colors.teal,
                onTap: () {
                  Navigator.pop(ctx);
                  _exportFullReport();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.file_download, color: Colors.black54),
        onTap: onTap,
      ),
    );
  }

  Future<void> _exportDaily() async {
    await _handleExport(
      label: 'Daily Attendance',
      exportFn: () => _csvExportService.exportDailyAttendance(),
    );
  }

  Future<void> _exportMonthly() async {
    await _handleExport(
      label: 'Monthly Attendance',
      exportFn: () => _csvExportService.exportMonthlyAttendance(),
    );
  }

  Future<void> _exportLeaves() async {
    await _handleExport(
      label: 'Leave / Permission Data',
      exportFn: () => _csvExportService.exportLeaves(),
    );
  }

  Future<void> _exportFullReport() async {
    await _handleExport(
      label: 'Full Company Report',
      exportFn: () => _csvExportService.exportFullReport(),
    );
  }

  /// Shared export handler: shows loading, processes export, shows result.
  Future<void> _handleExport({
    required String label,
    required Future<CsvExportResult> Function() exportFn,
  }) async {
    // Show loading snackbar
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Exporting $label...'),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      final result = await exportFn();

      if (!mounted) return;

      // Dismiss the loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result.success) {
        _showExportSuccessDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${result.error ?? "Unknown error"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show a success dialog after export with Open / Share / Close options.
  void _showExportSuccessDialog(CsvExportResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Export Successful')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.fileName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            // File path
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.filePath,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The file has been saved. You can share or open it using the buttons below.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles(
                [XFile(result.filePath)],
                text: result.fileName,
              );
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open File'),
            onPressed: () async {
              Navigator.pop(ctx);
              final openResult = await OpenFilex.open(result.filePath);
              if (openResult.type != ResultType.done && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not open file: ${openResult.message}',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFFFFD95A),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: _showExportMenu,
          ),
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
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AttendanceRecordsPage())),
            ),
            _buildActionCard(
              context,
              icon: Icons.receipt_long,
              label: 'Requests',
              color: Colors.purple,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminMailBoxPage())),
            ),
            _buildActionCard(
              context,
              icon: Icons.settings,
              label: 'Settings',
              color: Colors.blueGrey,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminSettingsPage())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
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
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}
