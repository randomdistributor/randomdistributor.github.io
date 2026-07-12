import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<_WalletData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WalletData> _load() async {
    final bal = await supabase
        .from('party_balances')
        .select('balance')
        .eq('party_type', 'buyer')
        .maybeSingle();
    final ledger = await supabase
        .from('ledger_entries')
        .select('type, amount, note, created_at, order_id, orders(order_no)')
        .eq('party_type', 'buyer')
        .order('created_at', ascending: false)
        .limit(200);
    return _WalletData(
      balance: (bal?['balance'] as num?)?.toDouble() ?? 0,
      entries: (ledger as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<void> _refresh() async {
    final d = await _load();
    setState(() => _future = Future.value(d));
  }

  String _label(String type) => switch (type) {
        'order_charge' => 'Purchase',
        'payment_in' => 'Payment',
        'payment_out' => 'Payment out',
        'settlement' => 'Settlement',
        'credit' => 'Credit',
        _ => 'Adjustment',
      };

  IconData _icon(String type) => switch (type) {
        'order_charge' => Icons.shopping_bag_outlined,
        'payment_in' => Icons.south_west,
        'settlement' => Icons.done_all,
        _ => Icons.swap_horiz,
      };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WalletData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Failed to load: ${snap.error}'));
        }
        final data = snap.data!;
        final credit = data.balance >= 0;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(credit ? 'Wallet credit' : 'Amount due',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline)),
                      const SizedBox(height: 6),
                      Text(money(data.balance.abs()),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: credit ? Colors.green.shade700 : Colors.red.shade700,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Ledger', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              if (data.entries.isEmpty)
                const Padding(padding: EdgeInsets.all(12), child: Text('No transactions yet.'))
              else
                for (final e in data.entries)
                  Card(
                    child: ListTile(
                      dense: true,
                      leading: Icon(_icon(e['type'] as String)),
                      title: Text(_label(e['type'] as String)),
                      subtitle: Text(e['orders'] != null
                          ? 'Order #${e['orders']['order_no']}'
                          : (e['note'] ?? '').toString()),
                      trailing: Text(
                        money(e['amount']),
                        style: TextStyle(
                          color: (e['amount'] as num) >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _WalletData {
  final double balance;
  final List<Map<String, dynamic>> entries;
  _WalletData({required this.balance, required this.entries});
}
