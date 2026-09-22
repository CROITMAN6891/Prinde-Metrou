import 'package:flutter/material.dart';

/// Holds the user's explicit language choice. `null` means "follow the
/// device locale" (still constrained to [supportedLocales] by MaterialApp).
class LocaleController extends ValueNotifier<Locale?> {
  LocaleController() : super(null);

  static const supportedLocales = [Locale('ro'), Locale('en')];

  void setLocale(Locale locale) => value = locale;
}
