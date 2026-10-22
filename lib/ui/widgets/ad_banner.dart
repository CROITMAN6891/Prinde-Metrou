import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../ads/consent_manager.dart';

/// A single, thin, fixed-position banner, loaded only once [adsAllowed]
/// (by default [ConsentManager.adsAllowed]) is true.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, this.adsAllowed});

  final ValueListenable<bool>? adsAllowed;

  /// The real unit serves only in Android release builds: debug and profile
  /// builds get Google's test banner, so testing on a device never counts
  /// as (invalid) traffic on the real unit. iOS has no AdMob app yet, so it
  /// stays on the iOS test banner.
  static String get _adUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return kReleaseMode
        ? 'ca-app-pub-5775369355948596/3241614658'
        : 'ca-app-pub-3940256099942544/6300978111';
  }

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _loading = false;
  late ValueListenable<bool> _adsAllowed;

  @override
  void initState() {
    super.initState();
    _adsAllowed = widget.adsAllowed ?? ConsentManager.instance.adsAllowed;
    _adsAllowed.addListener(_onAdsAllowedChanged);
    _onAdsAllowedChanged();
  }

  @override
  void didUpdateWidget(AdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final adsAllowed = widget.adsAllowed ?? ConsentManager.instance.adsAllowed;
    if (adsAllowed != _adsAllowed) {
      _adsAllowed.removeListener(_onAdsAllowedChanged);
      _adsAllowed = adsAllowed..addListener(_onAdsAllowedChanged);
      _onAdsAllowedChanged();
    }
  }

  void _onAdsAllowedChanged() {
    if (_adsAllowed.value) {
      if (_bannerAd == null && !_loading) _loadBanner();
    } else if (_bannerAd != null) {
      // Consent withdrawn through the privacy options: drop the banner.
      _bannerAd!.dispose();
      setState(() => _bannerAd = null);
    }
  }

  void _loadBanner() {
    _loading = true;
    BannerAd(
      adUnitId: AdBanner._adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _loading = false;
          if (!mounted || !_adsAllowed.value) {
            ad.dispose();
            return;
          }
          setState(() => _bannerAd = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          _loading = false;
          ad.dispose();
        },
      ),
    ).load();
  }

  @override
  void dispose() {
    _adsAllowed.removeListener(_onAdsAllowedChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
