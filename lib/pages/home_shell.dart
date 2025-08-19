import 'package:flutter/material.dart';
import 'garage_page.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

class HomeShell extends StatefulWidget {
  static const route = '/';
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
        ),
        title: Image.asset(
          'assets/logo.png',
          height: 35,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) {
            debugPrint('logo yüklenmedi: $error');
            return const Text('YALTES');
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(8),
          child: Divider(height: 1, thickness: 1),
        ),
      ),

      body: IndexedStack(
        index: _index,
        children: const [_QrPlaceholder(), GaragePage(), _CalPlaceholder()],
      ),

      bottomNavigationBar: CurvedNavigationBar(
        index: _index,
        height: 65,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        color: Theme.of(context).colorScheme.secondary,
        animationDuration: const Duration(milliseconds: 300),
        items: const [
          Icon(Icons.qr_code_2_outlined, size: 50, color: Colors.white),
          const ImageIcon(
            AssetImage('assets/garage.png'),
            size: 50,
            color: Colors.white,
          ),
          Icon(Icons.calendar_month, size: 50, color: Colors.white),
        ],
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder();

  @override
  Widget build(BuildContext context) {
    final card = Theme.of(context).cardTheme.color ?? const Color(0xFFEDEDED);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.qr_code_2, size: 180),
          ),
          const SizedBox(height: 12),
          Text(
            'Arabayı teslim almak için taratın',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _CalPlaceholder extends StatelessWidget {
  const _CalPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Takvim (yakında)'));
  }
}
