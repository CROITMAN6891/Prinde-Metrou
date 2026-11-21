import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prinde_metrou/ads/consent_manager.dart';
import 'package:prinde_metrou/game/progress_store.dart';
import 'package:prinde_metrou/l10n/generated/app_localizations.dart';
import 'package:prinde_metrou/l10n/locale_controller.dart';
import 'package:prinde_metrou/ui/screens/game_screen.dart';
import 'package:prinde_metrou/ui/widgets/pause_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a consent form pauses the game, which stays paused after it '
      'closes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final progressStore = await ProgressStore.load();
    // Never touches the platform: the test only flips formShowing.
    final consent = ConsentManager();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ro'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GameScreen(
          localeController: LocaleController(),
          progressStore: progressStore,
          consentManager: consent,
        ),
      ),
    );

    bool paused() =>
        tester.widget<PauseOverlay>(find.byType(PauseOverlay)).visible;

    expect(paused(), isFalse);

    consent.formShowing.value = true;
    await tester.pump();
    expect(paused(), isTrue);

    // No auto-resume: the player taps the pause overlay when ready.
    consent.formShowing.value = false;
    await tester.pump();
    expect(paused(), isTrue);

    // Dispose the screen so its game ticker is cancelled.
    await tester.pumpWidget(const SizedBox());
  });
}
