import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<_Data> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final bal = await supabase
        .from('party_balances')
        .select('balance')
        .eq('party_type', 'supplier')
        .maybeSingle();
    final ledger = await supabase
        .from('ledger_entries')
        .select('type, amount, note, created_at, orders(order_no)')
        .eq('party_type', 'supplier')
        .order('created_at', ascending: false)
        .limit(200);
    return _Data(
      balance: (bal?['balance'] as num?)?.toDouble() ?? 0,
      entries: (ledger as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<void> _refresh() async {
    final d = await _load();
    setState(() => _future = Future.value(d));
  }

  String _label(String type) => switch (type) {
        'settlement' => 'Settlement (goods dispatched)',
        'payment_out' => 'Payment received from System',
        'payment_in' => 'Payment',
        _ => 'Adjustment',
      };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Data>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Failed to load: ${snap.error}'));
        }
        final data = snap.data!;
        final owed = data.balance >= 0;
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
                      Text(owed ? 'System owes you' : 'You owe System',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline)),
                      const SizedBox(height: 6),
                      Text(money(data.balance.abs()),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: owed ? Colors.green.shade700 : Colors.red.shade700,
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
                      title: Text(_label(e['type'] as String)),
                      subtitle: e['orders'] != null ? Text('Order #${e['orders']['order_no']}') : null,
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

class _Data {
  final double balance;
  final List<Map<String, dynamic>> entries;
  _Data({required this.balance, required this.entries});
}
