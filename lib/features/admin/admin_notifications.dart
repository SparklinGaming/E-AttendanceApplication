import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../repositories/notification_repository.dart';
import 'package:intl/intl.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    _titleController.clear();
    _messageController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Create Notification"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title")),
            TextField(
                controller: _messageController,
                decoration: const InputDecoration(labelText: "Message"),
                maxLines: 3),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (_titleController.text.isNotEmpty &&
                  _messageController.text.isNotEmpty) {
                await _notificationRepository.addNotification(
                    _titleController.text, _messageController.text);
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Notification Sent!")));
              }
            },
            child: const Text("Send"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Notifications")),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationRepository.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              Timestamp? ts = data['created_at'];
              String date = ts != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate())
                  : 'Just now';

              return Card(
                child: ListTile(
                  title: Text(data['title'] ?? 'No Title'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['message'] ?? ''),
                      const SizedBox(height: 5),
                      Text(date,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () =>
                        _notificationRepository.deleteNotification(doc.id),
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
