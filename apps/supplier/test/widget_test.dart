import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Placeholder smoke test. The full app requires Supabase initialization and
// network access, so it isn't exercised here.
void main() {
  testWidgets('smoke: a trivial widget builds', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('ok'))));
    expect(find.text('ok'), findsOneWidget);
  });
}
