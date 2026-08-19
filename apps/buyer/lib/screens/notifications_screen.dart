import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import 'product_detail_screen.dart';

/// In-app feed of new products broadcast to this buyer.
/// Rows come from the notifications queue; live price/image come from
/// buyer_catalog so products updated after the broadcast still show correctly.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<_Item>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_Item>> _load() async {
    final notifs = await supabase
        .from('notifications')
        .select('id, payload, created_at, read_at')
        .eq('template', 'new_product')
        .order('created_at', ascending: false)
        .limit(100);

    final rows = (notifs as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return [];

    // Catalog is small; fetch once and match locally (also drops products that
    // were since deleted or disabled).
    final catalog = await supabase.from('buyer_catalog').select('*');
    final byId = {
      for (final p in (catalog as List).cast<Map<String, dynamic>>()) p['id'] as String: p
    };

    final items = <_Item>[];
    for (final n in rows) {
      final pid = (n['payload'] as Map?)?['product_id'] as String?;
      final product = pid == null ? null : byId[pid];
      if (product == null) continue; // product no longer available
      items.add(_Item(
        product: product,
        createdAt: DateTime.tryParse('${n['created_at']}'),
        unread: n['read_at'] == null,
      ));
    }
    return items;
  }

  Future<void> _markAllRead() async {
    final me = await supabase
        .from('buyers')
        .select('id')
        .eq('profile_id', supabase.auth.currentUser!.id)
        .maybeSingle();
    if (me == null) return;
    await supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('recipient_type', 'buyer')
        .eq('recipient_id', me['id'])
        .isFilter('read_at', null);
  }

  Future<void> _refresh() async {
    final data = await _load();
    if (mounted) setState(() => _future = Future.value(data));
  }

  String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New products')),
      body: FutureBuilder<List<_Item>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('Nothing new yet.'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final it = items[i];
                final p = it.product;
                final img = p['primary_image_url'] as String?;
                return Card(
                  color: it.unread
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25)
                      : null,
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: img == null || img.isEmpty
                            ? Container(
                                color: const Color(0xFFEDEFF3),
                                child: const Icon(Icons.image_outlined, color: Colors.black26))
                            : CachedNetworkImage(imageUrl: img, fit: BoxFit.cover),
                      ),
                    ),
                    title: Text(p['description'] ?? p['product_code'] ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${money(p['selling_price'])} · ${_ago(it.createdAt)}'),
                    trailing: it.unread
                        ? const Icon(Icons.circle, size: 10, color: Colors.blue)
                        : const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // Opening the feed counts as seeing it; clear the badge on the way out.
    _markAllRead();
    super.dispose();
  }
}

class _Item {
  final Map<String, dynamic> product;
  final DateTime? createdAt;
  final bool unread;
  _Item({required this.product, required this.createdAt, required this.unread});
}
