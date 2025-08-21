import 'package:flutter/material.dart';
import 'package:yaltes_car_app/app_constants.dart';
import 'package:yaltes_car_app/models/vehicle.dart';
import 'package:yaltes_car_app/pages/create_booking_page.dart';

class CarDetailPage extends StatelessWidget {
  static const route = '/car_detail';
  final Vehicle vehicle;
  const CarDetailPage({super.key, required this.vehicle});

  static const _navy = Color(0xFF232B74);

  String _resolveImg(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return '${AppConstants.BASE_URL}$raw';
  }

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final imgUrl = _resolveImg(v.imageUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text(v.plate.isNotEmpty ? v.plate : 'Araç Detayı'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Büyük kapak görsel
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: imgUrl.isEmpty
                  ? Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.directions_car, size: 80),
                    )
                  : Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            '${v.brand} ${v.model}${v.modelYear != null ? " (${v.modelYear})" : ""}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),

          // Özellikler
          _kv('Plaka', v.plate),
          _kv('Renk', v.color ?? ''),
          _kv('Koltuk', v.seats?.toString() ?? ''),
          _kv('Yakıt', v.fuelType ?? ''),
          _kv('Vites', v.transmission ?? ''),
          _kv('Kilometre', v.currentOdometer?.toString() ?? ''),
          const SizedBox(height: 8),
          _kv('Son Bırakıldığı Yer', v.lastLocationName ?? ''),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                CreateBookingPage.route,
                arguments: vehicle, // Vehicle modeli
              );
            },
            icon: const Icon(Icons.event_available),
            label: const Text('Rezervasyon Yap'),
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
            width: 160,
            child: Text(
              k,
              style: const TextStyle(fontWeight: FontWeight.w700, color: _navy),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontWeight: FontWeight.w500, color: _navy),
            ),
          ),
        ],
      ),
    );
  }
}
