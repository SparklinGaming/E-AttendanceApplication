import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/current_user_provider.dart';
import '../../repositories/overtime_repository.dart';
import '../../repositories/shift_repository.dart';
import '../../repositories/settings_repository.dart';

/// Employee overtime request form (Bahasa Indonesia UI).
class OvertimeRequestPage extends StatefulWidget {
  const OvertimeRequestPage({super.key});

  @override
  State<OvertimeRequestPage> createState() => _OvertimeRequestPageState();
}

class _OvertimeRequestPageState extends State<OvertimeRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final OvertimeRepository _otRepo = OvertimeRepository();
  final ShiftRepository _shiftRepo = ShiftRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

  // ── Date ──────────────────────────────────────────────────────────
  late DateTime _selectedDate;

  // ── Work schedule ─────────────────────────────────────────────────
  String _shiftStart = '09:00';
  String _shiftEnd = '18:00';
  String? _shiftName;
  bool _loadingShift = true;

  // ── Overtime times (default: start = shift end + 0) ───────────────
  late TimeOfDay _otStart;
  late TimeOfDay _otEnd;

  // ── Break ─────────────────────────────────────────────────────────
  double _breakHours = 0;

  // ── Compensation ──────────────────────────────────────────────────
  String _compensationType = 'upah_lembur';

  // ── Notes ─────────────────────────────────────────────────────────
  final TextEditingController _notesCtrl = TextEditingController();

  // ── Attachment ────────────────────────────────────────────────────
  File? _attachmentFile;
  bool _uploading = false;

  // ── Calculated ────────────────────────────────────────────────────
  double get _durationHours {
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _otStart.hour,
      _otStart.minute,
    );
    final end = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _otEnd.hour,
      _otEnd.minute,
    );
    if (!end.isAfter(start)) return 0;
    return (end.difference(start).inMinutes / 60.0) - _breakHours;
  }

  String get _durationText {
    final d = _durationHours;
    if (d <= 0) return '0 jam';
    final h = d.floor();
    final m = ((d - h) * 60).round();
    if (h > 0 && m > 0) return '$h jam $m menit';
    if (h > 0) return '$h jam';
    return '$m menit';
  }

  // ── Init ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _otStart = const TimeOfDay(hour: 18, minute: 0);
    _otEnd = const TimeOfDay(hour: 20, minute: 0);
    _loadShift();
  }

  Future<void> _loadShift() async {
    final uid = context.read<CurrentUserProvider>().uid;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    ShiftDefinition? shift;
    if (uid != null) {
      shift = await _shiftRepo.getEmployeeShift(uid, dateStr);
    }

    if (shift != null) {
      _shiftStart = shift.formatStart();
      _shiftEnd = shift.formatEnd();
      _shiftName = shift.name;

      // Default overtime start = shift end time
      _otStart = TimeOfDay(hour: shift.endHour, minute: shift.endMinute);
      _otEnd =
          TimeOfDay(hour: (shift.endHour + 2) % 24, minute: shift.endMinute);
    } else {
      final settings = await _settingsRepo.getWorkSettings();
      if (settings != null) {
        _shiftStart =
            '${settings['start_hour']!.toString().padLeft(2, '0')}:${settings['start_minute']!.toString().padLeft(2, '0')}';
        _shiftEnd =
            '${settings['end_hour']!.toString().padLeft(2, '0')}:${settings['end_minute']!.toString().padLeft(2, '0')}';
        _otStart = TimeOfDay(
            hour: settings['end_hour']!, minute: settings['end_minute']!);
        _otEnd = TimeOfDay(
            hour: (settings['end_hour']! + 2) % 24,
            minute: settings['end_minute']!);
      }
    }

    if (mounted) setState(() => _loadingShift = false);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Pickers ───────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadShift();
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _otStart : _otEnd;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _otStart = picked;
        } else {
          _otEnd = picked;
        }
      });
    }
  }

  Future<void> _pickAttachment() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lampiran'),
        content: const Text('Pilih sumber gambar'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Text('Kamera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Text('Galeri'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 70,
    );
    if (picked != null && mounted) {
      setState(() => _attachmentFile = File(picked.path));
    }
  }

  // ── Submit ────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final d = _durationHours;
    if (d <= 0) {
      _showError(
          'Waktu lembur tidak valid. Pastikan jam selesai setelah jam mulai.');
      return;
    }
    if (d > 4) {
      _showError(
          'Lembur maksimal 4 jam per hari (sesuai peraturan PP 35/2021).');
      return;
    }

    // Validate overtime start is after or at shift end
    final shiftEnd = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      int.parse(_shiftEnd.split(':')[0]),
      int.parse(_shiftEnd.split(':')[1]),
    );
    final otStartDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _otStart.hour,
      _otStart.minute,
    );
    if (otStartDt.isBefore(shiftEnd)) {
      _showError(
          'Jam mulai lembur harus setelah atau sama dengan jam selesai kerja ($_shiftEnd).');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final userProvider = context.read<CurrentUserProvider>();
    final uid = userProvider.uid;
    final name = userProvider.displayName;

    if (uid == null) {
      _showError('Anda belum login.');
      return;
    }

    try {
      // Upload attachment if any
      String? attachmentUrl;
      if (_attachmentFile != null) {
        setState(() => _uploading = true);
        attachmentUrl = await _otRepo.uploadAttachment(uid, _attachmentFile!);
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final request = OvertimeRequest(
        uid: uid,
        name: name,
        date: dateStr,
        shiftStart: _shiftStart,
        shiftEnd: _shiftEnd,
        overtimeStart: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _otStart.hour,
          _otStart.minute,
        ),
        overtimeEnd: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _otEnd.hour,
          _otEnd.minute,
        ),
        breakHours: _breakHours,
        durationHours: d,
        compensationType: _compensationType,
        notes: _notesCtrl.text.trim(),
        attachmentUrl: attachmentUrl,
      );

      await _otRepo.submitOvertime(request);

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pengajuan lembur berhasil dikirim!'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal mengirim: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Lembur'),
        actions: [
          TextButton(
            onPressed: _uploading ? null : _submit,
            child: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kirim',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: _loadingShift
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Date & Schedule card ─────────────────────
                    _Card(
                      children: [
                        _Label('Tanggal jadwal kerja'),
                        _TapField(
                          value: DateFormat('EEEE, dd MMM yyyy')
                              .format(_selectedDate),
                          icon: Icons.calendar_today,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const _Label('Jam kerja'),
                            const Spacer(),
                            if (_shiftName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(_shiftName!,
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.blue[700])),
                              ),
                            const SizedBox(width: 8),
                            Text(_shiftStart,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const Text(' – '),
                            Text(_shiftEnd,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Overtime times ───────────────────────────
                    _Card(
                      children: [
                        const _Label('Mulai lembur'),
                        _TapField(
                          value: _otStart.format(context),
                          icon: Icons.schedule,
                          onTap: () => _pickTime(true),
                        ),
                        const SizedBox(height: 12),
                        const _Label('Selesai lembur'),
                        _TapField(
                          value: _otEnd.format(context),
                          icon: Icons.schedule,
                          onTap: () => _pickTime(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Duration summary card ────────────────────
                    _Card(
                      color: Colors.blue[50],
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined,
                                size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text('Durasi lembur',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text(_durationText,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Maksimal 4 jam/hari (PP 35/2021)',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Break hours ──────────────────────────────
                    _Card(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: _Label('Jumlah jam istirahat'),
                            ),
                            SizedBox(
                              width: 120,
                              child: Slider(
                                value: _breakHours,
                                min: 0,
                                max: 2,
                                divisions: 8,
                                label: _breakHours.toStringAsFixed(1),
                                onChanged: (v) =>
                                    setState(() => _breakHours = v),
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              child: Text(
                                _breakHours.toStringAsFixed(1),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Compensation type ────────────────────────
                    _Card(
                      children: [
                        const _Label('Dapat replacement off'),
                        const SizedBox(height: 8),
                        _CompensationOption(
                          value: 'upah_lembur',
                          groupValue: _compensationType,
                          title: 'Upah lembur',
                          subtitle: 'Dibayar sesuai peraturan ketenagakerjaan',
                          onChanged: (v) =>
                              setState(() => _compensationType = v!),
                        ),
                        const Divider(height: 4),
                        _CompensationOption(
                          value: 'replacement_off',
                          groupValue: _compensationType,
                          title: 'Replacement off',
                          subtitle: 'Diganti hari libur di lain waktu',
                          onChanged: (v) =>
                              setState(() => _compensationType = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Attachment ───────────────────────────────
                    _Card(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: _Label('Lampiran'),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.attach_file, size: 18),
                              label: Text(
                                _attachmentFile != null ? 'Ganti' : 'Tambah',
                              ),
                              onPressed: _pickAttachment,
                            ),
                          ],
                        ),
                        if (_attachmentFile != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.image,
                                    size: 20, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _attachmentFile!.path.split('/').last,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 16, color: Colors.red),
                                  onPressed: () =>
                                      setState(() => _attachmentFile = null),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Notes ────────────────────────────────────
                    _Card(
                      children: [
                        const _Label('Keterangan'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Alasan dan detail pekerjaan lembur...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── Regulations info ─────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Ketentuan Lembur',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 4),
                          Text(
                            '• Maksimal 4 jam per hari / 18 jam per minggu\n'
                            '• Jam pertama: 1,5× upah sejam\n'
                            '• Jam berikutnya: 2× upah sejam\n'
                            '• Lembur harus dengan persetujuan karyawan',
                            style: TextStyle(fontSize: 11, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Reusable components ──────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final List<Widget> children;
  final Color? color;
  const _Card({required this.children, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));
  }
}

class _TapField extends StatelessWidget {
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _TapField({
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _CompensationOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final String title;
  final String subtitle;
  final ValueChanged<String?> onChanged;

  const _CompensationOption({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      contentPadding: EdgeInsets.zero,
      dense: true,
      onChanged: onChanged,
    );
  }
}