import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'theme.dart';
import 'auth/auth_gate.dart';

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const BuyerApp());
}

class BuyerApp extends StatelessWidget {
  const BuyerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) => PhoneFrame(child: child ?? const SizedBox.shrink()),
      home: const AuthGate(),
    );
  }
}

/// On a wide screen (desktop browser) the app is shown inside a centred phone
/// frame so it reads as a mobile app. On a real narrow screen it fills the
/// display normally.
class PhoneFrame extends StatelessWidget {
  final Widget child;
  const PhoneFrame({super.key, required this.child});

  static const double _frameWidth = 400;
  static const double _maxFrameHeight = 860;
  static const double _bezel = 10;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Real phone / narrow window: no frame.
    if (media.size.width < 600) return child;

    final frameH = math.min(media.size.height - 24, _maxFrameHeight);
    final innerW = _frameWidth - _bezel * 2;
    final innerH = frameH - _bezel * 2;

    return Container(
      color: const Color(0xFF2B2D31),
      alignment: Alignment.center,
      child: Container(
        width: _frameWidth,
        height: frameH,
        padding: const EdgeInsets.all(_bezel),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(46),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 40, spreadRadius: 4),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: MediaQuery(
            data: media.copyWith(
              size: Size(innerW, innerH),
              padding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
            ),
            child: SizedBox(width: innerW, height: innerH, child: child),
          ),
        ),
      ),
    );
  }
}
