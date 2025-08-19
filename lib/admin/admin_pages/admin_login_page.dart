import 'package:flutter/material.dart';
import 'package:yaltes_car_app/services/api_client.dart';

class AdminLoginPage extends StatefulWidget {
  static const route = '/admin_login';
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool showPass = false;
  bool busy = false;
  String? errorText;

  final api = ApiClient.instance;

  static const _navy = Color(0xFF232B74);

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  InputDecoration _deco(String hint, {Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38),
      filled: true,
      fillColor: const Color(0xFFF2F3F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      prefixIcon: prefix,
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navy, width: 2),
      ),
    );
  }

  Future<void> _loginAdmin() async {
    setState(() {
      busy = true;
      errorText = null;
    });

    try {
      final e = email.text.trim();
      final p = pass.text.trim();

      if (e.isEmpty || p.isEmpty) {
        throw 'Email ve şifre gerekli';
      }

      await api.adminLogin(e, p);
      await api.saveToken();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Admin girişi başarılı')));
      Navigator.pushReplacementNamed(context, '/admin_home');
    } catch (err) {
      setState(() => errorText = err.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Giriş başarısız: $err')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/logo_dark.png',
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'YALTES',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),

            Positioned.fill(
              top: 120,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  children: [
                    Text(
                      'Admin Panel',
                      textAlign: TextAlign.center,
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 36),

                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _deco(
                        'Email',
                        prefix: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: pass,
                      obscureText: !showPass,
                      decoration: _deco(
                        'Şifre',
                        prefix: const Icon(Icons.lock_outline),
                        suffix: IconButton(
                          icon: Icon(
                            showPass ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => showPass = !showPass),
                          tooltip: showPass
                              ? 'Şifreyi gizle'
                              : 'Şifreyi göster',
                        ),
                      ),
                    ),

                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: busy ? null : _loginAdmin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F51B5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          busy ? 'GİRİŞ YAPILIYOR...' : 'GİRİŞ YAP',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
