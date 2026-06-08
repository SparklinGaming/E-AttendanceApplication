import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/settings_repository.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final SettingsRepository _settingsRepository = SettingsRepository();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  // Working days (1=Mon … 7=Sun)
  final List<int> _workingDays = [1, 2, 3, 4, 5];

  // National holidays (yyyy-MM-dd strings)
  List<String> _holidays = [];

  bool _isLoading = true;

  static const List<String> _dayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final config = await _settingsRepository.getFullWorkConfig();
    if (!mounted) return;
    setState(() {
      if (config != null) {
        _startTime = TimeOfDay(
            hour: config['start_hour'], minute: config['start_minute']);
        _endTime =
            TimeOfDay(hour: config['end_hour'], minute: config['end_minute']);
        if (config['working_days'] != null) {
          _workingDays
            ..clear()
            ..addAll(List<int>.from(config['working_days']));
        }
        if (config['holidays'] != null) {
          _holidays = List<String>.from(config['holidays']);
        }
      }
      _isLoading = false;
    });
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _toggleWorkingDay(int day) {
    setState(() {
      if (_workingDays.contains(day)) {
        _workingDays.remove(day);
      } else {
        _workingDays.add(day);
        _workingDays.sort();
      }
    });
  }

  Future<void> _addHoliday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      if (!_holidays.contains(dateStr)) {
        setState(() => _holidays.add(dateStr));
        _holidays.sort();
      }
    }
  }

  void _removeHoliday(String dateStr) {
    setState(() => _holidays.remove(dateStr));
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    await _settingsRepository.setWorkSettings(_startTime, _endTime);
    await _settingsRepository.setWorkingDays(_workingDays);
    await _settingsRepository.setHolidays(_holidays);
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings Saved!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Work Settings")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Work Hours ──────────────────────────────────────
                const Text("Standard Work Hours",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ListTile(
                  title: const Text("Start Time (Check In)"),
                  trailing: Text(_startTime.format(context),
                      style: const TextStyle(fontSize: 16)),
                  onTap: () => _selectTime(true),
                ),
                const Divider(),
                ListTile(
                  title: const Text("End Time (Check Out)"),
                  trailing: Text(_endTime.format(context),
                      style: const TextStyle(fontSize: 16)),
                  onTap: () => _selectTime(false),
                ),

                const SizedBox(height: 30),

                // ── Working Days ────────────────────────────────────
                const Text("Working Days",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  "Select which days are working days. Unchecked days "
                  "will appear as holidays (red) on the weekly chart.",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final isSelected = _workingDays.contains(day);
                    return FilterChip(
                      label: Text(_dayLabels[i]),
                      selected: isSelected,
                      selectedColor: Colors.green[200],
                      checkmarkColor: Colors.green[900],
                      onSelected: (_) => _toggleWorkingDay(day),
                    );
                  }),
                ),

                const SizedBox(height: 30),

                // ── National Holidays ───────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("National Holidays",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Add"),
                      onPressed: _addHoliday,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "These dates will also show as red in the weekly chart.",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                if (_holidays.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("No holidays added yet.",
                        style: TextStyle(color: Colors.black38)),
                  )
                else
                  ..._holidays.map(
                    (dateStr) {
                      final display = _formatDateDisplay(dateStr);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        child: ListTile(
                          leading: const Icon(Icons.event, color: Colors.red),
                          title: Text(display),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _removeHoliday(dateStr),
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 40),

                // ── Save Button ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 15)),
                    onPressed: _saveSettings,
                    child: const Text("Save All Settings",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  String _formatDateDisplay(String yyyyMMdd) {
    try {
      final dt = DateFormat('yyyy-MM-dd').parse(yyyyMMdd);
      return DateFormat('EEEE, dd MMM yyyy').format(dt);
    } catch (_) {
      return yyyyMMdd;
    }
  }
}
