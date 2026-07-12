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
  late Future<_Data> _future;

  String get _orderId => widget.order['id'] as String;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final items = await supabase
        .from('order_items')
        .select('qty_ordered, buyer_unit_price, supplier_unit_price, line_total_buyer, '
            'line_total_supplier, products(product_code, description), suppliers(name)')
        .eq('order_id', _orderId);
    final payments = await supabase
        .from('payments')
        .select('id, amount, mode, direction, status, created_at')
        .eq('order_id', _orderId)
        .order('created_at');
    return _Data(
      items: (items as List).cast<Map<String, dynamic>>(),
      payments: (payments as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<void> _reload() async {
    final d = await _load();
    setState(() => _future = Future.value(d));
  }

  Future<void> _confirm(String paymentId, bool confirm) async {
    try {
      await supabase.rpc('confirm_payment',
          params: {'p_payment_id': paymentId, 'p_confirm': confirm});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(confirm ? 'Payment confirmed' : 'Payment rejected')));
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      appBar: AppBar(title: Text('Order #${o['order_no']}')),
      body: FutureBuilder<_Data>(
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
            padding: const EdgeInsets.all(24),
            children: [
              Text('Buyer: ${o['buyers']?['name'] ?? '—'}'),
              Text('Status: ${'${o['status']}'.replaceAll('_', ' ')}'),
              const SizedBox(height: 16),

              Text('Items', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Card(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Supplier')),
                    DataColumn(label: Text('Qty'), numeric: true),
                    DataColumn(label: Text('Buyer'), numeric: true),
                    DataColumn(label: Text('Supplier ₹'), numeric: true),
                  ],
                  rows: [
                    for (final it in data.items)
                      DataRow(cells: [
                        DataCell(Text(it['products']?['product_code'] ?? '')),
                        DataCell(Text(it['suppliers']?['name'] ?? '')),
                        DataCell(Text('${it['qty_ordered']}')),
                        DataCell(Text(money(it['line_total_buyer']))),
                        DataCell(Text(money(it['line_total_supplier']))),
                      ]),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Buyer total ${money(o['total_amount'])}'),
                      Text('Extra ${money(o['extra_charges'])}',
                          style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text('Payments', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              if (data.payments.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No payment submitted for this order yet.'),
                  ),
                )
              else
                for (final p in data.payments)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${money(p['amount'])} · ${p['mode']}',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('Status: ${p['status']}',
                                    style: TextStyle(
                                        color: p['status'] == 'confirmed'
                                            ? Colors.green.shade700
                                            : p['status'] == 'rejected'
                                                ? Colors.red.shade700
                                                : Colors.orange.shade800)),
                              ],
                            ),
                          ),
                          if (p['status'] == 'pending') ...[
                            OutlinedButton(
                              onPressed: () => _confirm(p['id'] as String, false),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => _confirm(p['id'] as String, true),
                              child: const Text('Confirm'),
                            ),
                          ],
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

class _Data {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> payments;
  _Data({required this.items, required this.payments});
}
