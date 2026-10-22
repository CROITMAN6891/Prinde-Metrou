import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:prinde_metrou/ads/consent_manager.dart';
import 'package:prinde_metrou/ui/widgets/ad_banner.dart';

class _FakePlatform implements ConsentPlatform {
  bool canRequest = true;
  bool updateFails = false;
  bool canRequestThrows = false;
  FormError? formError;
  PrivacyOptionsRequirementStatus privacyStatus =
      PrivacyOptionsRequirementStatus.notRequired;
  final calls = <String>[];
  int initializeCount = 0;

  @override
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters params) async {
    calls.add('update');
    if (updateFails) {
      throw FormError(errorCode: 1, message: 'network');
    }
  }

  @override
  Future<FormError?> loadAndShowConsentFormIfRequired() async {
    calls.add('form');
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
    return null;
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
