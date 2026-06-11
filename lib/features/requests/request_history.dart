import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/current_user_provider.dart';
import '../../repositories/leave_repository.dart';
import '../../repositories/overtime_repository.dart';
import '../../utils/empty_state_widget.dart';

/// Shows employee's own leave & overtime requests with their status.
class RequestHistoryPage extends StatefulWidget {
  const RequestHistoryPage({super.key});

  @override
  State<RequestHistoryPage> createState() => _RequestHistoryPageState();
}

class _RequestHistoryPageState extends State<RequestHistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final LeaveRepository _leaveRepository = LeaveRepository();
  final OvertimeRepository _overtimeRepository = OvertimeRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<CurrentUserProvider>().uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Leave / Permission'),
            Tab(text: 'Overtime'),
          ],
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Not logged in'))
          : TabBarView(
              controller: _tabController,
              children: [
                _LeaveHistoryTab(uid: uid, repository: _leaveRepository),
                _OvertimeHistoryTab(uid: uid, repository: _overtimeRepository),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Leave History Tab
// ─────────────────────────────────────────────────────────────────────────

class _LeaveHistoryTab extends StatelessWidget {
  const _LeaveHistoryTab({
    required this.uid,
    required this.repository,
  });

  final String uid;
  final LeaveRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: repository.getUserLeaves(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.beach_access,
            title: 'No Leave Requests Yet',
            subtitle: 'Tap the + button on the Schedule page to submit your first request.',
          );
        }

        final docs = List<DocumentSnapshot>.from(snapshot.data!.docs)
          ..sort((a, b) {
            final aTime = (a.data() as Map)['timestamp'];
            final bTime = (b.data() as Map)['timestamp'];
            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }
            return 0;
          });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _RequestCard(
              title: data['type'] ?? 'Leave',
              subtitle: 'Date: ${data['date'] ?? '-'}',
              body: data['reason'] ?? '',
              status: data['status'] ?? 'Pending',
              icon: Icons.beach_access,
              iconColor: Colors.blue,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Overtime History Tab
// ─────────────────────────────────────────────────────────────────────────

class _OvertimeHistoryTab extends StatelessWidget {
  const _OvertimeHistoryTab({
    required this.uid,
    required this.repository,
  });

  final String uid;
  final OvertimeRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: repository.getUserOvertimeStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.schedule,
            title: 'No Overtime Requests Yet',
            subtitle: 'Tap the + button on the Schedule page to submit an overtime request.',
          );
        }

        final docs = List<DocumentSnapshot>.from(snapshot.data!.docs)
          ..sort((a, b) {
            final aTime = (a.data() as Map)['created_at'];
            final bTime = (b.data() as Map)['created_at'];
            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }
            return 0;
          });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final duration = (data['duration_hours'] ?? 0).toDouble();
            return _RequestCard(
              title: 'Overtime — ${duration.toStringAsFixed(1)} hours',
              subtitle: 'Date: ${data['date'] ?? '-'}',
              body: data['notes'] ?? '',
              status: data['status'] ?? 'Pending',
              icon: Icons.schedule,
              iconColor: Colors.orange,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Reusable Request Card
// ─────────────────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.status,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String subtitle;
  final String body;
  final String status;
  final IconData icon;
  final Color iconColor;

  Color _statusColor() {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon() {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withValues(alpha: 0.15),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Icon(_statusIcon(), color: statusColor, size: 28),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
