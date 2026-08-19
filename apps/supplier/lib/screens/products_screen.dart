import '../widgets/product_image.dart';
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

  /// Products used in past orders can't be deleted (order history references them);
  /// offer to disable instead so they disappear from the buyer catalog.
  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('"${row['product_code']}" and its images will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('products').delete().eq('id', row['id']);
      _reload();
    } catch (e) {
      if (!mounted) return;
      final disable = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot delete'),
          content: const Text('This product is used in existing orders. Disable it instead? '
              'It will be hidden from buyers and order history stays intact.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disable')),
          ],
        ),
      );
      if (disable == true) {
        await supabase.from('products').update({'status': 'disabled'}).eq('id', row['id']);
        _reload();
      }
    }
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
                        child: ProductImage(url: img),
                      ),
                    ),
                    title: Text(r['description'] ?? r['product_code'] ?? ''),
                    subtitle: Text('${r['product_code']} · Qty ${r['available_qty']} · ${money(r['supplier_price'])}'),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(r),
                    ),
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
