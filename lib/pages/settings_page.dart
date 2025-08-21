import 'package:flutter/material.dart';
import 'package:yaltes_car_app/pages/login_page.dart';
import 'package:yaltes_car_app/services/api_client.dart';

final api = ApiClient.instance;

class SettingsPage extends StatefulWidget {
  static const route = '/settings';
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _navy = Color(0xFF232B74);
  static const _chipBg = Color(0xFFEDEDED);
  static const _avatarBg = Color(0xFFE9E9E9);

  Map<String, dynamic>? _me;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMe();
  }

  Future<void> _fetchMe() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await api.me(); // {id, email, full_name, role}
      if (!mounted) return;
      setState(() => _me = data);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401')) {
        await api.clearToken();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          LoginPage.route,
          (_) => false,
        );
        return;
      }
      if (!mounted) return;
      setState(() => _error = 'Profil alınamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await api.logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, LoginPage.route, (_) => false);
  }

  String _initials(String nameOrEmail) {
    final t = nameOrEmail.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return t[0].toUpperCase();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<void> _openEditProfile() async {
    if (_me == null) return;
    final fullName0 = (_me!['full_name'] ?? '') as String? ?? '';
    final email0 = (_me!['email'] ?? '') as String? ?? '';

    final fullNameCtrl = TextEditingController(text: fullName0);
    final emailCtrl = TextEditingController(text: email0);
    final passwordCtrl = TextEditingController(); // opsiyonel-yeni şifre

    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool showPw = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDlg) {
            Future<void> save() async {
              if (!formKey.currentState!.validate()) return;
              setStateDlg(() => saving = true);
              try {
                final updated = await api.updateMe(
                  fullName: fullNameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  password: passwordCtrl.text.trim().isEmpty
                      ? null
                      : passwordCtrl.text.trim(),
                );
                if (!mounted) return;
                setState(() => _me = updated);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil güncellendi.')),
                );
              } catch (e) {
                setStateDlg(() => saving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Güncelleme başarısız: $e')),
                );
              }
            }

            return AlertDialog(
              title: const Text('Profili Düzenle'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: fullNameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Ad Soyad',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ad Soyad gerekli'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'E-posta gerekli';
                          final ok = RegExp(
                            r'^[^@]+@[^@]+\.[^@]+$',
                          ).hasMatch(t);
                          return ok ? null : 'Geçerli bir e-posta girin';
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: !showPw,
                        decoration: InputDecoration(
                          labelText: 'Yeni şifre (opsiyonel)',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              showPw ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () =>
                                setStateDlg(() => showPw = !showPw),
                          ),
                        ),

                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return null;
                          if (t.length < 6) return 'En az 6 karakter olmalı';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('İptal'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final fullName = (_me?['full_name'] ?? '') as String? ?? '';
    final email = (_me?['email'] ?? '') as String? ?? '';
    final role = (_me?['role'] ?? '') as String? ?? '';
    final displayName = fullName.isNotEmpty
        ? fullName
        : (email.isNotEmpty ? email : '—');
    final avatarText = _initials(displayName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _fetchMe,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMe,
        child: ListView(
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
                child: Text(
                  avatarText,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _chipBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  displayName,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  email,
                  style: tt.bodySmall?.copyWith(color: Colors.black54),
                ),
              ),
            ],
            if (role.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  role == 'admin' ? 'Yönetici' : 'Kullanıcı',
                  style: tt.bodySmall?.copyWith(color: Colors.black54),
                ),
              ),
            ],
            const SizedBox(height: 20),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ],

            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Profil Bilgilerini Güncelle'),
              onTap: _openEditProfile,
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
              onTap: _logout,
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
      ),
    );
  }
}
