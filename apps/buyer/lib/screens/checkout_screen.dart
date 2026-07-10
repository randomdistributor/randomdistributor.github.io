import 'package:flutter/material.dart';

import '../cart.dart';
import '../main.dart';
import '../theme.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  Map<String, dynamic>? _org;
  bool _loading = true;
  bool _placing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrg();
  }

  Future<void> _loadOrg() async {
    try {
      _org = await supabase
          .from('organization')
          .select('system_name, upi_id, qr_image_url')
          .limit(1)
          .maybeSingle();
    } catch (_) {
      // organization is optional to display
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _placeOrder() async {
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      await supabase.rpc('place_order', params: {'p_items': Cart.instance.toRpcItems()});
      Cart.instance.clear();
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Order placed'),
          content: const Text('Your order has been sent. Track it under My orders.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context)..pop()..pop()..pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _error = _friendly('$e'));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  String _friendly(String raw) {
    if (raw.contains('below MOQ')) return 'A product is below its minimum order quantity.';
    if (raw.contains('multiple of carton')) return 'A product must be ordered in full cartons.';
    if (raw.contains('insufficient stock')) return 'A product no longer has enough stock.';
    return 'Could not place order. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Order summary', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        for (final l in Cart.instance.lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text('${l.description ?? l.code}  ×${l.qty}')),
                                Text(money(l.lineTotal)),
                              ],
                            ),
                          ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                            Text(money(Cart.instance.subtotal),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Payment', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pay ${_org?['system_name'] ?? 'the System'} after placing the order.'),
                        if (_org?['upi_id'] != null) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.qr_code, size: 20),
                            const SizedBox(width: 8),
                            SelectableText('UPI: ${_org!['upi_id']}'),
                          ]),
                        ],
                        const SizedBox(height: 6),
                        Text('The admin will confirm your payment.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline)),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _placing ? null : _placeOrder,
            child: _placing
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Place order · ${money(Cart.instance.subtotal)}'),
          ),
        ),
      ),
    );
  }
}
