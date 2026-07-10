import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = supabase
        .from('orders')
        .select('id, order_no, status, subtotal, extra_charges, total_amount, buyers(name)')
        .order('order_no', ascending: false)
        .then((v) => (v as List).cast<Map<String, dynamic>>());
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
          return Center(child: Text('Failed to load: ${snap.error}'));
        }
        final rows = snap.data!;
        if (rows.isEmpty) {
          return const Center(
            child: Text('No orders yet. They appear here once buyers check out.'),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Order')),
                DataColumn(label: Text('Buyer')),
                DataColumn(label: Text('Total'), numeric: true),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(Text('#${r['order_no']}')),
                    DataCell(Text((r['buyers']?['name']) ?? '—')),
                    DataCell(Text(money(r['total_amount']))),
                    DataCell(_StatusChip(r['status'] as String)),
                  ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.replaceAll('_', ' ')),
      visualDensity: VisualDensity.compact,
    );
  }
}
