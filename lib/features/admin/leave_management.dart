import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../repositories/leave_repository.dart';
import '../../repositories/overtime_repository.dart';

class AdminMailBoxPage extends StatefulWidget {
  const AdminMailBoxPage({super.key});

  @override
  State<AdminMailBoxPage> createState() => _AdminMailBoxPageState();
}

class _AdminMailBoxPageState extends State<AdminMailBoxPage> {
  final LeaveRepository _leaveRepository = LeaveRepository();
  final OvertimeRepository _overtimeRepository = OvertimeRepository();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Mail (Requests)"),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Leave / Izin'),
              Tab(text: 'Overtime'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLeaveTab(),
            _buildOvertimeTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _leaveRepository.getPendingLeaves(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText("Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red)),
          ));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No pending leave requests."));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            String name = data['name'] ?? 'Unknown';
            String type = data['type'] ?? '?';
            String date = data['date'] ?? '';
            String reason = data['reason'] ?? '';
            String uid = data['uid'];

            return Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(type,
                              style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("Date: $date"),
                    Text("Reason: $reason"),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text("Reject",
                              style: TextStyle(color: Colors.red)),
                          onPressed: () async {
                            await _leaveRepository.updateRequestStatus(
                                doc.id, 'Rejected', uid, type);
                          },
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text("Approve",
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          onPressed: () async {
                            await _leaveRepository.updateRequestStatus(
                                doc.id, 'Approved', uid, type);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOvertimeTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _overtimeRepository.getPendingOvertime(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText("Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red)),
          ));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No pending overtime requests."));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            String name = data['name'] ?? 'Unknown';
            String date = data['date'] ?? '';
            String uid = data['uid'];
            double duration = (data['duration_hours'] ?? 0).toDouble();
            String notes = data['notes'] ?? '';
            String type = 'Lembur';

            return Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(type,
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("Date: $date"),
                    Text("Duration: ${duration.toStringAsFixed(1)} hours"),
                    Text("Notes: $notes"),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text("Reject",
                              style: TextStyle(color: Colors.red)),
                          onPressed: () async {
                            await _overtimeRepository.updateStatus(
                                doc.id, 'Rejected', uid);
                          },
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text("Approve",
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          onPressed: () async {
                            await _overtimeRepository.updateStatus(
                                doc.id, 'Approved', uid);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
