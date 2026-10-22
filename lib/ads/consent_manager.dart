import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The calls [ConsentManager] makes into the UMP and Mobile Ads SDKs, behind
/// an interface so tests can drive the flow without platform channels.
abstract class ConsentPlatform {
  /// Completes when the consent info is up to date; throws on failure.
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters params);

  /// Returns the form error, or null if the form was shown or not needed.
  Future<FormError?> loadAndShowConsentFormIfRequired();

  Future<bool> canRequestAds();

  Future<PrivacyOptionsRequirementStatus> getPrivacyOptionsRequirementStatus();

  /// Returns the form error, or null once the user closed the form.
  Future<FormError?> showPrivacyOptionsForm();

  Future<void> initializeMobileAds();
}

/// The real SDKs.
class GoogleConsentPlatform implements ConsentPlatform {
  const GoogleConsentPlatform();

  @override
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters params) {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      done.complete,
      (error) => done.completeError(error),
    );
    return done.future;
  }

  @override
  Future<FormError?> loadAndShowConsentFormIfRequired() {
    final done = Completer<FormError?>();
    ConsentForm.loadAndShowConsentFormIfRequired(done.complete);
    return done.future;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() =>
      ConsentInformation.instance.getPrivacyOptionsRequirementStatus();

  @override
  Future<FormError?> showPrivacyOptionsForm() {
    final done = Completer<FormError?>();
    ConsentForm.showPrivacyOptionsForm(done.complete);
    return done.future;
  }

  @override
  Future<void> initializeMobileAds() => MobileAds.instance.initialize();
}

/// Gathers GDPR consent through Google's UMP form (shown only to users in
/// regions that need it, e.g. the EEA, UK and Switzerland) and holds ads
/// back until the SDK says they may be requested.
class ConsentManager {
  ConsentManager({this.platform = const GoogleConsentPlatform()});

  static final ConsentManager instance = ConsentManager();

  final ConsentPlatform platform;

  /// True once ads may be requested; the banner waits on this.
  final ValueNotifier<bool> adsAllowed = ValueNotifier(false);

  /// True when the user must be offered a way to change their consent
  /// choice (the "Privacy options" button in the pause overlay).
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  bool _mobileAdsInitialized = false;
  Future<void>? _gathering;

  /// Runs on every launch: refreshes the consent info, shows the form if
  /// needed, then enables ads if allowed. Never throws; concurrent calls
  /// share one run.
  Future<void> gatherConsent() =>
      _gathering ??= _gather().whenComplete(() => _gathering = null);

  Future<void> _gather() async {
    try {
      await platform.requestConsentInfoUpdate(_requestParameters());
      final formError = await platform.loadAndShowConsentFormIfRequired();
      if (formError != null) {
        debugPrint('Consent form error: ${formError.message}');
      }
    } catch (error) {
      // A failed update or form still leaves any consent stored from a
      // previous launch, which canRequestAds() below reflects.
      debugPrint('Consent gathering failed: $error');
    }
    await _refresh();
  }

  /// Opens the UMP privacy options form so the user can change their choice,
  /// then re-reads what it allows. Never throws.
  Future<void> showPrivacyOptionsForm() async {
    try {
      final formError = await platform.showPrivacyOptionsForm();
      if (formError != null) {
        debugPrint('Privacy options form error: ${formError.message}');
      }
    } catch (error) {
      debugPrint('Privacy options form failed: $error');
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    var canRequest = false;
    try {
      canRequest = await platform.canRequestAds();
    } catch (error) {
      debugPrint('canRequestAds failed: $error');
    }
    try {
      privacyOptionsRequired.value =
          await platform.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (error) {
      debugPrint('Privacy options status failed: $error');
    }
    if (canRequest && !_mobileAdsInitialized) {
      try {
        await platform.initializeMobileAds();
        _mobileAdsInitialized = true;
      } catch (error) {
        debugPrint('MobileAds initialization failed: $error');
        return;
      }
    }
    adsAllowed.value = canRequest && _mobileAdsInitialized;
  }

  ConsentRequestParameters _requestParameters() {
    // DEBUG ONLY, remove when no longer needed: pretends the device is in
    // the EEA so the consent form can be tested from outside it. On a
    // physical phone, add its hashed ID (printed by the UMP SDK in logcat)
    // to testIdentifiers. Never applies to release builds.
    if (kDebugMode) {
      return ConsentRequestParameters(
        consentDebugSettings: ConsentDebugSettings(
          debugGeography: DebugGeography.debugGeographyEea,
          testIdentifiers: [],
        ),
      );
    }
    return ConsentRequestParameters();
  }
}
