import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/analytics_service.dart';
import 'employee_list.dart';
import 'attendance_list_page.dart';
import 'admin_shift_assignment.dart';
import 'admin_shift_settings.dart';
import 'all_leaves_page.dart';
import 'leave_management.dart';
import 'overtime_list_page.dart';

class AnalyticsDashboard extends StatefulWidget {
  final Widget? bottomWidget;
  
  const AnalyticsDashboard({super.key, this.bottomWidget});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  final AnalyticsService _analyticsService = AnalyticsService();
  late Future<Map<String, dynamic>> _dashboardDataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _dashboardDataFuture = _analyticsService.getDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _loadData();
        await _dashboardDataFuture;
      },
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 100),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('Error loading dashboard: ${snapshot.error}'),
                  ),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return ListView(
              children: const [
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('No data available.'),
                  ),
                ),
              ],
            );
          }

          final data = snapshot.data!;
          final attendance = data['attendance'];
          final leave = data['leave'];
          final overtime = data['overtime'];
          final shift = data['shift'];
          final forecast = data['forecast'];

          return ListView(
            padding: const EdgeInsets.all(16.0),
            physics: const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator
            children: [
              _buildSectionTitle('Attendance Overview'),
              _buildAttendanceSummary(attendance),
              const SizedBox(height: 16),
              _buildChartContainer(
                title: 'Past 7 Days Attendance',
                child: _buildAttendanceTrendChart(forecast['past7Days']),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Leave & Permission'),
              _buildLeaveSummary(leave),
              const SizedBox(height: 16),
              _buildChartContainer(
                title: 'Leave Request Status',
                child: _buildLeavePieChart(leave),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Overtime Records'),
              _buildOvertimeSummary(overtime),
              const SizedBox(height: 24),
              _buildSectionTitle('Shift Management'),
              _buildShiftSummary(shift),
              const SizedBox(height: 16),
              _buildChartContainer(
                title: 'Employees per Shift',
                child: _buildShiftPieChart(shift['employeesPerShift']),
              ),
              const SizedBox(height: 24),
              if (widget.bottomWidget != null) widget.bottomWidget!,
              const SizedBox(height: 40), // Bottom padding
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildChartContainer({required String title, required Widget child, VoidCallback? onTap}) {
    final containerContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: child),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: containerContent,
        ),
      );
    }
    
    return containerContent;
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon, {VoidCallback? onTap, double? valueFontSize}) {
    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: valueFontSize ?? 24,
                      fontWeight: FontWeight.bold,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }

  Widget _buildAttendanceSummary(Map<String, dynamic> data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Employees',
                '${data['totalEmployees']}',
                Colors.blue,
                Icons.people,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmployeeListPage()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Present Today',
                '${data['presentToday']}',
                Colors.green,
                Icons.check_circle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendanceListPage(
                      title: 'Present Today',
                      users: List<Map<String, dynamic>>.from(data['presentUsers'] ?? []),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Absent Today',
                '${data['absentToday']}',
                Colors.red,
                Icons.cancel,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendanceListPage(
                      title: 'Absent Today',
                      users: List<Map<String, dynamic>>.from(data['absentUsers'] ?? []),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Late',
                '${data['lateCount']}',
                Colors.orange,
                Icons.watch_later,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendanceListPage(
                      title: 'Late Employees',
                      users: List<Map<String, dynamic>>.from(data['lateUsers'] ?? []),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaveSummary(Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total', 
            '${data['totalRequests']}', 
            Colors.purple, 
            Icons.receipt_long,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllLeavesPage()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Approved', 
            '${data['approved']}', 
            Colors.teal, 
            Icons.done_all,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllLeavesPage(filterStatus: 'Approved')),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Pending', 
            '${data['pending']}', 
            Colors.amber, 
            Icons.hourglass_empty,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllLeavesPage(filterStatus: 'Pending')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOvertimeSummary(Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard('Submissions', '${data['totalSubmissions']}', Colors.indigo, Icons.post_add,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OvertimeListPage()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard('Approved', '${data['approved']}', Colors.lightBlue, Icons.thumb_up,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OvertimeListPage(filterStatus: 'Approved')),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard('Total Hrs', '${data['totalHours']}h', Colors.cyan, Icons.access_time_filled),
        ),
      ],
    );
  }

  Widget _buildShiftSummary(Map<String, dynamic> data) {
    int scheduled = data['totalScheduled'] ?? 0;
    int unassigned = data['withoutShift'] ?? 0;
    int total = scheduled + unassigned;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Scheduled', 
            '$scheduled/$total', 
            Colors.brown, 
            Icons.assignment,
            valueFontSize: 16,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminShiftAssignmentPage()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Manage', 
            'Shift Setup', 
            Colors.teal, 
            Icons.schedule,
            valueFontSize: 16,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminShiftSettingsPage()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTrendChart(List<int> past7Days) {
    if (past7Days.isEmpty) return const Center(child: Text('No data'));
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < past7Days.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: past7Days[i].toDouble(),
              color: Colors.blueAccent,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (past7Days.reduce((a, b) => a > b ? a : b) + 5).toDouble(),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('D-${6 - value.toInt()}', style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildLeavePieChart(Map<String, dynamic> data) {
    int total = data['totalRequests'];
    if (total == 0) return const Center(child: Text('No leave data'));
    
    int approved = data['approved'];
    int pending = data['pending'];
    int rejected = total - approved - pending;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                  color: Colors.teal,
                  value: approved.toDouble(),
                  title: '$approved',
                  radius: 50,
                  titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                PieChartSectionData(
                  color: Colors.amber,
                  value: pending.toDouble(),
                  title: '$pending',
                  radius: 50,
                  titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                if (rejected > 0)
                  PieChartSectionData(
                    color: Colors.redAccent,
                    value: rejected.toDouble(),
                    title: '$rejected',
                    radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem(Colors.teal, 'Approved'),
              const SizedBox(height: 8),
              _buildLegendItem(Colors.amber, 'Pending'),
              if (rejected > 0) ...[
                const SizedBox(height: 8),
                _buildLegendItem(Colors.redAccent, 'Rejected'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildShiftPieChart(Map<String, int> employeesPerShift) {
    if (employeesPerShift.isEmpty || employeesPerShift.values.every((v) => v == 0)) {
      return const Center(child: Text('No shift data for today'));
    }

    final colors = [Colors.brown, Colors.orange, Colors.indigo, Colors.teal, Colors.purple];
    int colorIdx = 0;
    
    List<PieChartSectionData> sections = [];
    employeesPerShift.forEach((key, value) {
      if (value > 0) {
        sections.add(
          PieChartSectionData(
            color: colors[colorIdx % colors.length],
            value: value.toDouble(),
            title: '$value\n$key',
            radius: 60,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        );
        colorIdx++;
      }
    });

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: sections,
      ),
    );
  }
}
