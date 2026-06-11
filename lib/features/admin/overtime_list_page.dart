import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../repositories/overtime_repository.dart';

/// Admin page to view overtime requests for the current month.
/// Pass [filterStatus] to show only a specific status (e.g. 'Approved'),
/// or null to show all.
class OvertimeListPage extends StatefulWidget {
  final String? filterStatus;

  const OvertimeListPage({super.key, this.filterStatus});

  @override
  State<OvertimeListPage> createState() => _OvertimeListPageState();
}

class _OvertimeListPageState extends State<OvertimeListPage> {
  final OvertimeRepository _repo = OvertimeRepository();

  Future<void> _updateStatus(String docId, String status, String uid) async {
    await _repo.updateStatus(docId, status, uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Overtime $status'),
        backgroundColor: status == 'Approved' ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filterStatus != null
            ? 'Approved Overtime'
            : 'All Overtime Requests'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _repo.getAllOvertime(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No overtime requests.'));
          }

          final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

          // Filter to current month and optional status
          final docs = snapshot.data!.docs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final date = d['date'] as String?;
            if (date == null || !date.startsWith(currentMonth)) return false;
            if (widget.filterStatus != null) {
              final status =
                  (d['status'] as String? ?? '').toLowerCase();
              if (status != widget.filterStatus!.toLowerCase()) return false;
            }
            return true;
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Text(
                widget.filterStatus != null
                    ? 'No approved overtime this month.'
                    : 'No overtime requests this month.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unknown';
              final date = data['date'] ?? '';
              final duration = (data['duration_hours'] ?? 0).toDouble();
              final notes = data['notes'] ?? '';
              final status = (data['status'] ?? 'Pending').toString();
              final compensation = data['compensation_type'] ?? '';
              final uid = data['uid'] ?? '';
              final attachmentUrl = data['attachment_url'] as String?;
              final isPending = status.toLowerCase() == 'pending';

              Color statusColor;
              switch (status.toLowerCase()) {
                case 'approved':
                  statusColor = Colors.green;
                  break;
                case 'rejected':
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor = Colors.orange;
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Name + Status badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Date: $date',
                          style: TextStyle(color: Colors.grey[700])),
                      Text('Duration: ${duration.toStringAsFixed(1)} hours',
                          style: TextStyle(color: Colors.grey[700])),
                      if (notes.isNotEmpty)
                        Text('Notes: $notes',
                            style: TextStyle(color: Colors.grey[700])),
                      if (compensation.isNotEmpty)
                        Text(
                          compensation == 'upah_lembur'
                              ? 'Compensation: Overtime Pay'
                              : 'Compensation: Replacement Off',
                          style: TextStyle(color: Colors.grey[700]),
                        ),

                      // ── Attachment link ──────────────────────────
                      if (attachmentUrl != null && attachmentUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: () => _showAttachment(context, attachmentUrl),
                            child: Row(
                              children: [
                                Icon(Icons.image, size: 18, color: Colors.blue[700]),
                                const SizedBox(width: 6),
                                Text(
                                  'View Attachment',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── Approve / Reject buttons ─────────────────
                      if (isPending)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.close, color: Colors.red),
                                label: const Text('Reject',
                                    style: TextStyle(color: Colors.red)),
                                onPressed: () =>
                                    _updateStatus(doc.id, 'Rejected', uid),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check, color: Colors.white),
                                label: const Text('Approve',
                                    style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
                                onPressed: () =>
                                    _updateStatus(doc.id, 'Approved', uid),
                              ),
                            ],
                          ),
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

  void _showAttachment(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            ClipRRect(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }
}
