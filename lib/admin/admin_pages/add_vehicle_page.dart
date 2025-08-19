import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yaltes_car_app/services/api_client.dart';

class AddVehiclePage extends StatefulWidget {
  static const route = '/vehicle/new';
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();

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
  File? _pickedImageFile;
  String? _uploadedImageUrl;

  bool _saving = false;

  final _api = ApiClient.instance;

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
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await _uploadImageIfNeeded();

      final body = <String, dynamic>{
        'plate': _plate.text.trim(),
        'brand': _brand.text.trim(),
        'model': _model.text.trim(),
        'status': _status,
      };

      void putIfNotEmpty(String key, String val) {
        if (val.trim().isNotEmpty) body[key] = val.trim();
      }

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

      if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) {
        body['image_url'] = _uploadedImageUrl;
      }

      final created = await _api.createVehicle(body);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Araç eklendi')));

      Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kayıt başarısız: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Araç Ekle')),
      body: Form(
        // 👈 BURADA
        key: _formKey,
        child: AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 190,
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: _pickedImageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image_outlined, size: 52),
                            const SizedBox(height: 8),
                            Text('Fotoğraf seç', style: tt.bodyMedium),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _pickedImageFile!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 190,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              _Field(
                label: 'Plaka *',
                controller: _plate,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Plaka gerekli' : null,
                autofill: const [AutofillHints.name],
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
                    child: _Field(
                      label: 'Yakıt',
                      controller: _fuelType,
                      textInputAction: TextInputAction.next,
                      hintText: 'Benzin/Dizel/Elektrik…',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      label: 'Vites',
                      controller: _transmission,
                      textInputAction: TextInputAction.next,
                      hintText: 'Manuel/Otomatik…',
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
                  ChoiceChip(
                    label: const Text('Emekli'),
                    selected: _status == 'retired',
                    onSelected: (_) => setState(() => _status = 'retired'),
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
  final List<String>? autofill;
  final String? hintText;

  const _Field({
    required this.label,
    required this.controller,
    this.textInputAction,
    this.keyboardType,
    this.validator,
    this.autofill,
    this.hintText,
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
        autofillHints: autofill,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
      ),
    );
  }
}
