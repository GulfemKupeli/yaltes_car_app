import 'package:flutter/material.dart';
import 'package:yaltes_car_app/models/vehicle.dart';
import 'package:yaltes_car_app/pages/car_detail_page.dart';
import 'package:yaltes_car_app/services/api_client.dart';
import 'package:yaltes_car_app/app_constants.dart';
import 'package:yaltes_car_app/utils/url_helpers.dart';

class GaragePage extends StatefulWidget {
  const GaragePage({super.key});

  @override
  State<GaragePage> createState() => _GaragePageState();
}

class _GaragePageState extends State<GaragePage> {
  int _filterIndex = 0;
  bool _loading = false;
  List<Vehicle> _vehicles = [];

  final api = ApiClient.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await api.listVehicles(); // List<dynamic>
      _vehicles = list
          .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Araçlar alınamadı: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Vehicle> get _filtered {
    final wanted = switch (_filterIndex) {
      1 => VehicleStatus.active,
      2 => VehicleStatus.maintenance,
      3 => VehicleStatus.retired,
      _ => null,
    };
    if (wanted == null) return _vehicles;
    return _vehicles.where((v) => v.status == wanted).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              'Araçlar',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _FilterChip(
                label: 'Tümü',
                selected: _filterIndex == 0,
                onSelected: () => setState(() => _filterIndex = 0),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Aktif',
                selected: _filterIndex == 1,
                onSelected: () => setState(() => _filterIndex = 1),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Bakımda',
                selected: _filterIndex == 2,
                onSelected: () => setState(() => _filterIndex = 2),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Emekli',
                selected: _filterIndex == 3,
                onSelected: () => setState(() => _filterIndex = 3),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const Icon(Icons.directions_car, size: 56),
                  const SizedBox(height: 8),
                  Text('Kayıt bulunamadı', style: tt.bodyMedium),
                ],
              ),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final v in _filtered)
                  _CarCard(v: v, surfaceVariant: cs.surfaceVariant),
              ],
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.secondary : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: selected ? cs.onSecondary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  final Vehicle v;
  final Color surfaceVariant;
  const _CarCard({required this.v, required this.surfaceVariant});

  @override
  Widget build(BuildContext context) {
    final imgUrl = resolveImageUrl(v.imageUrl);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(context, CarDetailPage.route, arguments: v);
      },
      child: SizedBox(
        width: 180,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: imgUrl.isEmpty
                      ? const Icon(Icons.directions_car, size: 40)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 80,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  v.plate,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${v.brand} ${v.model}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: v.status.color(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        v.status.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
