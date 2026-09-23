import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prinde_metrou/game/progression.dart';
import 'package:prinde_metrou/game/train_skin.dart';
import 'package:prinde_metrou/l10n/generated/app_localizations.dart';
import 'package:prinde_metrou/ui/widgets/celebration_overlay.dart';
import 'package:prinde_metrou/ui/widgets/pause_overlay.dart';
import 'package:prinde_metrou/ui/widgets/skin_picker.dart';
import 'package:prinde_metrou/ui/widgets/tier_choice_overlay.dart';

Widget _host(Widget child, {Locale locale = const Locale('ro')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('pause overlay resumes on tap', (tester) async {
    var resumed = false;
    await tester.pumpWidget(
      _host(PauseOverlay(visible: true, onResume: () => resumed = true)),
    );
    expect(find.text('Atinge pentru a continua'), findsOneWidget);
    await tester.tap(find.text('Pauză'));
    expect(resumed, isTrue);
  });

  testWidgets('tier choice offers next tier and reports the choice', (
    tester,
  ) async {
    bool? advanced;
    await tester.pumpWidget(
      _host(
        TierChoiceOverlay(
          visible: true,
          score: 25,
          tier: SpeedTier.light,
          onChoose: ({required bool advance}) => advanced = advance,
        ),
        locale: const Locale('en'),
      ),
    );
    expect(find.text('25 wagons!'), findsOneWidget);
    expect(find.text('Continue to the next level (Medium)'), findsOneWidget);

    await tester.tap(find.text('Keep going at this level'));
    expect(advanced, isFalse);
  });

  testWidgets('celebration shows unlock line when requested', (tester) async {
    await tester.pumpWidget(
      _host(
        const CelebrationOverlay(
          celebration: Celebration.legend,
          unlockedSkin: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Legendă!'), findsOneWidget);
    expect(find.text('Culoare nouă de tren deblocată!'), findsOneWidget);
  });

  testWidgets('skin picker only lets unlocked skins be picked', (tester) async {
    TrainSkin? picked;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await SkinPicker.show(
              context,
              selected: TrainSkin.classic,
              bestScore: 10,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 15 and 25 are still locked with a best of 10.
    expect(find.byIcon(Icons.lock), findsNWidgets(2));
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(picked, isNull);

    await tester.tap(find.byKey(const ValueKey('skin-ocean')));
    await tester.pumpAndSettle();
    expect(picked?.id, 'ocean');
  });
}
