import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'order_detail_screen.dart';

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
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await supabase
        .from('orders')
        .select('id, order_no, status, total_amount, created_at')
        .order('order_no', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    final data = await _load();
    setState(() => _future = Future.value(data));
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
          return const Center(child: Text('No orders yet.'));
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              return Card(
                child: ListTile(
                  title: Text('Order #${r['order_no']}'),
                  subtitle: Text('${r['status']}'.replaceAll('_', ' ')),
                  trailing: Text(money(r['total_amount']),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(order: r),
                  )).then((_) => _refresh()),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
