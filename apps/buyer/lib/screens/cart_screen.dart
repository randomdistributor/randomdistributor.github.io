import 'package:flutter/material.dart';

import '../cart.dart';
import '../theme.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: ListenableBuilder(
        listenable: Cart.instance,
        builder: (context, _) {
          final lines = Cart.instance.lines;
          if (lines.isEmpty) {
            return const Center(child: Text('Your cart is empty.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: lines.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _CartTile(line: lines[i]),
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: Cart.instance,
        builder: (context, _) {
          if (Cart.instance.count == 0) return const SizedBox.shrink();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal', style: TextStyle(fontSize: 16)),
                      Text(money(Cart.instance.subtotal),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                    child: const Text('Checkout'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  final CartLine line;
  const _CartTile({required this.line});

  int get _min {
    if (!line.cartonOnly) return line.moq;
    return (line.moq / line.unitsPerCarton).ceil() * line.unitsPerCarton;
  }

  @override
  Widget build(BuildContext context) {
    final step = line.cartonOnly ? line.unitsPerCarton : 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.description ?? line.code,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('${money(line.sellingPrice)} × ${line.qty}'
                      '${line.cartonOnly ? '  (${(line.qty / line.unitsPerCarton).round()} cartons)' : ''}',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(money(line.lineTotal),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () {
                final next = line.qty - step;
                if (next >= _min) {
                  Cart.instance.setQty(line.productId, next);
                } else {
                  Cart.instance.remove(line.productId);
                }
              },
            ),
            Text('${line.qty}'),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                final next = line.qty + step;
                if (next <= line.availableQty) Cart.instance.setQty(line.productId, next);
              },
            ),
          ],
        ),
      ),
    );
  }
}
