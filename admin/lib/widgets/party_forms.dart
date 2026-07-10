import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

/// Shared create/edit/reset-PIN UI for suppliers and buyers.
/// Creation calls the `admin-provision` Edge Function (mobile + PIN login);
/// editing updates the record directly.

bool _isSupplier(String role) => role == 'supplier';

/// Pulls a human message out of an Edge Function error or any exception.
String _errText(Object e) {
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) return '${d['error']}';
    return 'Request failed (${e.status}).';
  }
  return '$e';
}

Future<bool?> showPartyCreateDialog(BuildContext context, {required String role}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _PartyCreateDialog(role: role),
  );
}

Future<bool?> showPartyEditDialog(BuildContext context,
    {required String role, required Map<String, dynamic> row}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _PartyEditDialog(role: role, row: row),
  );
}

class PartyRowActions extends StatelessWidget {
  final String? profileId;
  final VoidCallback onEdit;
  const PartyRowActions({super.key, required this.profileId, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'pin' && profileId != null) {
              showDialog(context: context, builder: (_) => _ResetPinDialog(userId: profileId!));
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'pin',
              enabled: profileId != null,
              child: Text(profileId == null ? 'No login (created directly)' : 'Reset PIN'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PartyCreateDialog extends StatefulWidget {
  final String role;
  const _PartyCreateDialog({required this.role});

  @override
  State<_PartyCreateDialog> createState() => _PartyCreateDialogState();
}

class _PartyCreateDialogState extends State<_PartyCreateDialog> {
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _gst = TextEditingController();
  final _address = TextEditingController();
  final _mobile = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _mobile.text.trim().isEmpty || _pin.text.trim().length < 4) {
      setState(() => _error = 'Name, mobile and a 4+ digit PIN are required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.functions.invoke('admin-provision', body: {
        'action': 'create_party',
        'role': widget.role,
        'name': _name.text.trim(),
        'mobile': _mobile.text.trim(),
        'pin': _pin.text.trim(),
        'business_name': _business.text.trim().isEmpty ? null : _business.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        if (_isSupplier(widget.role))
          'gst_no': _gst.text.trim().isEmpty ? null : _gst.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = _errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _isSupplier(widget.role) ? 'supplier' : 'buyer';
    return AlertDialog(
      title: Text('Add $label'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 12),
              TextField(controller: _business, decoration: const InputDecoration(labelText: 'Business name')),
              if (_isSupplier(widget.role)) ...[
                const SizedBox(height: 12),
                TextField(controller: _gst, decoration: const InputDecoration(labelText: 'GST no.')),
              ],
              const SizedBox(height: 12),
              TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
              const Divider(height: 28),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Login', style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile *'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _pin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Initial PIN *'))),
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
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _PartyEditDialog extends StatefulWidget {
  final String role;
  final Map<String, dynamic> row;
  const _PartyEditDialog({required this.role, required this.row});

  @override
  State<_PartyEditDialog> createState() => _PartyEditDialogState();
}

class _PartyEditDialogState extends State<_PartyEditDialog> {
  late final _name = TextEditingController(text: widget.row['name']);
  late final _business = TextEditingController(text: widget.row['business_name']);
  late final _gst = TextEditingController(text: widget.row['gst_no']);
  late final _address = TextEditingController(text: widget.row['address']);
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final table = _isSupplier(widget.role) ? 'suppliers' : 'buyers';
    final payload = {
      'name': _name.text.trim(),
      'business_name': _business.text.trim().isEmpty ? null : _business.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      if (_isSupplier(widget.role))
        'gst_no': _gst.text.trim().isEmpty ? null : _gst.text.trim(),
    };
    try {
      await supabase.from(table).update(payload).eq('id', widget.row['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = _errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _isSupplier(widget.role) ? 'supplier' : 'buyer';
    return AlertDialog(
      title: Text('Edit $label'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name *')),
            const SizedBox(height: 12),
            TextField(controller: _business, decoration: const InputDecoration(labelText: 'Business name')),
            if (_isSupplier(widget.role)) ...[
              const SizedBox(height: 12),
              TextField(controller: _gst, decoration: const InputDecoration(labelText: 'GST no.')),
            ],
            const SizedBox(height: 12),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
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

class _ResetPinDialog extends StatefulWidget {
  final String userId;
  const _ResetPinDialog({required this.userId});

  @override
  State<_ResetPinDialog> createState() => _ResetPinDialogState();
}

class _ResetPinDialogState extends State<_ResetPinDialog> {
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _done;

  Future<void> _save() async {
    if (_pin.text.trim().length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.functions.invoke('admin-provision', body: {
        'action': 'reset_pin',
        'user_id': widget.userId,
        'pin': _pin.text.trim(),
      });
      setState(() => _done = 'PIN updated.');
    } catch (e) {
      setState(() => _error = _errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset PIN'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _pin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'New PIN')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_done != null) ...[
              const SizedBox(height: 12),
              Text(_done!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Update'),
        ),
      ],
    );
  }
}
