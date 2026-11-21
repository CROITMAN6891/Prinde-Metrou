import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/consent_manager.dart';
import 'app.dart';
import 'game/progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The grid is laid out for portrait; landscape just shrinks it.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Draw under the system bars on every Android version, as Android 15+
  // already enforces; SafeArea keeps the game and banner clear of them.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Transparent bars with light icons over the dark metro background.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Android
      statusBarBrightness: Brightness.dark, // iOS: dark bar, light text
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      // No grey scrim behind 3-button navigation; light icons stay readable.
      systemNavigationBarContrastEnforced: false,
    ),
  );
  final progressStore = await ProgressStore.load();
  runApp(PrindeMetrouApp(progressStore: progressStore));
  // After runApp so the consent form has a screen to show over; this also
  // initializes MobileAds once ads are allowed.
  unawaited(ConsentManager.instance.gatherConsent());
}
