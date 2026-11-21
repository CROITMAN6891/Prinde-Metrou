import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:prinde_metrou/ads/consent_manager.dart';
import 'package:prinde_metrou/ui/widgets/ad_banner.dart';

class _FakePlatform implements ConsentPlatform {
  bool canRequest = true;
  bool updateFails = false;
  bool canRequestThrows = false;
  bool statusThrows = false;
  bool formThrows = false;
  FormError? formError;
  ConsentStatus consentStatus = ConsentStatus.notRequired;
  PrivacyOptionsRequirementStatus privacyStatus =
      PrivacyOptionsRequirementStatus.notRequired;
  final calls = <String>[];
  int initializeCount = 0;

  /// Runs while either form is "on screen", to observe the manager then.
  VoidCallback? whileFormShows;

  @override
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters params) async {
    calls.add('update');
    if (updateFails) {
      throw FormError(errorCode: 1, message: 'network');
    }
  }

  @override
  Future<ConsentStatus> getConsentStatus() async {
    if (statusThrows) throw StateError('channel');
    return consentStatus;
  }

  @override
  Future<FormError?> loadAndShowConsentFormIfRequired() async {
    calls.add('form');
    whileFormShows?.call();
    if (formThrows) throw StateError('form');
    return formError;
  }

  @override
  Future<bool> canRequestAds() async {
    calls.add('canRequestAds');
    if (canRequestThrows) throw StateError('channel');
    return canRequest;
  }

  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async => privacyStatus;

  @override
  Future<FormError?> showPrivacyOptionsForm() async {
    calls.add('privacyForm');
    whileFormShows?.call();
    if (formThrows) throw StateError('form');
    return formError;
  }

  @override
  Future<void> initializeMobileAds() async {
    calls.add('initialize');
    initializeCount++;
  }
}

void main() {
  late _FakePlatform platform;
  late ConsentManager manager;

  setUp(() {
    platform = _FakePlatform();
    manager = ConsentManager(platform: platform);
  });

  test('updates, shows the form, then initializes ads when allowed', () async {
    await manager.gatherConsent();
    expect(platform.calls, ['update', 'form', 'canRequestAds', 'initialize']);
    expect(manager.adsAllowed.value, isTrue);
  });

  test('keeps ads off and skips initialization when not allowed', () async {
    platform.canRequest = false;
    await manager.gatherConsent();
    expect(platform.initializeCount, 0);
    expect(manager.adsAllowed.value, isFalse);
  });

  test('a failed update still checks canRequestAds', () async {
    platform.updateFails = true;
    await manager.gatherConsent();
    expect(platform.calls, ['update', 'canRequestAds', 'initialize']);
    expect(manager.adsAllowed.value, isTrue);
  });

  test('a form error still checks canRequestAds', () async {
    platform.formError = FormError(errorCode: 2, message: 'form');
    await manager.gatherConsent();
    expect(manager.adsAllowed.value, isTrue);
  });

  test('a throwing canRequestAds never crashes and keeps ads off', () async {
    platform.canRequestThrows = true;
    await manager.gatherConsent();
    expect(manager.adsAllowed.value, isFalse);
    expect(platform.initializeCount, 0);
  });

  test('initializes MobileAds only once across launches', () async {
    await manager.gatherConsent();
    await manager.gatherConsent();
    await manager.showPrivacyOptionsForm();
    expect(platform.initializeCount, 1);
  });

  test('concurrent gathers share one run', () async {
    await Future.wait([manager.gatherConsent(), manager.gatherConsent()]);
    expect(platform.calls.where((c) => c == 'update'), hasLength(1));
  });

  test('exposes whether privacy options are required', () async {
    platform.privacyStatus = PrivacyOptionsRequirementStatus.required;
    await manager.gatherConsent();
    expect(manager.privacyOptionsRequired.value, isTrue);
  });

  test('privacy options can grant or withdraw ads', () async {
    platform.canRequest = false;
    await manager.gatherConsent();
    expect(manager.adsAllowed.value, isFalse);

    platform.canRequest = true;
    await manager.showPrivacyOptionsForm();
    expect(platform.calls, contains('privacyForm'));
    expect(manager.adsAllowed.value, isTrue);

    platform.canRequest = false;
    await manager.showPrivacyOptionsForm();
    expect(manager.adsAllowed.value, isFalse);
  });

  group('formShowing', () {
    late List<bool> seenWhileShowing;

    setUp(() {
      seenWhileShowing = [];
      platform.whileFormShows = () =>
          seenWhileShowing.add(manager.formShowing.value);
    });

    test('stays false when consent is not required', () async {
      final changes = <bool>[];
      manager.formShowing.addListener(
        () => changes.add(manager.formShowing.value),
      );
      await manager.gatherConsent();
      expect(seenWhileShowing, [false]);
      expect(changes, isEmpty);
      expect(manager.formShowing.value, isFalse);
    });

    test('stays false when the status check throws, and the form still '
        'runs', () async {
      platform.statusThrows = true;
      await manager.gatherConsent();
      expect(platform.calls, contains('form'));
      expect(seenWhileShowing, [false]);
      expect(manager.formShowing.value, isFalse);
    });

    test('is true while the required form shows, false after', () async {
      platform.consentStatus = ConsentStatus.required;
      await manager.gatherConsent();
      expect(seenWhileShowing, [true]);
      expect(manager.formShowing.value, isFalse);
    });

    test('clears after a form error', () async {
      platform.consentStatus = ConsentStatus.required;
      platform.formError = FormError(errorCode: 2, message: 'form');
      await manager.gatherConsent();
      expect(seenWhileShowing, [true]);
      expect(manager.formShowing.value, isFalse);
    });

    test('clears when the form throws', () async {
      platform.consentStatus = ConsentStatus.required;
      platform.formThrows = true;
      await manager.gatherConsent();
      expect(seenWhileShowing, [true]);
      expect(manager.formShowing.value, isFalse);
      expect(platform.calls, contains('canRequestAds'));
    });

    test('is true around the privacy options form, false after', () async {
      await manager.showPrivacyOptionsForm();
      expect(seenWhileShowing, [true]);
      expect(manager.formShowing.value, isFalse);
    });

    test('clears when the privacy options form errors or throws', () async {
      platform.formError = FormError(errorCode: 3, message: 'privacy');
      await manager.showPrivacyOptionsForm();
      expect(manager.formShowing.value, isFalse);

      platform.formThrows = true;
      await manager.showPrivacyOptionsForm();
      expect(seenWhileShowing, [true, true]);
      expect(manager.formShowing.value, isFalse);
    });
  });

  testWidgets('banner renders nothing while ads are not allowed', (
    tester,
  ) async {
    final adsAllowed = ValueNotifier(false);
    await tester.pumpWidget(
      MaterialApp(home: AdBanner(adsAllowed: adsAllowed)),
    );
    expect(find.byType(AdWidget), findsNothing);
    final box = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(AdBanner),
        matching: find.byType(SizedBox),
      ),
    );
    expect(box.width, 0);
    expect(box.height, 0);
  });
}
