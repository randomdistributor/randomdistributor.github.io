import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'product_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  String _search = '';
  String? _brand;
  String? _category;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await supabase.from('buyer_catalog').select('*').order('product_code');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    final data = await _load();
    setState(() => _future = Future.value(data));
  }

  List<Map<String, dynamic>> _apply(List<Map<String, dynamic>> rows) {
    return rows.where((r) {
      if (_brand != null && r['brand_name'] != _brand) return false;
      if (_category != null && r['category_name'] != _category) return false;
      if (_search.isNotEmpty) {
        final hay = '${r['product_code']} ${r['description'] ?? ''}'.toLowerCase();
        if (!hay.contains(_search.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Failed to load catalog:\n${snap.error}',
              textAlign: TextAlign.center));
        }
        final all = snap.data!;
        final brands = all.map((e) => e['brand_name']).whereType<String>().toSet().toList()..sort();
        final cats = all.map((e) => e['category_name']).whereType<String>().toSet().toList()..sort();
        final items = _apply(all);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search products',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  _filterChip('All brands', _brand == null, () => setState(() => _brand = null)),
                  for (final b in brands)
                    _filterChip(b, _brand == b, () => setState(() => _brand = b)),
                  const SizedBox(width: 8),
                  _filterChip('All categories', _category == null, () => setState(() => _category = null)),
                  for (final c in cats)
                    _filterChip(c, _category == c, () => setState(() => _category = c)),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No products found.'))
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) => _ProductCard(row: items[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ProductCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final img = row['primary_image_url'] as String?;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: row)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: img == null || img.isEmpty
                  ? Container(
                      color: const Color(0xFFEDEFF3),
                      child: const Icon(Icons.image_outlined, size: 40, color: Colors.black26),
                    )
                  : CachedNetworkImage(
                      imageUrl: img,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: const Color(0xFFEDEFF3)),
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFFEDEFF3),
                        child: const Icon(Icons.broken_image_outlined, color: Colors.black26),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row['description'] ?? row['product_code'] ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(money(row['selling_price']),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                  Text('Qty ${row['available_qty']}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
