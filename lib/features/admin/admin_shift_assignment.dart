import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/shift_repository.dart';
import '../../repositories/user_repository.dart';

/// Admin page to assign employees to shifts on a daily basis.
class AdminShiftAssignmentPage extends StatefulWidget {
  const AdminShiftAssignmentPage({super.key});

  @override
  State<AdminShiftAssignmentPage> createState() =>
      _AdminShiftAssignmentPageState();
}

class _AdminShiftAssignmentPageState extends State<AdminShiftAssignmentPage> {
  final ShiftRepository _shiftRepo = ShiftRepository();
  final UserRepository _userRepo = UserRepository();

  DateTime _selectedDate = DateTime.now();
  List<ShiftDefinition> _shifts = [];
  Map<String, String> _assignments = {}; // uid → shiftId
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _shifts = await _shiftRepo.getShiftDefinitions();
    await _loadAssignments();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);

    // Fetch employees
    final usersSnap = await _userRepo.getEmployees().first;
    final emps = usersSnap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return {
        'uid': d.id,
        'name': data['name'] ?? 'Unknown',
        'email': data['email'] ?? '',
      };
    }).toList();

    // Fetch existing assignments for the date
    final existing = await _shiftRepo.getDailyAssignments(_dateStr);

    if (!mounted) return;
    setState(() {
      _employees = emps;
      _assignments = Map.from(existing);
      _isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null && picked != _selectedDate) {
      _selectedDate = picked;
      await _loadAssignments();
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await _shiftRepo.setDailyAssignments(_dateStr, _assignments);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Assignments saved for ${DateFormat('dd MMM yyyy').format(_selectedDate)}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Copy assignments from the previous day.
  Future<void> _copyFromYesterday() async {
    final yesterday = _selectedDate.subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
    final prevAssignments = await _shiftRepo.getDailyAssignments(yesterdayStr);
    if (prevAssignments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No assignments found for yesterday.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    setState(() {
      _assignments = Map.from(prevAssignments);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateDisplay = DateFormat('EEEE, dd MMM yyyy').format(_selectedDate);
    final bool isToday =
        _dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Shift Assignment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Date selector ───────────────────────────────────
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          _selectedDate =
                              _selectedDate.subtract(const Duration(days: 1));
                          _loadAssignments();
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickDate,
                          child: Text(
                            dateDisplay,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isToday ? Colors.blue : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          _selectedDate =
                              _selectedDate.add(const Duration(days: 1));
                          _loadAssignments();
                        },
                      ),
                    ],
                  ),
                ),

                // ── Quick actions ──────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy from yesterday'),
                        onPressed: _copyFromYesterday,
                      ),
                      const Spacer(),
                      Text(
                        '${_employees.length} employees',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                // ── Employee list ──────────────────────────────────
                Expanded(
                  child: _employees.isEmpty
                      ? const Center(child: Text('No employees found.'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _employees.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final emp = _employees[index];
                            final uid = emp['uid'] as String;
                            final name = emp['name'] as String;
                            final assignedShiftId = _assignments[uid];

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              leading: CircleAvatar(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                ),
                              ),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                emp['email'] as String,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: _ShiftDropdown(
                                shifts: _shifts,
                                selectedId: assignedShiftId,
                                onChanged: (shiftId) {
                                  setState(() {
                                    if (shiftId == null) {
                                      _assignments.remove(uid);
                                    } else {
                                      _assignments[uid] = shiftId;
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),

                // ── Save button ────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Assignments'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSaving ? null : _save,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Dropdown to select a shift for an employee.
class _ShiftDropdown extends StatelessWidget {
  final List<ShiftDefinition> shifts;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _ShiftDropdown({
    required this.shifts,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String?>(
        value: selectedId,
        hint: const Text('–', style: TextStyle(color: Colors.grey)),
        underline: const SizedBox.shrink(),
        isExpanded: false,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('None', style: TextStyle(color: Colors.grey)),
          ),
          ...shifts.map(
            (s) => DropdownMenuItem<String?>(
              value: s.id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _dotColor(s.id),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(s.name, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Color _dotColor(String id) {
    switch (id) {
      case 'morning':
        return const Color(0xFF4CAF50);
      case 'afternoon':
        return const Color(0xFFFF9800);
      case 'night':
        return const Color(0xFF2196F3);
      default:
        return Colors.grey;
    }
  }
}
