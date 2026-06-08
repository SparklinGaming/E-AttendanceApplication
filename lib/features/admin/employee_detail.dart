import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/user_repository.dart';
import '../../utils/stats_helper.dart';

class EmployeeDetailPage extends StatelessWidget {
  final String uid;

  const EmployeeDetailPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final AttendanceRepository attendanceRepository = AttendanceRepository();
    final StatsHelper statsHelper = StatsHelper();
    final UserRepository userRepository = UserRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Employee Details')),
      body: StreamBuilder<QuerySnapshot>(
        stream: attendanceRepository.getUserAttendanceStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          // sort once (desc) instead of sorting on every ListView build
          docs.sort((a, b) => (b['timestamp'] as Timestamp)
              .compareTo(a['timestamp'] as Timestamp));
          final stats = statsHelper.calculateStats(docs);
          final weeklyData = statsHelper.calculateWeeklyData(docs);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                FutureBuilder<DocumentSnapshot>(
                  future: userRepository.getUserDocument(uid),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) return const SizedBox();
                    var userData =
                        userSnap.data!.data() as Map<String, dynamic>;
                    return Column(
                      children: [
                        CircleAvatar(
                            radius: 40, child: Text(userData['name'][0])),
                        const SizedBox(height: 10),
                        Text(userData['name'],
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(userData['email'],
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),
                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard('Present', stats['present'].toString(),
                        Colors.green[100]!),
                    _buildStatCard(
                        'Late', stats['late'].toString(), Colors.orange[100]!),
                    _buildStatCard('Absence', stats['absence'].toString(),
                        Colors.red[100]!),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Weekly Activity (Hours)",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),

                // Reuse Chart Logic
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 12,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(show: false),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: weeklyData.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                                toY: e.value, color: Colors.blue, width: 14)
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Attendance History",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),

                // List History
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isCheckIn = data['type'] == 'in';
                    String time = DateFormat('hh:mm a')
                        .format((data['timestamp'] as Timestamp).toDate());

                    return ListTile(
                      leading: Icon(isCheckIn ? Icons.login : Icons.logout,
                          color: isCheckIn ? Colors.green : Colors.red),
                      title: Text(data['date']),
                      subtitle: Text(isCheckIn ? "Check In" : "Check Out"),
                      trailing: Text(time),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label),
        ],
      ),
    );
  }
}
