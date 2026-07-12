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
  double _credit = 0;
  bool _loading = true;
  bool _placing = false;
  String? _error;

  String _mode = 'upi_qr';
  bool _useCredit = false;
  final _amount = TextEditingController();

  double get _total => Cart.instance.subtotal;
  double get _appliedCredit => _useCredit ? _credit.clamp(0, _total).toDouble() : 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _org = await supabase
          .from('organization')
          .select('system_name, upi_id')
          .limit(1)
          .maybeSingle();
      final bal = await supabase
          .from('party_balances')
          .select('balance')
          .eq('party_type', 'buyer')
          .maybeSingle();
      final b = (bal?['balance'] as num?)?.toDouble() ?? 0;
      _credit = b > 0 ? b : 0;
    } catch (_) {}
    _amount.text = _total.toStringAsFixed(2);
    if (mounted) setState(() => _loading = false);
  }

  void _recomputeSuggested() {
    final due = (_total - _appliedCredit).clamp(0, _total).toDouble();
    _amount.text = due.toStringAsFixed(2);
  }

  Future<void> _placeOrder() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt > _total + 0.001) {
      setState(() => _error = 'Payment cannot exceed the order total.');
      return;
    }
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      await supabase.rpc('place_order', params: {
        'p_items': Cart.instance.toRpcItems(),
        'p_payment_mode': _mode,
        'p_payment_amount': amt,
      });
      Cart.instance.clear();
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Order placed'),
          content: const Text(
              'Your order and payment were sent. The admin will confirm your payment. '
              'Track it under My orders.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context)..pop()..pop()..pop(),
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
                            child: Row(children: [
                              Expanded(child: Text('${l.description ?? l.code}  ×${l.qty}')),
                              Text(money(l.lineTotal)),
                            ]),
                          ),
                        const Divider(),
                        _row('Total', money(_total), bold: true),
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
                        if (_credit > 0)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Use my wallet credit (${money(_credit)})'),
                            subtitle: const Text('Pay less now using your credit'),
                            value: _useCredit,
                            onChanged: (v) => setState(() {
                              _useCredit = v;
                              _recomputeSuggested();
                            }),
                          ),
                        DropdownButtonFormField<String>(
                          initialValue: _mode,
                          decoration: const InputDecoration(labelText: 'Payment mode'),
                          items: const [
                            DropdownMenuItem(value: 'upi_qr', child: Text('UPI / QR')),
                            DropdownMenuItem(value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                            DropdownMenuItem(value: 'online', child: Text('Online')),
                          ],
                          onChanged: (v) => setState(() => _mode = v!),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amount,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount paying now',
                            helperText: 'Up to ${money(_total)} — you can pay part now',
                          ),
                        ),
                        if (_org?['upi_id'] != null) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            const Icon(Icons.qr_code, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: SelectableText('Pay ${_org?['system_name'] ?? 'System'} · UPI: ${_org!['upi_id']}')),
                          ]),
                        ],
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
                : const Text('Place order'),
          ),
        ),
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 16) : null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(a, style: style), Text(b, style: style)],
    );
  }
}
