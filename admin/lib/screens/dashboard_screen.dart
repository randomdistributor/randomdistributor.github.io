import 'package:flutter/material.dart';

import '../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, int>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadCounts();
  }

  Future<int> _count(String table) async {
    final rows = await supabase.from(table).select('id');
    return (rows as List).length;
  }

  Future<Map<String, int>> _loadCounts() async {
    final results = await Future.wait([
      _count('suppliers'),
      _count('buyers'),
      _count('products'),
      _count('orders'),
    ]);
    return {
      'Suppliers': results[0],
      'Buyers': results[1],
      'Products': results[2],
      'Orders': results[3],
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Failed to load: ${snap.error}'));
        }
        final data = snap.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final e in data.entries)
                _StatCard(label: e.key, value: e.value),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline)),
              const SizedBox(height: 8),
              Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
      ),
    );
  }
}
