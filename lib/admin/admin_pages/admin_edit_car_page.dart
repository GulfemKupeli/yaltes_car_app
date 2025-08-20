import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yaltes_car_app/constants/vehicle_options.dart';
import 'package:yaltes_car_app/features/location/location_picker_page.dart';
import 'package:yaltes_car_app/services/api_client.dart';
import 'package:yaltes_car_app/utils/url_helpers.dart';

class AdminEditCarPage extends StatefulWidget {
  static const route = '/admin_edit_car';
  final Map<String, dynamic>? car;
  const AdminEditCarPage({super.key, required this.car});

  @override
  State<AdminEditCarPage> createState() => _AdminEditCarPageState();
}

class _AdminEditCarPageState extends State<AdminEditCarPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient.instance;

  Map<String, dynamic>? _car;

  final _plate = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _modelYear = TextEditingController();
  final _seats = TextEditingController();
  final _fuelType = TextEditingController();
  final _transmission = TextEditingController();
  final _odometer = TextEditingController();

  String _status = 'active';

  final _locName = TextEditingController();
  final _latText = TextEditingController();
  final _lngText = TextEditingController();

  File? _pickedImageFile;
  String? _uploadedImageUrl;

  bool _saving = false;
  bool _inited = false;

  @override
  void dispose() {
    _plate.dispose();
    _brand.dispose();
    _model.dispose();
    _color.dispose();
    _modelYear.dispose();
    _seats.dispose();
    _fuelType.dispose();
    _transmission.dispose();
    _odometer.dispose();
    _locName.dispose();
    _latText.dispose();
    _lngText.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    _car =
        widget.car ??
        (ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?);
    if (_car != null) _fillFromCar(_car!);
  }

  void _fillFromCar(Map<String, dynamic> c) {
    _plate.text = (c['plate'] ?? '').toString();
    _brand.text = (c['brand'] ?? '').toString();
    _model.text = (c['model'] ?? '').toString();
    _color.text = (c['color'] ?? '').toString();
    _modelYear.text = (c['model_year'] ?? '').toString();
    _seats.text = (c['seats'] ?? '').toString();
    _fuelType.text = (c['fuel_type'] ?? '').toString();
    _transmission.text = (c['transmission'] ?? '').toString();
    _odometer.text = (c['current_odometer'] ?? '').toString();
    _status = (c['status'] ?? 'active').toString();

    _locName.text = (c['last_location_name'] ?? '').toString();
    final lat = c['last_location_lat'];
    final lng = c['last_location_lng'];
    if (lat != null) _latText.text = (lat as num).toStringAsFixed(6);
    if (lng != null) _lngText.text = (lng as num).toStringAsFixed(6);

    setState(() {});
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() {
      _pickedImageFile = File(x.path);
      _uploadedImageUrl = null;
    });
  }

  Future<void> _uploadImageIfNeeded() async {
    if (_pickedImageFile == null) return;
    final url = await _api.uploadImage(_pickedImageFile!);
    _uploadedImageUrl = url;
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.pushNamed(context, LocationPickerPage.route);
    if (result is Map) {
      final name = (result['name'] ?? '').toString();
      final lat = (result['lat'] as num?)?.toDouble();
      final lng = (result['lng'] as num?)?.toDouble();
      setState(() {
        _locName.text = name;
        _latText.text = lat != null ? lat.toStringAsFixed(6) : '';
        _lngText.text = lng != null ? lng.toStringAsFixed(6) : '';
      });
    }
  }

  Future<void> _save() async {
    if (_car == null) return;
    if (!_formKey.currentState!.validate()) return;

    final locName = _locName.text.trim();
    final lat = double.tryParse(_latText.text.trim());
    final lng = double.tryParse(_lngText.text.trim());
    if (locName.isEmpty || lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum adı, enlem ve boylam zorunludur.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _uploadImageIfNeeded();

      final body = <String, dynamic>{};

      void putIfNotEmpty(String key, String val) {
        if (val.trim().isNotEmpty) body[key] = val.trim();
      }

      putIfNotEmpty('plate', _plate.text);
      putIfNotEmpty('brand', _brand.text);
      putIfNotEmpty('model', _model.text);
      putIfNotEmpty('color', _color.text);

      if (_modelYear.text.isNotEmpty) {
        body['model_year'] = int.tryParse(_modelYear.text);
      }
      if (_seats.text.isNotEmpty) {
        body['seats'] = int.tryParse(_seats.text);
      }
      putIfNotEmpty('fuel_type', _fuelType.text);
      putIfNotEmpty('transmission', _transmission.text);
      if (_odometer.text.isNotEmpty) {
        body['current_odometer'] = int.tryParse(_odometer.text);
      }

      body['status'] = _status;

      body['last_location_name'] = locName;
      body['last_location_lat'] = lat;
      body['last_location_lng'] = lng;

      if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) {
        body['image_url'] = _uploadedImageUrl;
      }

      final id = (_car!['id'] ?? '').toString();
      await _api.updateVehicle(id, body);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Araç güncellendi')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Güncelleme başarısız: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final existingRaw = (_car?['image_url'] ?? '').toString();
    final existingImgUrl = resolveImageUrl(existingRaw);
    final showNetwork = _pickedImageFile == null && existingImgUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Araç Düzenle')),
      body: Form(
        key: _formKey,
        child: AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // FOTO
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 190,
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: _pickedImageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _pickedImageFile!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 190,
                          ),
                        )
                      : (showNetwork
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  existingImgUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 190,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_outlined,
                                    size: 52,
                                  ),
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.image_outlined, size: 52),
                                  const SizedBox(height: 8),
                                  Text('Fotoğraf seç', style: tt.bodyMedium),
                                ],
                              )),
                ),
              ),
              const SizedBox(height: 16),

              _Field(
                label: 'Plaka *',
                controller: _plate,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Plaka gerekli' : null,
              ),
              _Field(
                label: 'Marka *',
                controller: _brand,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Marka gerekli' : null,
              ),
              _Field(
                label: 'Model *',
                controller: _model,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Model gerekli' : null,
              ),

              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Model Yılı',
                      controller: _modelYear,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      label: 'Koltuk',
                      controller: _seats,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  Expanded(
                    child: _DropdownField(
                      label: 'Yakıt',
                      controller: _fuelType,
                      items: VehicleOptions.fuelTypes,
                      hintText: 'Seçiniz',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DropdownField(
                      label: 'Vites',
                      controller: _transmission,
                      items: VehicleOptions.transmissions,
                      hintText: 'Seçiniz',
                    ),
                  ),
                ],
              ),

              _Field(
                label: 'Renk',
                controller: _color,
                textInputAction: TextInputAction.next,
              ),
              _Field(
                label: 'KM',
                controller: _odometer,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),

              const SizedBox(height: 8),

              Text('Durum', style: tt.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Aktif'),
                    selected: _status == 'active',
                    onSelected: (_) => setState(() => _status = 'active'),
                  ),
                  ChoiceChip(
                    label: const Text('Bakımda'),
                    selected: _status == 'maintenance',
                    onSelected: (_) => setState(() => _status = 'maintenance'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Text('Son Bırakıldığı Konum', style: tt.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Konum Adı *',
                      controller: _locName,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _openLocationPicker,
                    icon: const Icon(Icons.place_outlined),
                    label: const Text('Konum Seç'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Enlem (lat) *',
                      controller: _latText,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (double.tryParse((v ?? '').trim()) == null)
                          ? 'Geçersiz sayı'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      label: 'Boylam (lng) *',
                      controller: _lngText,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (double.tryParse((v ?? '').trim()) == null)
                          ? 'Geçersiz sayı'
                          : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
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
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    this.textInputAction,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        textInputAction: textInputAction,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
      ),
    );
  }
}

class _DropdownField extends StatefulWidget {
  const _DropdownField({
    required this.label,
    required this.controller,
    required this.items,
    this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final List<String> items;
  final String? hintText;

  @override
  State<_DropdownField> createState() => _DropdownFieldState();
}

class _DropdownFieldState extends State<_DropdownField> {
  @override
  Widget build(BuildContext context) {
    final current = widget.controller.text.isEmpty
        ? null
        : widget.controller.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: (current != null && widget.items.contains(current))
            ? current
            : null,
        items: widget.items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (val) => widget.controller.text = val ?? '',
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
      ),
    );
  }
}
