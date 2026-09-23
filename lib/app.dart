import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'game/progress_store.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'ui/screens/game_screen.dart';
import 'ui/theme/metro_theme.dart';

class PrindeMetrouApp extends StatefulWidget {
  const PrindeMetrouApp({super.key, required this.progressStore});

  final ProgressStore progressStore;

  @override
  State<PrindeMetrouApp> createState() => _PrindeMetrouAppState();
}

class _PrindeMetrouAppState extends State<PrindeMetrouApp> {
  final _localeController = LocaleController();

  @override
  void dispose() {
    _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: _localeController,
      builder: (context, locale, _) {
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: MetroTheme.theme,
          locale: locale,
          supportedLocales: LocaleController.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: GameScreen(
            localeController: _localeController,
            progressStore: widget.progressStore,
          ),
        );
      },
    );
  }
}
