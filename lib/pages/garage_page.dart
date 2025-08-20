import 'package:flutter/material.dart';
import 'package:yaltes_car_app/models/vehicle.dart';
import 'package:yaltes_car_app/pages/car_detail_page.dart';
import 'package:yaltes_car_app/services/api_client.dart';
import 'package:yaltes_car_app/utils/url_helpers.dart';

class GaragePage extends StatefulWidget {
  const GaragePage({super.key});

  @override
  State<GaragePage> createState() => _GaragePageState();
}

class _GaragePageState extends State<GaragePage> {
  static const _navy = Color(0xFF232B74);

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
      final list = await api.listVehicles();
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

  List<Vehicle> get _available =>
      _vehicles.where((v) => v.status == VehicleStatus.active).toList();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              'Müsait Araçlar',
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_available.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const Icon(Icons.directions_car, size: 56),
                  const SizedBox(height: 8),
                  Text('Müsait araç bulunamadı', style: tt.bodyMedium),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final maxW = c.maxWidth;
                final cross = maxW >= 1000 ? 4 : (maxW >= 700 ? 3 : 2);
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _available.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.82, // kartı dikine biraz uzattık
                  ),
                  itemBuilder: (_, i) =>
                      _CarCard(v: _available[i], titleColor: _navy),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  final Vehicle v;
  final Color titleColor;
  const _CarCard({required this.v, required this.titleColor});

  static const _navy = Color(0xFF232B74);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imgUrl = resolveImageUrl(v.imageUrl);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          Navigator.pushNamed(context, CarDetailPage.route, arguments: v),
      child: Card(
        clipBehavior: Clip.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
        child: Padding(
          // kart içinde kenarlık/boşluk
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- ÇERÇEVELİ GÖRSEL ----
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(6), // ince çerçeve etkisi
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 4 / 3, // tutarlı görünüm
                    child: imgUrl.isEmpty
                        ? Center(
                            child: Icon(
                              Icons.directions_car,
                              size: 48,
                              color: cs.outline,
                            ),
                          )
                        : Image.network(
                            imgUrl,
                            fit: BoxFit.cover, // istersen BoxFit.contain yap
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 40,
                                color: cs.outline,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ---- METİNLER (NAVY) ----
              Text(
                v.plate,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${v.brand} ${v.model}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
