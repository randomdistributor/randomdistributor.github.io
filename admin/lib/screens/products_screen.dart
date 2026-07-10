import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = supabase
        .from('products')
        .select(
            'id, product_code, description, unit, available_qty, supplier_price, units_per_carton, sale_mode, moq, supplier_id, category_id, brand_id, suppliers(name)')
        .order('product_code')
        .then((v) => (v as List).cast<Map<String, dynamic>>());
    setState(() {});
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductDialog(row: row),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
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
            return const Center(child: Text('No products yet. Add one.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Qty'), numeric: true),
                  DataColumn(label: Text('Supplier price'), numeric: true),
                  DataColumn(label: Text('Carton/MOQ')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(cells: [
                      DataCell(Text(r['product_code'] ?? '')),
                      DataCell(Text(r['description'] ?? '')),
                      DataCell(Text((r['suppliers']?['name']) ?? '—')),
                      DataCell(Text('${r['available_qty']}')),
                      DataCell(Text(money(r['supplier_price']))),
                      DataCell(Text(r['sale_mode'] == 'carton_only'
                          ? '${r['units_per_carton']}/carton · MOQ ${r['moq']}'
                          : 'loose · MOQ ${r['moq']}')),
                      DataCell(IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(r),
                      )),
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

class _ProductDialog extends StatefulWidget {
  final Map<String, dynamic>? row;
  const _ProductDialog({this.row});

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _brands = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  late final _code = TextEditingController(text: widget.row?['product_code']);
  late final _desc = TextEditingController(text: widget.row?['description']);
  late final _unit = TextEditingController(text: widget.row?['unit'] ?? 'pcs');
  late final _qty = TextEditingController(text: '${widget.row?['available_qty'] ?? 0}');
  late final _price = TextEditingController(text: '${widget.row?['supplier_price'] ?? ''}');
  late final _carton = TextEditingController(text: '${widget.row?['units_per_carton'] ?? 1}');
  late final _moq = TextEditingController(text: '${widget.row?['moq'] ?? 1}');

  String? _supplierId;
  String? _categoryId;
  String? _brandId;
  String _saleMode = 'loose_allowed';

  @override
  void initState() {
    super.initState();
    _supplierId = widget.row?['supplier_id'];
    _categoryId = widget.row?['category_id'];
    _brandId = widget.row?['brand_id'];
    _saleMode = widget.row?['sale_mode'] ?? 'loose_allowed';
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    _suppliers = ((await supabase.from('suppliers').select('id, name').order('name')) as List)
        .cast<Map<String, dynamic>>();
    _categories = ((await supabase.from('categories').select('id, name').order('name')) as List)
        .cast<Map<String, dynamic>>();
    _brands = ((await supabase.from('brands').select('id, name').order('name')) as List)
        .cast<Map<String, dynamic>>();
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.trim());
    if (_code.text.trim().isEmpty || _supplierId == null || price == null) {
      setState(() => _error = 'Code, supplier and supplier price are required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final payload = {
      'supplier_id': _supplierId,
      'product_code': _code.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'category_id': _categoryId,
      'brand_id': _brandId,
      'unit': _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
      'available_qty': int.tryParse(_qty.text.trim()) ?? 0,
      'supplier_price': price,
      'units_per_carton': int.tryParse(_carton.text.trim()) ?? 1,
      'sale_mode': _saleMode,
      'moq': int.tryParse(_moq.text.trim()) ?? 1,
    };
    try {
      if (widget.row == null) {
        await supabase.from('products').insert(payload);
      } else {
        await supabase.from('products').update(payload).eq('id', widget.row!['id']);
      }
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
      title: Text(widget.row == null ? 'Add product' : 'Edit product'),
      content: SizedBox(
        width: 460,
        child: _loading
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _supplierId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Supplier *'),
                      items: [
                        for (final s in _suppliers)
                          DropdownMenuItem(value: s['id'] as String, child: Text(s['name'])),
                      ],
                      onChanged: (v) => setState(() => _supplierId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _code, decoration: const InputDecoration(labelText: 'Product code *')),
                    const SizedBox(height: 12),
                    TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _categoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: [
                            for (final c in _categories)
                              DropdownMenuItem(value: c['id'] as String, child: Text(c['name'])),
                          ],
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _brandId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Brand'),
                          items: [
                            for (final b in _brands)
                              DropdownMenuItem(value: b['id'] as String, child: Text(b['name'])),
                          ],
                          onChanged: (v) => setState(() => _brandId = v),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextField(controller: _qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Available qty'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Supplier price *'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit'))),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _saleMode,
                          decoration: const InputDecoration(labelText: 'Sale mode'),
                          items: const [
                            DropdownMenuItem(value: 'loose_allowed', child: Text('Loose allowed')),
                            DropdownMenuItem(value: 'carton_only', child: Text('Carton only')),
                          ],
                          onChanged: (v) => setState(() => _saleMode = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _carton, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Units/carton'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _moq, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'MOQ'))),
                    ]),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                  ],
                ),
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
