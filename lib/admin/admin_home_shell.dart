import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:yaltes_car_app/admin/admin_pages/admin_cars_page.dart';

class AdminHomeShell extends StatefulWidget {
  static const route = '/admin_home';
  final int initialIndex;
  const AdminHomeShell({super.key, this.initialIndex = 0});

  @override
  State<AdminHomeShell> createState() => _AdminHomeShellState();
}

class _AdminHomeShellState extends State<AdminHomeShell> {
  int _index = 0;

  late final List<Widget> _pages = const [
    AdminCarsPage(),
    AdminQrPage(),
    AdminEditCarsPage(),
    AdminAppointmentsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          title: Image.asset(
            'assets/logo.png',
            height: 42,
            fit: BoxFit.contain,
          ),
          centerTitle: true,
          elevation: 0,
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
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: CurvedNavigationBar(
          index: _index,
          height: 60,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          color: Theme.of(context).colorScheme.secondary,
          animationDuration: const Duration(milliseconds: 300),
          items: const [
            const ImageIcon(
              AssetImage('assets/garage.png'),
              size: 50,
              color: Colors.white,
            ),
            Icon(Icons.qr_code_2_outlined, size: 50, color: Colors.white),
            Icon(Icons.calendar_month, size: 50, color: Colors.white),
          ],
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

class AdminQrPage extends StatelessWidget {
  const AdminQrPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("QR ile Teslim Sayfası"));
  }
}

class AdminEditCarsPage extends StatelessWidget {
  const AdminEditCarsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Araç Düzenleme Sayfası"));
  }
}

class AdminAppointmentsPage extends StatelessWidget {
  const AdminAppointmentsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Randevular Sayfası"));
  }
}
