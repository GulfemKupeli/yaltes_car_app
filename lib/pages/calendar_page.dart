import 'package:flutter/material.dart';
import 'package:yaltes_car_app/models/bookings.dart';
import 'package:yaltes_car_app/services/api_client.dart';

class CalendarPage extends StatefulWidget {
  static const route = '/calendar';
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _api = ApiClient.instance;
  bool _loading = true;
  String? _error;
  List<Booking> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.myBookings();
      list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      if (!mounted) return;
      setState(() => _all = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = _all
        .where((b) => b.endsAt.isAfter(now) && b.status != 'canceled')
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Takvim & Randevular')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            Text(
              'Yaklaşan Randevular',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (upcoming.isEmpty) const Text('Yaklaşan randevu yok.'),
            for (final b in upcoming)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text('${_fmtDT(b.startsAt)} – ${_fmtDT(b.endsAt)}'),
                  subtitle: Text(
                    'Durum: ${b.status}${b.purpose != null ? ' • ${b.purpose}' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      BookingDetailPage.route,
                      arguments: b,
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Aylık görünüm',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _MonthGrid(bookings: upcoming),
          ],
        ),
      ),
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDT(DateTime d) =>
      '${_two(d.day)}.${_two(d.month)} ${_two(d.hour)}:${_two(d.minute)}';
}

class _MonthGrid extends StatelessWidget {
  final List<Booking> bookings;
  const _MonthGrid({required this.bookings});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, 1);
    final firstWeekday = first.weekday % 7;
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;

    final Map<int, int> dots = {};
    for (final b in bookings) {
      if (b.startsAt.month == today.month && b.startsAt.year == today.year) {
        dots[b.startsAt.day] = (dots[b.startsAt.day] ?? 0) + 1;
      }
    }

    final totalCells = firstWeekday + daysInMonth;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: totalCells,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemBuilder: (_, i) {
          if (i < firstWeekday) return const SizedBox.shrink();
          final day = i - firstWeekday + 1;
          final has = dots[day] ?? 0;
          final isToday = day == today.day;
          return Container(
            decoration: BoxDecoration(
              color: isToday ? Colors.green.withOpacity(.2) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 6,
                  top: 4,
                  child: Text(
                    '$day',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (has > 0)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: CircleAvatar(radius: 4),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class BookingDetailPage extends StatefulWidget {
  static const route = '/booking/detail';
  const BookingDetailPage({super.key});
  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  final _api = ApiClient.instance;
  late Booking b;
  TimeOfDay? _endTime;
  DateTime? _endDate;
  final bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    b = ModalRoute.of(context)!.settings.arguments as Booking;
    _endDate = DateTime(b.endsAt.year, b.endsAt.month, b.endsAt.day);
    _endTime = TimeOfDay(hour: b.endsAt.hour, minute: b.endsAt.minute);
  }

  DateTime get _newEnd => DateTime(
    _endDate!.year,
    _endDate!.month,
    _endDate!.day,
    _endTime!.hour,
    _endTime!.minute,
  );

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Rezervasyon Detayı')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.access_time),
            title: Text('${_fmt(b.startsAt)} – ${_fmt(b.endsAt)}'),
            subtitle: Text(
              'Durum: ${b.status}${b.purpose != null ? ' • ${b.purpose}' : ''}',
            ),
          ),
          const Divider(),
          Text('Bırakış (bitiş) saatini düzenle', style: tt.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PickTile(
                  label: 'Tarih',
                  value: _fmtDate(_endDate!),
                  icon: Icons.calendar_today_outlined,
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate!,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: DateTime(now.year, now.month + 6, 0),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PickTile(
                  label: 'Saat',
                  value: _fmtTime(_endTime!),
                  icon: Icons.schedule_outlined,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _endTime!,
                    );
                    if (picked != null) setState(() => _endTime = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final newEnd = _newEnd;
    if (!newEnd.isAfter(b.startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitiş, başlangıçtan sonra olmalı.')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bitiş zamanı düzenleme özelliği yakında eklenecek.'),
      ),
    );
    Navigator.pop(context);
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmt(DateTime d) =>
      '${_two(d.day)}.${_two(d.month)} ${_two(d.hour)}:${_two(d.minute)}';
  String _fmtDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
  String _fmtTime(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';
}

class _PickTile extends StatelessWidget {
  final String label;
  final String value;
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
          color: cs.surfaceContainerHighest,
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
