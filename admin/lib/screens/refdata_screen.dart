import 'package:flutter/material.dart';

import '../main.dart';

/// Manage the shared reference data: categories and brands.
/// Products point at these, so they live independently of any product.
class RefDataScreen extends StatefulWidget {
  const RefDataScreen({super.key});

  @override
  State<RefDataScreen> createState() => _RefDataScreenState();
}

class _RefDataScreenState extends State<RefDataScreen> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _brands = [];
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _categories = ((await supabase.from('categories').select('id, name').order('name')) as List)
        .cast<Map<String, dynamic>>();
    _brands = ((await supabase.from('brands').select('id, name').order('name')) as List)
        .cast<Map<String, dynamic>>();
    if (mounted) setState(() => _loading = false);
  }

  Future<String?> _prompt(String title, {String? initial}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _add(String table) async {
    final name = await _prompt(table == 'categories' ? 'New category' : 'New brand');
    if (name == null || name.isEmpty) return;
    try {
      await supabase.from(table).insert({'name': name});
      await _load();
    } catch (e) {
      setState(() => _message = 'Could not add "$name": already exists or not permitted.');
    }
  }

  Future<void> _rename(String table, Map<String, dynamic> row) async {
    final name = await _prompt('Rename', initial: row['name'] as String?);
    if (name == null || name.isEmpty) return;
    try {
      await supabase.from(table).update({'name': name}).eq('id', row['id']);
      await _load();
    } catch (e) {
      setState(() => _message = 'Could not rename: $e');
    }
  }

  Future<void> _delete(String table, Map<String, dynamic> row) async {
    final label = table == 'categories' ? 'category' : 'brand';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $label?'),
        content: Text('"${row['name']}" will be removed. Products using it keep working '
            'but will have no $label set.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from(table).delete().eq('id', row['id']);
      await _load();
    } catch (e) {
      setState(() => _message = 'Could not delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_message != null) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: Text(_message!)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _message = null),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _panel('Categories', 'categories', _categories),
              _panel('Brands', 'brands', _brands),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panel(String title, String table, List<Map<String, dynamic>> rows) {
    return SizedBox(
      width: 360,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _add(table),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Padding(padding: EdgeInsets.all(12), child: Text('None yet.'))
              else
                for (final r in rows)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r['name'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Rename',
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _rename(table, r),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _delete(table, r),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
