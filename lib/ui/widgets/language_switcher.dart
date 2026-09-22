import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/locale_controller.dart';
import '../theme/metro_theme.dart';

/// Small RO/EN toggle. Highlights whichever locale is currently active,
/// whether that came from an explicit user choice or from the device.
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activeLocale = Localizations.localeOf(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LanguageChip(
          label: l10n.languageNameRomanian,
          selected: activeLocale.languageCode == 'ro',
          onTap: () => localeController.setLocale(const Locale('ro')),
        ),
        const SizedBox(width: 6),
        _LanguageChip(
          label: l10n.languageNameEnglish,
          selected: activeLocale.languageCode == 'en',
          onTap: () => localeController.setLocale(const Locale('en')),
        ),
      ],
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? MetroTheme.wagonColor : Colors.transparent,
          border: Border.all(color: MetroTheme.wagonColor, width: 1.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? MetroTheme.background : MetroTheme.wagonColor,
          ),
        ),
      ),
    );
  }
}
