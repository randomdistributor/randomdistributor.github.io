import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/party_forms.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = supabase
        .from('suppliers')
        .select('id, profile_id, name, business_name, gst_no, address, status')
        .order('name')
        .then((v) => (v as List).cast<Map<String, dynamic>>());
    setState(() {});
  }

  Future<void> _add() async {
    final ok = await showPartyCreateDialog(context, role: 'supplier');
    if (ok == true) _reload();
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    final ok = await showPartyEditDialog(context, role: 'supplier', row: row);
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add supplier'),
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
            return const Center(child: Text('No suppliers yet. Add one.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              return Card(
                child: ListTile(
                  title: Text(r['name'] ?? ''),
                  subtitle: Text([
                    if (r['business_name'] != null) r['business_name'],
                    if (r['gst_no'] != null) 'GST ${r['gst_no']}',
                  ].join('  ·  ')),
                  trailing: PartyRowActions(
                    profileId: r['profile_id'] as String?,
                    onEdit: () => _edit(r),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
