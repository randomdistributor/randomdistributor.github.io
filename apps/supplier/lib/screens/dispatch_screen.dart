import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../services/images.dart';

class DispatchScreen extends StatefulWidget {
  final String supplierOrderId;
  final List<Map<String, dynamic>> items;
  const DispatchScreen({super.key, required this.supplierOrderId, required this.items});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  late final Map<String, TextEditingController> _qty = {
    for (final it in widget.items)
      it['id'] as String: TextEditingController(text: '${it['qty_ordered']}'),
  };

  String? _copyUrl;
  String? _billUrl;
  bool _uploadingCopy = false;
  bool _uploadingBill = false;
  bool _busy = false;
  String? _error;

  Future<void> _upload({required bool bill}) async {
    setState(() {
      if (bill) {
        _uploadingBill = true;
      } else {
        _uploadingCopy = true;
      }
    });
    try {
      final url = await ImageService.pickAndUpload(
        bucket: 'dispatch-docs',
        folder: widget.supplierOrderId,
        source: ImageSource.gallery,
      );
      if (url != null) {
        setState(() {
          if (bill) {
            _billUrl = url;
          } else {
            _copyUrl = url;
          }
        });
      }
    } catch (e) {
      setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingBill = false;
          _uploadingCopy = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    // build dispatch items with qty > 0
    final lines = <Map<String, dynamic>>[];
    for (final it in widget.items) {
      final q = int.tryParse(_qty[it['id']]!.text.trim()) ?? 0;
      final ordered = (it['qty_ordered'] as int?) ?? 0;
      if (q < 0 || q > ordered) {
        setState(() => _error = 'Dispatch qty for ${it['product_code']} must be 0..$ordered');
        return;
      }
      if (q > 0) {
        lines.add({
          'order_item_id': it['id'],
          'qty_dispatched': q,
          'unit_price': it['supplier_unit_price'],
        });
      }
    }
    if (lines.isEmpty) {
      setState(() => _error = 'Enter a dispatch quantity for at least one item.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dispatch = await supabase
          .from('dispatches')
          .insert({
            'supplier_order_id': widget.supplierOrderId,
            'status': 'dispatched',
            'dispatch_date': DateTime.now().toIso8601String().substring(0, 10),
            'dispatch_copy_image_url': _copyUrl,
            'dispatch_bill_image_url': _billUrl,
          })
          .select('id')
          .single();

      final dispatchId = dispatch['id'] as String;
      await supabase.from('dispatch_items').insert([
        for (final l in lines) {...l, 'dispatch_id': dispatchId},
      ]);

      await supabase
          .from('supplier_orders')
          .update({'status': 'partially_dispatched'})
          .eq('id', widget.supplierOrderId);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create dispatch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Quantities to dispatch', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                for (final it in widget.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it['description'] ?? it['product_code'] ?? ''),
                              Text('Ordered ${it['qty_ordered']}',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _qty[it['id']],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Documents', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _docTile('Dispatch copy', _copyUrl, _uploadingCopy, () => _upload(bill: false))),
              const SizedBox(width: 12),
              Expanded(child: _docTile('Dispatch bill', _billUrl, _uploadingBill, () => _upload(bill: true))),
            ],
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
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Dispatch'),
          ),
        ),
      ),
    );
  }

  Widget _docTile(String label, String? url, bool uploading, VoidCallback onTap) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          color: Colors.white,
        ),
        child: Center(
          child: uploading
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(url == null ? Icons.upload_file : Icons.check_circle,
                        color: url == null
                            ? Theme.of(context).colorScheme.primary
                            : Colors.green),
                    const SizedBox(height: 6),
                    Text(url == null ? label : '$label ✓',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
        ),
      ),
    );
  }
}
