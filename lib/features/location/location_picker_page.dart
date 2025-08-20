import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickResult {
  final String name;
  final double lat;
  final double lng;
  const LocationPickResult({
    required this.name,
    required this.lat,
    required this.lng,
  });
}

class LocationPickerPage extends StatefulWidget {
  static const route = '/location/picker';
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _query = TextEditingController();
  bool _loading = false;
  LocationPickResult? _result;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<bool> _ensurePermission() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied)
      p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loading = true);
    try {
      final ok = await _ensurePermission();
      if (!ok) throw 'Konum izni gerekli';
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = marks.isNotEmpty ? marks.first : null;
      final name = [
        p?.name,
        p?.thoroughfare,
        p?.subLocality,
        p?.locality,
      ].where((e) => (e ?? '').trim().isNotEmpty).join(', ');
      setState(() {
        _result = LocationPickResult(
          name: name.isNotEmpty ? name : 'Seçilen konum',
          lat: pos.latitude,
          lng: pos.longitude,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Konum alınamadı: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchByAddress() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    try {
      final locs = await locationFromAddress(q);
      if (locs.isEmpty) throw 'Adres bulunamadı';
      final loc = locs.first;
      final marks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
      final p = marks.isNotEmpty ? marks.first : null;
      final name = [
        p?.name,
        p?.thoroughfare,
        p?.subLocality,
        p?.locality,
      ].where((e) => (e ?? '').trim().isNotEmpty).join(', ');
      setState(() {
        _result = LocationPickResult(
          name: name.isNotEmpty ? name : q,
          lat: loc.latitude,
          lng: loc.longitude,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Adres çözülemedi: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirm() {
    if (_result == null) return;
    Navigator.pop(context, _result);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Konum Seç')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Adresle Bul', style: tt.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  decoration: const InputDecoration(
                    hintText: 'Örn: Büyük Otopark A2, Ümraniye',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _searchByAddress,
                icon: const Icon(Icons.search),
                label: const Text('Bul'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Ya da', style: tt.titleSmall),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _useCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Konumumu kullan'),
          ),
          const SizedBox(height: 16),
          if (_result != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.place),
                title: Text(_result!.name),
                subtitle: Text(
                  '${_result!.lat.toStringAsFixed(6)}, ${_result!.lng.toStringAsFixed(6)}',
                ),
                trailing: FilledButton(
                  onPressed: _confirm,
                  child: const Text('Seç'),
                ),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
