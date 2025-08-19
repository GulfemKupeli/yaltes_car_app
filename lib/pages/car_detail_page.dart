import 'package:flutter/material.dart';
import 'package:yaltes_car_app/app_constants.dart';
import 'package:yaltes_car_app/models/vehicle.dart';
import 'package:yaltes_car_app/utils/url_helpers.dart';

class CarDetailPage extends StatelessWidget {
  static const route = '/car_detail';
  final Vehicle vehicle;
  const CarDetailPage({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final imgUrl = resolveImageUrl(v.imageUrl);

    return Scaffold(
      appBar: AppBar(title: Text(v.plate.isNotEmpty ? v.plate : 'Araç Detayı')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: (imgUrl.isEmpty)
                ? const Icon(Icons.directions_car, size: 80)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 220,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined, size: 80),
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          Text(
            '${v.brand} ${v.model}${v.modelYear != null ? " (${v.modelYear})" : ""}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              Icon(Icons.circle, size: 12, color: v.status.color(context)),
              const SizedBox(width: 8),
              Text(
                v.status.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),

          _kv('Plaka', v.plate),
          _kv('Renk', v.color ?? ''),
          _kv('Koltuk', v.seats?.toString() ?? ''),
          _kv('Yakıt', v.fuelType ?? ''),
          _kv('Vites', v.transmission ?? ''),
          _kv('KM', v.currentOdometer?.toString() ?? ''),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              //rezervasyon şeyi
            },
            icon: const Icon(Icons.event_available),
            label: const Text('Rezervasyon Yap (yakında)'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
