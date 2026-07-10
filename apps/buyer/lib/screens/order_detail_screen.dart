import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<_OrderData> _future;

  String get _orderId => widget.order['id'] as String;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OrderData> _load() async {
    final items = await supabase
        .from('buyer_order_items')
        .select('id, product_code, description, qty_ordered, buyer_unit_price, line_total_buyer')
        .eq('order_id', _orderId);
    final dispatches = await supabase
        .from('buyer_dispatches')
        .select('id, dispatch_no, status, dispatch_date, dispatch_copy_image_url')
        .eq('order_id', _orderId)
        .order('dispatch_no');
    return _OrderData(
      items: (items as List).cast<Map<String, dynamic>>(),
      dispatches: (dispatches as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<void> _reload() async {
    final d = await _load();
    setState(() => _future = Future.value(d));
  }

  Future<void> _confirmReceipt(Map<String, dynamic> dispatch) async {
    try {
      final buyer = await supabase
          .from('buyers')
          .select('id')
          .eq('profile_id', supabase.auth.currentUser!.id)
          .single();
      final dItems = await supabase
          .from('buyer_dispatch_items')
          .select('order_item_id, qty_dispatched')
          .eq('dispatch_id', dispatch['id']);

      final receipt = await supabase
          .from('receipts')
          .insert({
            'dispatch_id': dispatch['id'],
            'buyer_id': buyer['id'],
            'confirmed_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final rows = [
        for (final di in (dItems as List))
          {
            'receipt_id': receipt['id'],
            'order_item_id': di['order_item_id'],
            'qty_received': di['qty_dispatched'],
          }
      ];
      if (rows.isNotEmpty) await supabase.from('receipt_items').insert(rows);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Receipt confirmed')));
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.order['order_no']}')),
      body: FutureBuilder<_OrderData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Status: ${'${widget.order['status']}'.replaceAll('_', ' ')}'),
              const SizedBox(height: 12),
              Text('Items', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Card(
                child: Column(
                  children: [
                    for (final it in data.items)
                      ListTile(
                        title: Text(it['description'] ?? it['product_code'] ?? ''),
                        subtitle: Text('${money(it['buyer_unit_price'])} × ${it['qty_ordered']}'),
                        trailing: Text(money(it['line_total_buyer'])),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Dispatches', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              if (data.dispatches.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Not dispatched yet.'),
                  ),
                )
              else
                for (final d in data.dispatches)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Dispatch #${d['dispatch_no']}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Chip(
                                label: Text('${d['status']}'.replaceAll('_', ' ')),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          if (d['dispatch_date'] != null) Text('Date: ${d['dispatch_date']}'),
                          const SizedBox(height: 8),
                          if (d['status'] != 'received')
                            FilledButton.tonal(
                              onPressed: () => _confirmReceipt(d),
                              child: const Text('Confirm receipt'),
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderData {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> dispatches;
  _OrderData({required this.items, required this.dispatches});
}
