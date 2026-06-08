import 'package:flutter/material.dart';

class AttendanceListPage extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> users;

  const AttendanceListPage({super.key, required this.title, required this.users});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFFFFD95A),
      ),
      body: users.isEmpty
          ? Center(
              child: Text(
                'No employees found',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final name = user['name'] ?? 'Unknown';
                final initial = name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : 'U';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Text(
                        initial,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: user.containsKey('time') ? Text('Check-in: ${user['time']}') : null,
                  ),
                );
              },
            ),
    );
  }
}
