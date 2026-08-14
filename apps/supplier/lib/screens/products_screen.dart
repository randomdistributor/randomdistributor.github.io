import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = supabase
        .from('products')
        .select('id, product_code, description, available_qty, supplier_price, '
            'units_per_carton, sale_mode, moq, category_id, brand_id, '
            'product_images(url, is_primary, sort_order)')
        .order('product_code')
        .then((v) => (v as List).cast<Map<String, dynamic>>());
    setState(() {});
  }

  String? _primaryImage(Map<String, dynamic> p) {
    final imgs = (p['product_images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (imgs.isEmpty) return null;
    imgs.sort((a, b) {
      final pa = (a['is_primary'] == true) ? 0 : 1;
      final pb = (b['is_primary'] == true) ? 0 : 1;
      if (pa != pb) return pa - pb;
      return ((a['sort_order'] ?? 0) as int).compareTo((b['sort_order'] ?? 0) as int);
    });
    return imgs.first['url'] as String?;
  }

  Future<void> _open([Map<String, dynamic>? row]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: row)),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Add product'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('No products yet. Add your first one.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = rows[i];
                final img = _primaryImage(r);
                return Card(
                  child: ListTile(
                    onTap: () => _open(r),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: img == null
                            ? Container(
                                color: const Color(0xFFEDEFF3),
                                child: const Icon(Icons.image_outlined, color: Colors.black26))
                            : CachedNetworkImage(imageUrl: img, fit: BoxFit.cover),
                      ),
                    ),
                    title: Text(r['description'] ?? r['product_code'] ?? ''),
                    subtitle: Text('${r['product_code']} · Qty ${r['available_qty']} · ${money(r['supplier_price'])}'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
