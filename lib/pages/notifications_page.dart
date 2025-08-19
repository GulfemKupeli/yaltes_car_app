import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  static const route = '/notifications';
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, index) {
          return ListTile(
            leading: const Icon(Icons.notifications),
            title: Text('Bildirim ${index + 1}'),
            subtitle: const Text('Bu, örnek bir bildirim metnidir.'),
            onTap: () {},
          );
        },
        separatorBuilder: (_, __) => const Divider(),
        itemCount: 10,
      ),
    );
  }
}
