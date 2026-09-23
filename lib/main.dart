import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app.dart';
import 'game/progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  final progressStore = await ProgressStore.load();
  runApp(PrindeMetrouApp(progressStore: progressStore));
}
