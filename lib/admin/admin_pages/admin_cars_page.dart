import 'package:flutter/material.dart';
import 'package:yaltes_car_app/admin/admin_pages/add_vehicle_page.dart';
import 'package:yaltes_car_app/services/api_client.dart';
import 'package:yaltes_car_app/utils/url_helpers.dart';

class AdminCarsPage extends StatefulWidget {
  const AdminCarsPage({super.key});
  static const route = '/garage_home';

  @override
  State<AdminCarsPage> createState() => _AdminCarsPageState();
}

class _AdminCarsPageState extends State<AdminCarsPage> {
  final _search = TextEditingController();
  bool _loading = false;
  int _filterIndex = 0;
  List<Map<String, dynamic>> _cars = [];

  final api = ApiClient.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await api.listVehicles();
      _cars = list.cast<Map<String, dynamic>>();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Araçlar alınamadı: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteVehicle(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: const Text('Bu aracı kalıcı olarak sileceksiniz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await api.deleteVehicle(id);
      if (!mounted) return;
      setState(
        () => _cars.removeWhere((c) => (c['id'] ?? '').toString() == id),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Araç silindi')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Silme başarısız: $e')));
    }
  }

  void _editVehicle(Map<String, dynamic> car) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Düzenleme ekranı yakında')));
  }

  void _createVehicle() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Araç ekleme ekranı yakında')));
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final statusFilter = switch (_filterIndex) {
      1 => 'active',
      2 => 'maintenance',

      _ => null,
    };

    return _cars.where((c) {
      final plate = (c['plate'] ?? '').toString().toLowerCase();
      final brand = (c['brand'] ?? '').toString().toLowerCase();
      final model = (c['model'] ?? '').toString().toLowerCase();
      final status = (c['status'] ?? '').toString().toLowerCase();

      final matchesText =
          q.isEmpty ||
          plate.contains(q) ||
          brand.contains(q) ||
          model.contains(q);
      final matchesStatus = statusFilter == null || status == statusFilter;
      return matchesText && matchesStatus;
    }).toList();
  }

  Color _statusColor(BuildContext context, String status) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case 'active':
        return cs.tertiary;
      case 'maintenance':
        return cs.secondary;
      case 'retired':
        return cs.outline;
      default:
        return cs.error;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'maintenance':
        return 'Bakımda';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Araçlar',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: tt.titleLarge?.color,
                    ),
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Ekle'),
                  onPressed: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      AddVehiclePage.route,
                    );
                    if (result != null && context.mounted) {
                      await _load();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Plaka / Marka / Model ara',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor:
                    Theme.of(context).inputDecorationTheme.fillColor ??
                    cs.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'Tümü',
                  selected: _filterIndex == 0,
                  onTap: () => setState(() => _filterIndex = 0),
                ),
                _FilterChip(
                  label: 'Aktif',
                  selected: _filterIndex == 1,
                  onTap: () => setState(() => _filterIndex = 1),
                ),
                _FilterChip(
                  label: 'Bakımda',
                  selected: _filterIndex == 2,
                  onTap: () => setState(() => _filterIndex = 2),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    const Icon(Icons.directions_car, size: 56),
                    const SizedBox(height: 8),
                    Text('Kayıt bulunamadı', style: tt.bodyMedium),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, c) {
                  final maxW = c.maxWidth;
                  final crossCount = maxW >= 1000 ? 4 : (maxW >= 700 ? 3 : 2);
                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemBuilder: (_, i) {
                      final car = _filtered[i];
                      final plate = (car['plate'] ?? '').toString();
                      final brand = (car['brand'] ?? '').toString();
                      final model = (car['model'] ?? '').toString();
                      final status = (car['status'] ?? 'active').toString();
                      final img = (car['image_url'] ?? '').toString();
                      final id = (car['id'] ?? '').toString();

                      final rawImg = (car['image_url'] ?? '').toString();
                      final imgUrl = resolveImageUrl(rawImg);

                      debugPrint('ADMIN IMG raw="$rawImg" resolved="$imgUrl"');

                      return Card(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: imgUrl.isEmpty
                                        ? const Icon(
                                            Icons.directions_car,
                                            size: 48,
                                          )
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Image.network(
                                              imgUrl,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                    Icons.broken_image_outlined,
                                                  ),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  plate,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$brand $model',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.surfaceVariant,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 10,
                                            color: _statusColor(
                                              context,
                                              status,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _statusLabel(status),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: 'Düzenle',
                                      onPressed: () => _editVehicle(car),
                                      icon: const Icon(Icons.edit),
                                    ),
                                    IconButton(
                                      tooltip: 'Sil',
                                      onPressed: id.isEmpty
                                          ? null
                                          : () => _deleteVehicle(id),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.secondary : cs.surfaceVariant;
    final fg = selected ? cs.onSecondary : cs.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}
