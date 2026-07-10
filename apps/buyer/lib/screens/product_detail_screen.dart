import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../cart.dart';
import '../theme.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final Map<String, dynamic> p = widget.product;
  late final bool cartonOnly = p['sale_mode'] == 'carton_only';
  late final int perCarton = (p['units_per_carton'] as int?) ?? 1;
  late final int moq = (p['moq'] as int?) ?? 1;
  late final int available = (p['available_qty'] as int?) ?? 0;
  late final int step = cartonOnly ? perCarton : 1;
  late int qty;

  @override
  void initState() {
    super.initState();
    qty = _minQty();
    final existing = Cart.instance.qtyFor(p['id'] as String);
    if (existing > 0) qty = existing;
  }

  int _minQty() {
    if (!cartonOnly) return moq;
    // smallest carton-multiple that is >= moq
    final multiples = (moq / perCarton).ceil();
    return multiples * perCarton;
  }

  void _dec() {
    final next = qty - step;
    if (next >= _minQty()) setState(() => qty = next);
  }

  void _inc() {
    final next = qty + step;
    if (next <= available) setState(() => qty = next);
  }

  void _addToCart() {
    Cart.instance.addOrUpdate(CartLine(
      productId: p['id'] as String,
      code: p['product_code'] as String? ?? '',
      description: p['description'] as String?,
      sellingPrice: (p['selling_price'] as num?)?.toDouble() ?? 0,
      unitsPerCarton: perCarton,
      cartonOnly: cartonOnly,
      moq: moq,
      availableQty: available,
      imageUrl: p['primary_image_url'] as String?,
      qty: qty,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $qty to cart'), duration: const Duration(seconds: 1)),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final img = p['primary_image_url'] as String?;
    final cartons = cartonOnly ? (qty / perCarton).round() : null;
    return Scaffold(
      appBar: AppBar(title: Text(p['product_code'] ?? 'Product')),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: img == null || img.isEmpty
                ? Container(
                    color: const Color(0xFFEDEFF3),
                    child: const Icon(Icons.image_outlined, size: 64, color: Colors.black26),
                  )
                : CachedNetworkImage(imageUrl: img, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['description'] ?? p['product_code'] ?? '',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  if (p['brand_name'] != null) Chip(label: Text('${p['brand_name']}')),
                  if (p['category_name'] != null) Chip(label: Text('${p['category_name']}')),
                ]),
                const SizedBox(height: 8),
                Text(money(p['selling_price']),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Available: $available'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  Chip(
                    avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text(cartonOnly ? 'Carton of $perCarton · carton only' : 'Loose allowed'),
                  ),
                  Chip(label: Text('MOQ $moq')),
                ]),
                const SizedBox(height: 20),
                _qtySelector(cartons),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: available < _minQty() ? null : _addToCart,
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(available < _minQty()
                ? 'Out of stock'
                : 'Add to cart · ${money((p['selling_price'] as num? ?? 0) * qty)}'),
          ),
        ),
      ),
    );
  }

  Widget _qtySelector(int? cartons) {
    return Row(
      children: [
        Text(cartonOnly ? 'Cartons' : 'Quantity',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const Spacer(),
        IconButton.filledTonal(onPressed: _dec, icon: const Icon(Icons.remove)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Text('${cartonOnly ? cartons : qty}',
                  style: Theme.of(context).textTheme.titleLarge),
              if (cartonOnly)
                Text('$qty units',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
            ],
          ),
        ),
        IconButton.filledTonal(onPressed: _inc, icon: const Icon(Icons.add)),
      ],
    );
  }
}
