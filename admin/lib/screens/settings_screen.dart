import 'package:flutter/material.dart';

import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _id;
  String? _message;

  final _systemName = TextEditingController();
  final _adminName = TextEditingController();
  final _adminPhone = TextEditingController();
  final _upi = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final row = await supabase
        .from('organization')
        .select('id, system_name, admin_name, admin_phone, upi_id')
        .limit(1)
        .maybeSingle();
    if (row != null) {
      _id = row['id'] as String?;
      _systemName.text = row['system_name'] ?? '';
      _adminName.text = row['admin_name'] ?? '';
      _adminPhone.text = row['admin_phone'] ?? '';
      _upi.text = row['upi_id'] ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final payload = {
      'system_name': _systemName.text.trim(),
      'admin_name': _adminName.text.trim(),
      'admin_phone': _adminPhone.text.trim(),
      'upi_id': _upi.text.trim(),
    };
    try {
      if (_id == null) {
        final inserted =
            await supabase.from('organization').insert(payload).select('id').single();
        _id = inserted['id'] as String?;
      } else {
        await supabase.from('organization').update(payload).eq('id', _id!);
      }
      setState(() => _message = 'Saved.');
    } catch (e) {
      setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('System identity',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Shown to both parties as the "System / Admin".',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 16),
                TextField(controller: _systemName, decoration: const InputDecoration(labelText: 'System name')),
                const SizedBox(height: 12),
                TextField(controller: _adminName, decoration: const InputDecoration(labelText: 'Admin display name')),
                const SizedBox(height: 12),
                TextField(controller: _adminPhone, decoration: const InputDecoration(labelText: 'Admin phone (single outbound number)')),
                const SizedBox(height: 12),
                TextField(controller: _upi, decoration: const InputDecoration(labelText: 'UPI ID (for buyer payments)')),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
