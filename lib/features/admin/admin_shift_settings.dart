import 'package:flutter/material.dart';
import '../../repositories/shift_repository.dart';

/// Admin page to define shift templates (name, start/end time).
class AdminShiftSettingsPage extends StatefulWidget {
  const AdminShiftSettingsPage({super.key});

  @override
  State<AdminShiftSettingsPage> createState() => _AdminShiftSettingsPageState();
}

class _AdminShiftSettingsPageState extends State<AdminShiftSettingsPage> {
  final ShiftRepository _shiftRepo = ShiftRepository();
  List<ShiftDefinition> _shifts = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    final shifts = await _shiftRepo.getShiftDefinitions();
    if (!mounted) return;
    setState(() {
      _shifts = shifts;
      _isLoading = false;
    });
  }

  Future<void> _pickTime(int shiftIndex, bool isStart) async {
    final shift = _shifts[shiftIndex];
    final initial = TimeOfDay(
      hour: isStart ? shift.startHour : shift.endHour,
      minute: isStart ? shift.startMinute : shift.endMinute,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;

    setState(() {
      _shifts[shiftIndex] = shift.copyWith(
        startHour: isStart ? picked.hour : shift.startHour,
        startMinute: isStart ? picked.minute : shift.startMinute,
        endHour: isStart ? shift.endHour : picked.hour,
        endMinute: isStart ? shift.endMinute : picked.minute,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await _shiftRepo.saveShiftDefinitions(_shifts);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shifts saved!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shift Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Define Shift Templates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Set the name and working hours for each shift. '
                  'These will be used when assigning employees to shifts.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                ...List.generate(_shifts.length, (i) {
                  final shift = _shifts[i];
                  return _ShiftCard(
                    shift: shift,
                    index: i,
                    onNameChanged: (name) {
                      setState(() {
                        _shifts[i] = shift.copyWith(name: name);
                      });
                    },
                    onPickStart: () => _pickTime(i, true),
                    onPickEnd: () => _pickTime(i, false),
                    onDelete: _shifts.length > 1
                        ? () {
                            setState(() => _shifts.removeAt(i));
                          }
                        : null,
                  );
                }),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Shifts'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSaving ? null : _save,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final ShiftDefinition shift;
  final int index;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback? onDelete;

  const _ShiftCard({
    required this.shift,
    required this.index,
    required this.onNameChanged,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _shiftColor(index);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: shift.name),
                    decoration: const InputDecoration(
                      labelText: 'Shift Name',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: onNameChanged,
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete shift',
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: 'Start',
                    time: shift.formatStart(),
                    onTap: onPickStart,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 18),
                ),
                Expanded(
                  child: _TimeTile(
                    label: 'End',
                    time: shift.formatEnd(),
                    onTap: onPickEnd,
                  ),
                ),
              ],
            ),
            if (shift.isOvernight)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: const [
                    Icon(Icons.nightlight_round,
                        size: 14, color: Colors.deepPurple),
                    SizedBox(width: 4),
                    Text('Overnight shift',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.deepPurple,
                            fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  Color _shiftColor(int idx) {
    const colors = [
      Color(0xFF4CAF50), // green
      Color(0xFFFF9800), // orange
      Color(0xFF2196F3), // blue
      Color(0xFF9C27B0), // purple
      Color(0xFFF44336), // red
    ];
    return colors[idx % colors.length];
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(time,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// Extension for display formatting
extension ShiftTimeFormat on ShiftDefinition {
  String formatStart() =>
      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
  String formatEnd() =>
      '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
}
