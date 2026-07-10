import 'package:flutter/material.dart';

import '../main.dart';
import '../screens/dashboard_screen.dart';
import '../screens/suppliers_screen.dart';
import '../screens/buyers_screen.dart';
import '../screens/products_screen.dart';
import '../screens/margins_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/settings_screen.dart';

class _Dest {
  final String label;
  final IconData icon;
  final Widget page;
  const _Dest(this.label, this.icon, this.page);
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _dests = <_Dest>[
    _Dest('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
    _Dest('Suppliers', Icons.local_shipping_outlined, SuppliersScreen()),
    _Dest('Buyers', Icons.people_alt_outlined, BuyersScreen()),
    _Dest('Products', Icons.inventory_2_outlined, ProductsScreen()),
    _Dest('Margins', Icons.tune, MarginsScreen()),
    _Dest('Orders', Icons.receipt_long_outlined, OrdersScreen()),
    _Dest('Payments', Icons.payments_outlined, PaymentsScreen()),
    _Dest('Settings', Icons.settings_outlined, SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: wide,
            minExtendedWidth: 200,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.hub, color: Theme.of(context).colorScheme.primary),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout),
                    onPressed: () => supabase.auth.signOut(),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final d in _dests)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(title: _dests[_index].label),
                Expanded(child: _dests[_index].page),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          Text(email,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline)),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 16,
            child: Text(email.isNotEmpty ? email[0].toUpperCase() : '?'),
          ),
        ],
      ),
    );
  }
}
