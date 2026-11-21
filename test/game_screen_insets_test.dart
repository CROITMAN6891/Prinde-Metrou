import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prinde_metrou/ads/consent_manager.dart';
import 'package:prinde_metrou/game/progress_store.dart';
import 'package:prinde_metrou/l10n/generated/app_localizations.dart';
import 'package:prinde_metrou/l10n/locale_controller.dart';
import 'package:prinde_metrou/ui/screens/game_screen.dart';
import 'package:prinde_metrou/ui/widgets/language_switcher.dart';
import 'package:prinde_metrou/ui/widgets/pause_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('edge-to-edge: the game stays clear of the system bars', (
    tester,
  ) async {
    const statusBar = 40.0;
    const gestureBar = 30.0;
    SharedPreferences.setMockInitialValues({});
    final progressStore = await ProgressStore.load();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ro'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // What the system reports once the app draws under its bars.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: statusBar, bottom: gestureBar),
            viewPadding: const EdgeInsets.only(
              top: statusBar,
              bottom: gestureBar,
            ),
          ),
          child: child!,
        ),
        home: GameScreen(
          localeController: LocaleController(),
          progressStore: progressStore,
          consentManager: ConsentManager(),
        ),
      ),
    );

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // Top bar row below the status bar; the play area (and the banner
    // under it) above the gesture bar.
    expect(
      tester.getTopLeft(find.byType(LanguageSwitcher)).dy,
      greaterThanOrEqualTo(statusBar),
    );
    expect(
      tester.getBottomLeft(find.byType(PauseOverlay)).dy,
      lessThanOrEqualTo(screenHeight - gestureBar),
    );

    // Dispose the screen so its game ticker is cancelled.
    await tester.pumpWidget(const SizedBox());
  });
}
