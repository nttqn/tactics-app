import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob banner + interstitial.
///
/// Each platform has Marchlords' own ad units, since AdMob units are
/// platform-specific. The App IDs live outside this file: Android's in
/// android/app/build.gradle.kts, iOS's in ios/Runner/Info.plist.
///
/// `google_mobile_ads` only supports Android/iOS, so everything here is a
/// no-op elsewhere, which keeps `flutter run -d chrome` and tests working.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get bannerAdUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? 'ca-app-pub-9078637596840810/6671864833'
      : 'ca-app-pub-9078637596840810/9444708696';

  static String get interstitialAdUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? 'ca-app-pub-9078637596840810/6049048302'
      : 'ca-app-pub-9078637596840810/5301360260';

  /// Becomes true once the SDK has started; nothing loads before that.
  final ValueNotifier<bool> ready = ValueNotifier(false);
  bool get _ready => ready.value;
  InterstitialAd? _interstitialAd;
  int _breaksSinceInterstitial = 0;

  Future<void> initialize() async {
    if (!_supported) return;
    try {
      await MobileAds.instance.initialize();
      ready.value = true;
      _loadInterstitial();
    } catch (_) {
      // Ads failing must never block the game.
    }
  }

  BannerAd? createBannerAd({required void Function() onLoaded}) {
    if (!_ready) return null;
    final banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    banner.load();
    return banner;
  }

  void _loadInterstitial() {
    if (!_ready) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  /// Call only when a battle is over or being left, never during play.
  /// Shows at most every other break.
  void maybeShowInterstitial() {
    if (!_ready) return;
    _breaksSinceInterstitial++;
    if (_breaksSinceInterstitial < 2 || _interstitialAd == null) {
      if (_interstitialAd == null) _loadInterstitial();
      return;
    }
    _breaksSinceInterstitial = 0;
    final ad = _interstitialAd!;
    _interstitialAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }
}
