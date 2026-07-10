import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../shell/admin_shell.dart';
import 'login_screen.dart';

/// Decides what to show based on auth state and role.
/// No session -> login. Session but not admin -> access denied. Admin -> shell.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session == null) return const LoginScreen();
        return const _AdminOnly();
      },
    );
  }
}

class _AdminOnly extends StatefulWidget {
  const _AdminOnly();

  @override
  State<_AdminOnly> createState() => _AdminOnlyState();
}

class _AdminOnlyState extends State<_AdminOnly> {
  late Future<String?> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _loadRole();
  }

  Future<String?> _loadRole() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await supabase
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    return row?['role'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == 'admin') return const AdminShell();
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                const Text('This account is not an admin.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => supabase.auth.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
