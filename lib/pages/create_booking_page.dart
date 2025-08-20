import 'package:flutter/material.dart';
import 'package:yaltes_car_app/models/vehicle.dart';
import 'package:yaltes_car_app/services/api_client.dart';

class CreateBookingPage extends StatefulWidget {
  static const route = '/booking/new';
  final Vehicle vehicle;
  const CreateBookingPage({super.key, required this.vehicle});

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  final _api = ApiClient.instance;

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  bool _checking = false;
  bool? _available; // null: bilinmiyor
  String? _availabilityMsg;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    // Başlangıcı en yakın :00 / :30'a yuvarla
    final roundedStart = DateTime(
      now.year,
      now.month,
      now.day,
      now.minute >= 30 ? now.hour + 1 : now.hour,
      now.minute >= 30 ? 0 : 30,
    );
    final defaultEnd = roundedStart.add(const Duration(hours: 2));

    _startDate = DateTime(
      roundedStart.year,
      roundedStart.month,
      roundedStart.day,
    );
    _startTime = TimeOfDay(
      hour: roundedStart.hour,
      minute: roundedStart.minute,
    );

    _endDate = DateTime(defaultEnd.year, defaultEnd.month, defaultEnd.day);
    _endTime = TimeOfDay(hour: defaultEnd.hour, minute: defaultEnd.minute);

    // İlk ekranda otomatik kontrol
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAvailability());
  }

  DateTime? get _startsAt {
    if (_startDate == null || _startTime == null) return null;
    return DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
  }

  DateTime? get _endsAt {
    if (_endDate == null || _endTime == null) return null;
    return DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endTime!.hour,
      _endTime!.minute,
    );
  }

  bool get _timesValid {
    final s = _startsAt, e = _endsAt;
    if (s == null || e == null) return false;
    return e.isAfter(s);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_startDate ?? now) : (_endDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month + 6, 0),
      helpText: isStart ? 'Başlangıç tarihi' : 'Bitiş tarihi',
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = picked;
      }
      _available = null;
      _availabilityMsg = null;
    });
    _checkAvailability();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? TimeOfDay.now())
        : (_endTime ?? TimeOfDay.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'Başlangıç saati' : 'Bitiş saati',
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
      _available = null;
      _availabilityMsg = null;
    });
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final s = _startsAt, e = _endsAt;
    if (s == null || e == null || !e.isAfter(s)) {
      setState(() {
        _available = null;
        _availabilityMsg = null;
      });
      return;
    }

    setState(() {
      _checking = true;
      _available = null;
      _availabilityMsg = 'Uygunluk kontrol ediliyor...';
    });

    try {
      // Bu aralıkta MÜSAİT araç listesi gelir; bizim araç var mı bakıyoruz
      final list = await _api.availability(s, e);
      final ok = list.any(
        (m) => (m['id'] ?? '').toString() == widget.vehicle.id,
      );
      setState(() {
        _available = ok;
        _availabilityMsg = ok
            ? 'Bu aralıkta araç uygun (talep admin onayına gidecek).'
            : 'Bu aralıkta araç uygun değil (başka rezervasyon/engel var).';
      });
    } catch (e) {
      setState(() {
        _available = null;
        _availabilityMsg = 'Kontrol hatası: $e';
      });
    } finally {
      setState(() => _checking = false);
    }
  }

  Future<void> _reserve() async {
    final s = _startsAt, e = _endsAt;
    if (s == null || e == null || !_timesValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir tarih/saat aralığı seçin.'),
        ),
      );
      return;
    }

    // <<< vehicle.id null/boş guard
    final vid = widget.vehicle.id;
    if (vid == null || vid.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Araç ID bulunamadı.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await _api.createBooking(vehicleId: vid, startsAt: s, endsAt: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rezervasyon talebiniz oluşturuldu (onay bekleniyor).'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      final msg = e.toString();
      final friendly = msg.contains('409')
          ? 'Bu aralık biraz önce dolmuş olabilir. Lütfen farklı bir zaman seçin.'
          : 'Rezervasyon başarısız: $msg';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendly)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final v = widget.vehicle;

    return Scaffold(
      appBar: AppBar(title: const Text('Rezervasyon')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Araç başlığı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.directions_car, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${v.plate} — ${v.brand} ${v.model}',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text('Başlangıç', style: tt.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PickTile(
                  label: 'Tarih',
                  value: _startDate == null ? 'Seçiniz' : _fmtDate(_startDate!),
                  icon: Icons.calendar_today_outlined,
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PickTile(
                  label: 'Saat',
                  value: _startTime == null ? 'Seçiniz' : _fmtTime(_startTime!),
                  icon: Icons.schedule_outlined,
                  onTap: () => _pickTime(isStart: true),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text('Bitiş', style: tt.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PickTile(
                  label: 'Tarih',
                  value: _endDate == null ? 'Seçiniz' : _fmtDate(_endDate!),
                  icon: Icons.calendar_today_outlined,
                  onTap: () => _pickDate(isStart: false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PickTile(
                  label: 'Saat',
                  value: _endTime == null ? 'Seçiniz' : _fmtTime(_endTime!),
                  icon: Icons.schedule_outlined,
                  onTap: () => _pickTime(isStart: false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          if (!_timesValid)
            const Text(
              'Bitiş zamanı başlangıçtan sonra olmalı.',
              style: TextStyle(color: Colors.red),
            ),

          if (_availabilityMsg != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_checking)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_checking) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _availabilityMsg!,
                    style: TextStyle(
                      color: _available == null
                          ? cs.onSurfaceVariant
                          : (_available! ? Colors.green[700] : cs.error),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: (_timesValid && _available == true && !_saving)
                ? _reserve
                : null,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.event_available),
            label: const Text('Rezervasyon Yap'),
          ),

          const SizedBox(height: 8),
          Text(
            'Not: Rezervasyon önce admin onayına düşer. Onaylanana kadar araç başka taleplere kapalı tutulur.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
  String _fmtTime(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';
  String _two(int n) => n.toString().padLeft(2, '0');
}

class _PickTile extends StatelessWidget {
  final String label;
  final String value; // non-nullable
  final IconData icon;
  final VoidCallback onTap;
  const _PickTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(value)),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
