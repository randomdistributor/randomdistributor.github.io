import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'dispatch_screen.dart';

class SupplierOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> supplierOrder;
  const SupplierOrderDetailScreen({super.key, required this.supplierOrder});

  @override
  State<SupplierOrderDetailScreen> createState() => _SupplierOrderDetailScreenState();
}

class _SupplierOrderDetailScreenState extends State<SupplierOrderDetailScreen> {
  late Future<_Data> _future;

  String get _soId => widget.supplierOrder['id'] as String;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final items = await supabase
        .from('supplier_order_items')
        .select('id, product_code, description, qty_ordered, supplier_unit_price, line_total_supplier')
        .eq('supplier_order_id', _soId);
    final dispatches = await supabase
        .from('dispatches')
        .select('id, dispatch_no, status, dispatch_date')
        .eq('supplier_order_id', _soId)
        .order('dispatch_no');
    return _Data(
      items: (items as List).cast<Map<String, dynamic>>(),
      dispatches: (dispatches as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<void> _reload() async {
    final d = await _load();
    setState(() => _future = Future.value(d));
  }

  @override
  Widget build(BuildContext context) {
    final so = widget.supplierOrder;
    return Scaffold(
      appBar: AppBar(title: Text('Order #${so['supplier_order_no']}')),
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
            padding: const EdgeInsets.all(16),
            children: [
              Text('From: System', style: Theme.of(context).textTheme.bodyMedium),
              Text('Status: ${'${so['status']}'.replaceAll('_', ' ')}'),
              const SizedBox(height: 16),
              Text('Items to pack', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Card(
                child: Column(
                  children: [
                    for (final it in data.items)
                      ListTile(
                        title: Text(it['description'] ?? it['product_code'] ?? ''),
                        subtitle: Text('${it['product_code']} · ${money(it['supplier_unit_price'])} × ${it['qty_ordered']}'),
                        trailing: Text(money(it['line_total_supplier'])),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Dispatches', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              if (data.dispatches.isEmpty)
                const Card(
                  child: Padding(padding: EdgeInsets.all(16), child: Text('No dispatches yet.')),
                )
              else
                for (final d in data.dispatches)
                  Card(
                    child: ListTile(
                      title: Text('Dispatch #${d['dispatch_no']}'),
                      subtitle: Text('${d['status']}'.replaceAll('_', ' ')),
                      trailing: Text('${d['dispatch_date'] ?? ''}'),
                    ),
                  ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Create dispatch'),
            onPressed: () async {
              final items = (await _future).items;
              if (!context.mounted) return;
              final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
                builder: (_) => DispatchScreen(supplierOrderId: _soId, items: items),
              ));
              if (done == true) _reload();
            },
          ),
        ),
      ),
    );
  }
}

class _Data {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> dispatches;
  _Data({required this.items, required this.dispatches});
}
