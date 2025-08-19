import 'package:flutter/material.dart';

class AdminEditCarPage extends StatelessWidget {
  static const route = '/admin_edit_car';
  const AdminEditCarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final plate = TextEditingController();
    final brand = TextEditingController();
    final model = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Araç Ekle/Düzenle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Bilgiler', style: tt.titleMedium),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(labelText: 'Plaka'),
            controller: plate,
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(labelText: 'Marka'),
            controller: brand,
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(labelText: 'Model'),
            controller: model,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
