import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../repositories/leave_repository.dart';

class AllLeavesPage extends StatefulWidget {
  final String? filterStatus;
  const AllLeavesPage({super.key, this.filterStatus});

  @override
  State<AllLeavesPage> createState() => _AllLeavesPageState();
}

class _AllLeavesPageState extends State<AllLeavesPage> {
  final LeaveRepository _leaveRepository = LeaveRepository();

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.filterStatus != null ? "${widget.filterStatus} Leave / Permission" : "All Leave / Permission Requests")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _leaveRepository.getAllLeaves(),
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
            return const Center(child: Text("No leave requests found."));
          }

          var docs = snapshot.data!.docs.toList();

          if (widget.filterStatus != null) {
            docs = docs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return data['status'] == widget.filterStatus;
            }).toList();
          }

          if (docs.isEmpty) {
            return const Center(child: Text("No leave requests found."));
          }

          docs.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;
            Timestamp? timeA = dataA['updated_at'] as Timestamp? ?? dataA['timestamp'] as Timestamp?;
            Timestamp? timeB = dataB['updated_at'] as Timestamp? ?? dataB['timestamp'] as Timestamp?;
            if (timeA == null && timeB == null) return 0;
            if (timeA == null) return 1;
            if (timeB == null) return -1;
            return timeB.compareTo(timeA); // Descending order
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;

              String name = data['name'] ?? 'Unknown';
              String type = data['type'] ?? '?';
              String date = data['date'] ?? '';
              String reason = data['reason'] ?? '';
              String status = data['status'] ?? 'Pending';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text("Status: ", style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(status, style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (data['updated_at'] != null || data['timestamp'] != null)
                            Text(
                              "Updated: ${DateFormat('MMM d, yyyy HH:mm').format((data['updated_at'] as Timestamp? ?? data['timestamp'] as Timestamp).toDate())}",
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
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
      ),
    );
  }
}
