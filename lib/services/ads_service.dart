import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';

/// AdMob: AB/İsviçre kullanıcıları için Google UMP onay formu, ödüllü reklam ve banner.
class AdsService {
  bool _initialized = false;
  RewardedAd? _rewarded;
  bool _loadingRewarded = false;

  bool get isRewardedReady => _rewarded != null;

  /// SDK başlatılıp onay alındıktan sonra true olur (banner'lar bunu bekler).
  final ValueNotifier<bool> ready = ValueNotifier(false);

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _gatherConsent();
      await MobileAds.instance.initialize();
      _initialized = true;
      ready.value = true;
      preloadRewarded();
    } catch (e) {
      debugPrint('Reklamlar başlatılamadı: $e');
    }
  }

  /// GDPR/nFADP için onay formunu (gerekiyorsa) gösterir.
  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) debugPrint('Onay formu hatası: ${error.message}');
          if (!done.isCompleted) done.complete();
        });
      },
      (FormError error) {
        debugPrint('Onay bilgisi alınamadı: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  /// Kullanıcı ayarlardan gizlilik seçeneklerini yeniden açabilsin.
  Future<void> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((FormError? e) {
      if (e != null) debugPrint('Gizlilik formu hatası: ${e.message}');
    });
  }

  void preloadRewarded() {
    if (!_initialized || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AppConfig.rewardedAdUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Ödüllü reklam yüklenemedi: $error');
          _loadingRewarded = false;
        },
      ),
    );
  }

  /// Ödüllü reklamı gösterir. Kullanıcı reklamı sonuna kadar izlerse true döner.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      preloadRewarded();
      return false;
    }
    _rewarded = null;
    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!result.isCompleted) result.complete(earned);
        preloadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!result.isCompleted) result.complete(false);
        preloadRewarded();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }

  BannerAd createBanner({required VoidCallback onLoaded}) => BannerAd(
        size: AdSize.banner,
        adUnitId: AppConfig.bannerAdUnit,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => onLoaded(),
          onAdFailedToLoad: (ad, error) {
            debugPrint('Banner yüklenemedi: $error');
            ad.dispose();
          },
        ),
      );
}
