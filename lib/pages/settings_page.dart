import 'package:flutter/material.dart';
import 'package:yaltes_car_app/pages/login_page.dart';
import 'package:yaltes_car_app/services/api_client.dart';

final api = ApiClient.instance;

class SettingsPage extends StatelessWidget {
  static const route = '/settings';
  const SettingsPage({super.key});

  static const _navy = Color(0xFF232B74);
  static const _chipBg = Color(0xFFEDEDED);
  static const _avatarBg = Color(0xFFE9E9E9);

  Future<void> _logout(BuildContext context) async {
    await api.logout();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      LoginPage.route,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 136,
              height: 136,
              decoration: const BoxDecoration(
                color: _avatarBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person_outline, size: 80, color: _navy),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _chipBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Name Surname',
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Profil Bilgilerini Güncelle'),
            onTap: () {},
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Bildirimleri Aç'),
            trailing: Switch(value: true, onChanged: (_) {}),
          ),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: const Text('Çıkış Yap'),
            onTap: () async {
              await api.clearToken();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Hakkında'),
            onTap: () {},
          ),

          const SizedBox(height: 180),

          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 28,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('YALTES', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
