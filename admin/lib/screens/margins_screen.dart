import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

class MarginsScreen extends StatefulWidget {
  const MarginsScreen({super.key});

  @override
  State<MarginsScreen> createState() => _MarginsScreenState();
}

class _MarginsScreenState extends State<MarginsScreen> {
  // reference lists for target selection
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _rules = [];
  bool _loading = true;

  // form state
  String _scope = 'supplier';
  String? _targetId;
  String _type = 'percent';
  final _value = TextEditingController(text: '25');

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    _suppliers = ((await supabase.from('suppliers').select('id, name').order('name')) as List)
        .cast<Map<String, dynamic>>();
    _categories = ((await supabase.from('categories').select('id, name').order('name')) as List)
        .cast<Map<String, dynamic>>();
    _products = ((await supabase.from('products').select('id, product_code').order('product_code')) as List)
        .cast<Map<String, dynamic>>();
    _rules = ((await supabase
            .from('margin_rules')
            .select('id, scope, scope_ref_id, margin_type, margin_value, active')
            .order('scope')) as List)
        .cast<Map<String, dynamic>>();
    setState(() {
      _loading = false;
      _targetId = null;
    });
  }

  List<Map<String, dynamic>> get _targets {
    switch (_scope) {
      case 'supplier':
        return _suppliers;
      case 'category':
        return _categories;
      default:
        return _products; // product & product_override
    }
  }

  String _targetLabel(Map<String, dynamic> m) => m['name'] ?? m['product_code'] ?? m['id'];

  String _targetNameFor(String scope, String? refId) {
    Iterable<Map<String, dynamic>> src =
        scope == 'supplier' ? _suppliers : scope == 'category' ? _categories : _products;
    final m = src.where((e) => e['id'] == refId);
    return m.isEmpty ? '—' : _targetLabel(m.first);
  }

  Future<void> _addRule() async {
    final v = double.tryParse(_value.text.trim());
    if (_targetId == null || v == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a target and enter a value')),
      );
      return;
    }
    try {
      await supabase.from('margin_rules').upsert({
        'scope': _scope,
        'scope_ref_id': _targetId,
        'margin_type': _type,
        'margin_value': v,
        'active': true,
      }, onConflict: 'scope, scope_ref_id');
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _deleteRule(String id) async {
    await supabase.from('margin_rules').delete().eq('id', id);
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add margin rule',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                      'Resolution order when a product matches several: product override › product › category › supplier.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _box(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: _scope,
                          decoration: const InputDecoration(labelText: 'Scope'),
                          items: const [
                            DropdownMenuItem(value: 'supplier', child: Text('Supplier')),
                            DropdownMenuItem(value: 'category', child: Text('Category')),
                            DropdownMenuItem(value: 'product', child: Text('Product')),
                            DropdownMenuItem(value: 'product_override', child: Text('Product override')),
                          ],
                          onChanged: (v) => setState(() {
                            _scope = v!;
                            _targetId = null;
                          }),
                        ),
                      ),
                      _box(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          initialValue: _targetId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Target'),
                          items: [
                            for (final t in _targets)
                              DropdownMenuItem(
                                value: t['id'] as String,
                                child: Text(_targetLabel(t), overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) => setState(() => _targetId = v),
                        ),
                      ),
                      _box(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(value: 'percent', child: Text('Percent %')),
                            DropdownMenuItem(value: 'flat', child: Text('Flat ₹')),
                          ],
                          onChanged: (v) => setState(() => _type = v!),
                        ),
                      ),
                      _box(
                        width: 120,
                        child: TextField(
                          controller: _value,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Value'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      FilledButton(onPressed: _addRule, child: const Text('Save rule')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PreviewLine(type: _type, value: double.tryParse(_value.text) ?? 0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Existing rules', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_rules.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No rules yet.'),
            )
          else
            for (final r in _rules)
              Card(
                child: ListTile(
                  leading: _scopeChip(r['scope']),
                  title: Text(_targetNameFor(r['scope'], r['scope_ref_id'] as String?)),
                  subtitle: Text(r['margin_type'] == 'percent'
                      ? '+${r['margin_value']}%'
                      : '+${money(r['margin_value'])}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteRule(r['id'] as String),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _box({required double width, required Widget child}) =>
      SizedBox(width: width, child: child);

  Widget _scopeChip(String scope) {
    final label = switch (scope) {
      'supplier' => 'Supplier',
      'category' => 'Category',
      'product' => 'Product',
      _ => 'Override',
    };
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}

class _PreviewLine extends StatelessWidget {
  final String type;
  final double value;
  const _PreviewLine({required this.type, required this.value});

  @override
  Widget build(BuildContext context) {
    const sample = 200.0;
    final selling = type == 'percent' ? sample * (1 + value / 100) : sample + value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Preview: supplier ${money(sample)} → buyer ${money(selling)}'),
    );
  }
}
