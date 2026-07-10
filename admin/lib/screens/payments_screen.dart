import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

/// Records admin-entered payments (cash / UPI-QR / bank / online).
/// A DB trigger turns each payment into a ledger entry automatically.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = supabase
        .from('payments')
        .select('id, party_type, amount, direction, mode, reference_no, paid_on')
        .order('created_at', ascending: false)
        .limit(100)
        .then((v) => (v as List).cast<Map<String, dynamic>>());
    setState(() {});
  }

  Future<void> _add() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _PaymentDialog(),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Record payment'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
            return const Center(child: Text('No payments recorded yet.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Party')),
                  DataColumn(label: Text('Direction')),
                  DataColumn(label: Text('Mode')),
                  DataColumn(label: Text('Amount'), numeric: true),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(cells: [
                      DataCell(Text('${r['paid_on']}')),
                      DataCell(Text(r['party_type'])),
                      DataCell(Text(r['direction'])),
                      DataCell(Text(r['mode'])),
                      DataCell(Text(money(r['amount']))),
                    ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog();

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String _partyType = 'buyer';
  List<Map<String, dynamic>> _parties = [];
  String? _partyId;
  String _direction = 'in';
  String _mode = 'upi_qr';
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  Future<void> _loadParties() async {
    final table = _partyType == 'buyer' ? 'buyers' : 'suppliers';
    _parties = ((await supabase.from(table).select('id, name').order('name')) as List)
        .cast<Map<String, dynamic>>();
    setState(() {
      _loading = false;
      _partyId = null;
    });
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim());
    if (_partyId == null || amt == null || amt <= 0) {
      setState(() => _error = 'Pick a party and enter a valid amount');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.from('payments').insert({
        'party_type': _partyType,
        'party_id': _partyId,
        'amount': amt,
        'direction': _direction,
        'mode': _mode,
        'reference_no': _ref.text.trim().isEmpty ? null : _ref.text.trim(),
        'entered_by': supabase.auth.currentUser?.id,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record payment'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _partyType,
              decoration: const InputDecoration(labelText: 'Party type'),
              items: const [
                DropdownMenuItem(value: 'buyer', child: Text('Buyer')),
                DropdownMenuItem(value: 'supplier', child: Text('Supplier')),
              ],
              onChanged: (v) {
                setState(() {
                  _partyType = v!;
                  _loading = true;
                  // buyers pay in; suppliers are paid out — sensible default
                  _direction = v == 'buyer' ? 'in' : 'out';
                });
                _loadParties();
              },
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
            else
              DropdownButtonFormField<String>(
                initialValue: _partyId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Party'),
                items: [
                  for (final p in _parties)
                    DropdownMenuItem(value: p['id'] as String, child: Text(p['name'])),
                ],
                onChanged: (v) => setState(() => _partyId = v),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _direction,
                  decoration: const InputDecoration(labelText: 'Direction'),
                  items: const [
                    DropdownMenuItem(value: 'in', child: Text('In (received)')),
                    DropdownMenuItem(value: 'out', child: Text('Out (paid)')),
                  ],
                  onChanged: (v) => setState(() => _direction = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'Mode'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi_qr', child: Text('UPI / QR')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank')),
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                    DropdownMenuItem(value: 'adjustment', child: Text('Adjustment')),
                  ],
                  onChanged: (v) => setState(() => _mode = v!),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount *'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Reference no.'))),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
