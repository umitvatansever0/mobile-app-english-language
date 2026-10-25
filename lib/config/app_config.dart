import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Uygulama genelindeki ayarlar.
///
/// Gerçek anahtarlar koda yazılmaz; derlerken --dart-define ile verilir:
///   flutter build appbundle \
///     --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx \
///     --dart-define=REVENUECAT_IOS_KEY=appl_xxx \
///     --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-.../... \
///     --dart-define=ADMOB_REWARDED_IOS=ca-app-pub-.../... \
///     --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-.../... \
///     --dart-define=ADMOB_BANNER_IOS=ca-app-pub-.../...
/// Verilmezse Google'ın resmi TEST reklam kimlikleri kullanılır ve abonelik
/// "test modu"nda çalışır (gerçek ödeme alınmaz).
class AppConfig {
  AppConfig._();

  static const appName = 'İngilizce Çalışma Kartları';

  // --- Ücretsiz kullanım kuralları ---
  static const dailyFreeWords = 20;
  static const rewardedBonusWords = 3;
  static const maxRewardedAdsPerDay = 3;
  static const premiumSessionSizes = [20, 50, 100];

  /// RevenueCat'te oluşturulacak entitlement kimliği.
  static const premiumEntitlement = 'premium';

  // --- RevenueCat ---
  static const _rcAndroid = String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const _rcIos = String.fromEnvironment('REVENUECAT_IOS_KEY');

  static String get revenueCatKey {
    if (kIsWeb) return '';
    return Platform.isIOS ? _rcIos : _rcAndroid;
  }

  static bool get purchasesConfigured => revenueCatKey.isNotEmpty;

  // --- AdMob (Google resmi test kimlikleri varsayılan) ---
  static const _rewardedAndroid = String.fromEnvironment('ADMOB_REWARDED_ANDROID',
      defaultValue: 'ca-app-pub-3940256099942544/5224354917');
  static const _rewardedIos = String.fromEnvironment('ADMOB_REWARDED_IOS',
      defaultValue: 'ca-app-pub-3940256099942544/1712485313');
  static const _bannerAndroid = String.fromEnvironment('ADMOB_BANNER_ANDROID',
      defaultValue: 'ca-app-pub-3940256099942544/6300978111');
  static const _bannerIos = String.fromEnvironment('ADMOB_BANNER_IOS',
      defaultValue: 'ca-app-pub-3940256099942544/2934735716');

  static String get rewardedAdUnit => Platform.isIOS ? _rewardedIos : _rewardedAndroid;
  static String get bannerAdUnit => Platform.isIOS ? _bannerIos : _bannerAndroid;

  /// Kelime hatası bildirimi ve destek için e-posta. Boşsa "Bildir" bağlantısı gizlenir.
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  /// Mağaza sayfaları ("Uygulamayı Puanla" için).
  static const androidPackage = 'com.umitvatansever.ingilizce_calisma_kartlari';
  static const iosAppId = String.fromEnvironment('IOS_APP_ID');

  static const privacyUrl = String.fromEnvironment('PRIVACY_URL',
      defaultValue: 'https://github.com/umitvatansever0/mobile-app-english-language/blob/main/docs/privacy.md');
  static const termsUrl = String.fromEnvironment('TERMS_URL',
      defaultValue: 'https://github.com/umitvatansever0/mobile-app-english-language/blob/main/docs/terms.md');
}
