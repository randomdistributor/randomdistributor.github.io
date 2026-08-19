import 'package:flutter/material.dart';

import '../main.dart';
import '../cart.dart';
import '../screens/catalog_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/notifications_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _unread = 0;

  static const _titles = ['Catalog', 'My orders', 'Wallet'];
  static const _pages = [CatalogScreen(), OrdersScreen(), WalletScreen()];

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final rows = await supabase
          .from('notifications')
          .select('id')
          .eq('template', 'new_product')
          .isFilter('read_at', null);
      if (mounted) setState(() => _unread = (rows as List).length);
    } catch (_) {
      // notifications are non-critical; ignore failures
    }
  }

  void _openCart() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    _loadUnread();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          _badged(
            count: _unread,
            icon: Icons.notifications_none,
            onPressed: _openNotifications,
            color: Colors.orange,
          ),
          ListenableBuilder(
            listenable: Cart.instance,
            builder: (context, _) => _badged(
              count: Cart.instance.count,
              icon: Icons.shopping_cart_outlined,
              onPressed: _openCart,
              color: Colors.red,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), label: 'Catalog'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
        ],
      ),
    );
  }

  Widget _badged({
    required int count,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(icon: Icon(icon), onPressed: onPressed),
        if (count > 0)
          Positioned(
            right: 4,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}
