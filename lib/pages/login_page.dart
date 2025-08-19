import 'package:flutter/material.dart';
import 'package:yaltes_car_app/admin/admin_pages/admin_login_page.dart';
import 'package:yaltes_car_app/services/api_client.dart';
import 'package:yaltes_car_app/pages/home_shell.dart';
import 'package:yaltes_car_app/pages/sign_up_page.dart';

class LoginPage extends StatefulWidget {
  static const route = '/login';
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool remember = true;
  bool showPass = false;
  bool busy = false;
  String? errorText;

  final api = ApiClient.instance;

  static const _navy = Color(0xFF232B74);
  static const _indigo = Color(0xFF3F51B5);
  static const _fieldFill = Color(0xFFF2F3F7);
  static const _hint = Colors.black54;

  @override
  void initState() {
    super.initState();
    api.loadToken().then((ok) async {
      if (!mounted || !ok) return;
      try {
        await api.me();
        if (mounted) _goHome();
      } catch (_) {}
    });
  }

  void _goHome() => Navigator.of(context).pushReplacementNamed(HomeShell.route);

  Future<void> _login() async {
    setState(() {
      busy = true;
      errorText = null;
    });
    try {
      await api.login(email.text.trim(), pass.text.trim());
      if (remember) await api.saveToken();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Giriş başarılı')));

      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeShell.route,
        (route) => false,
      );
    } catch (e) {
      setState(() => errorText = e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Giriş başarısız: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  InputDecoration _fieldDeco(
    String hintText, {
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.black38),
      filled: true,
      fillColor: _fieldFill,
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _navy,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 130,
                top: 55,
                child: Image.asset(
                  'assets/logo_dark.png',
                  height: 50,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'YALTES',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),

              Positioned.fill(
                top: 175,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
                    children: [
                      Text(
                        'Hoşgeldiniz',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Devam etmek için giriş yap',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(color: _hint),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Email',
                        style: textTheme.labelMedium?.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDeco(
                          'Email',
                          prefix: const Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Şifre',
                        style: textTheme.labelMedium?.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: pass,
                        obscureText: !showPass,
                        decoration: _fieldDeco(
                          'şifre',
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => showPass = !showPass),
                            icon: Icon(
                              showPass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            tooltip: showPass
                                ? 'Şifreyi gizle'
                                : 'Şifreyi göster',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Checkbox(
                              value: remember,
                              onChanged: (v) =>
                                  setState(() => remember = v ?? true),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              activeColor: _navy,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Beni hatırla',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                            ), // ▲
                          ),
                          const Spacer(),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {},
                            child: const Text('Şifremi unuttum'),
                          ),
                        ],
                      ),

                      if (errorText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: busy ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _indigo,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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

                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Hesabın yok mu?   ',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                            ), // ▲
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, SignUpPage.route),
                            child: const Text('Yeni hesap oluştur'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 190),
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 230.0),
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AdminLoginPage.route,
                                );
                              },
                              icon: const Icon(
                                Icons.lock_person_outlined,
                                color: Colors.black87,
                              ),
                              label: const Text("Admin Girişi"),
                              style: TextButton.styleFrom(
                                backgroundColor: Color(0xFFBBDEFB),
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
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
      ),
    );
  }
}
