import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'supplier_order_detail_screen.dart';

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
    _reload();
  }

  void _reload() {
    _future = supabase
        .from('supplier_orders')
        .select('id, supplier_order_no, status, total_supplier_value, created_at')
        .order('supplier_order_no', ascending: false)
        .then((v) => (v as List).cast<Map<String, dynamic>>());
    setState(() {});
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
          return const Center(child: Text('No orders from the System yet.'));
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              return Card(
                child: ListTile(
                  title: Text('Order #${r['supplier_order_no']}'),
                  subtitle: Text('${r['status']}'.replaceAll('_', ' ')),
                  trailing: Text(money(r['total_supplier_value']),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(
                        builder: (_) => SupplierOrderDetailScreen(supplierOrder: r),
                      ))
                      .then((_) => _reload()),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
