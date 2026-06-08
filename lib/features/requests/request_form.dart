import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/current_user_provider.dart';
import '../../repositories/leave_repository.dart';

class RequestFormPage extends StatefulWidget {
  const RequestFormPage({super.key});

  @override
  State<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends State<RequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final LeaveRepository _leaveRepository = LeaveRepository();

  String _selectedType = 'Annual Leave'; // Annual Leave
  final List<String> _types = [
    'Annual Leave',
    'Emergency Leave',
    'Medical Certificate'
  ];

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _dateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Submit Request")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Request Type",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  setState(() => _selectedType = val!);
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text("Date", style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: () => _selectDate(context),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Reason",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), hintText: "Enter reason..."),
                validator: (val) =>
                    val == null || val.isEmpty ? "Please enter a reason" : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!(_formKey.currentState?.validate() ?? false)) {
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final uid = context.read<CurrentUserProvider>().uid;
                    if (uid == null) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                          const SnackBar(content: Text("Not logged in.")));
                      return;
                    }
                    try {
                      await _leaveRepository.submitRequest(uid, _selectedType,
                          _dateController.text, _reasonController.text);
                      if (!mounted) return;
                      messenger.showSnackBar(
                          const SnackBar(content: Text("Request Submitted!")));
                      navigator.pop();
                    } catch (e) {
                      if (!mounted) return;
                      messenger
                          .showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text("Submit",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
