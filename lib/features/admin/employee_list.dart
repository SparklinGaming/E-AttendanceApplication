import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../repositories/user_repository.dart';
import 'employee_detail.dart';
import 'add_employee.dart';

class EmployeeListPage extends StatelessWidget {
  const EmployeeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final UserRepository userRepository = UserRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Employee List')),
      body: StreamBuilder<QuerySnapshot>(
        stream: userRepository.getEmployees(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No employees found.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String docId = snapshot.data!.docs[index].id;

              return Dismissible(
                key: Key(docId),
                background: Container(
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white)),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Confirm Delete"),
                      content: const Text(
                          "Are you sure you want to delete this employee?"),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text("Cancel")),
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text("Delete",
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  userRepository.deleteEmployee(docId);
                },
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(data['name'] ?? 'No Name'),
                  subtitle: Text(data['email'] ?? 'No Email'),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                EmployeeDetailPage(uid: docId)));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const AddEmployeePage()));
        },
      ),
    );
  }
}
