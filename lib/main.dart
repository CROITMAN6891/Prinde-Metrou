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
  final progressStore = await ProgressStore.load();
  runApp(PrindeMetrouApp(progressStore: progressStore));
  // After runApp so the consent form has a screen to show over; this also
  // initializes MobileAds once ads are allowed.
  unawaited(ConsentManager.instance.gatherConsent());
}
