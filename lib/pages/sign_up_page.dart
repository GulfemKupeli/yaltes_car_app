import 'package:flutter/material.dart';
import 'package:yaltes_car_app/pages/login_page.dart';
import 'package:yaltes_car_app/services/api_client.dart';

final api = ApiClient.instance;

class SignUpPage extends StatefulWidget {
  static const route = '/sign-up';
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();

  bool showPass = false;
  bool busy = false;
  String? errorText;
  String? okText;

  Future<void> _register() async {
    setState(() {
      busy = true;
      errorText = null;
      okText = null;
    });
    try {
      await api.register(
        fullName: name.text.trim(),
        email: email.text.trim(),
        password: pass.text.trim(),
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıt başarılı! Şimdi giriş yapın.')),
      );

      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      setState(() => errorText = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  InputDecoration _deco(BuildContext context, String label, {Widget? suffix}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade200,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Color(0xFF232B74),
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
                      'Yeni Hesap Oluştur',
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 40),
                    TextField(
                      controller: name,
                      decoration: _deco(context, 'İsim'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: email,
                      decoration: _deco(context, 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pass,
                      obscureText: !showPass,
                      decoration: _deco(
                        context,
                        'Şifre',
                        suffix: IconButton(
                          icon: Icon(
                            showPass ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => showPass = !showPass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (errorText != null)
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    if (okText != null)
                      Text(
                        okText!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: busy ? null : _register,
                        child: Text(
                          busy ? 'KAYIT YAPILIYOR...' : 'KAYIT OL',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Zaten bir hesabın var mı?   ',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.black87,
                          ), // ▲
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, LoginPage.route),
                          child: const Text('Giriş yap'),
                        ),
                      ],
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
