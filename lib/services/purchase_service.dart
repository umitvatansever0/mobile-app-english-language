import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_config.dart';

/// Paywall'da gösterilecek plan.
class PlanOption {
  const PlanOption({required this.id, required this.title, required this.price, required this.subtitle, this.package});
  final String id; // 'annual' | 'monthly'
  final String title;
  final String price;
  final String subtitle;
  final Package? package;
}

enum PurchaseOutcome { success, cancelled, failed, notConfigured }

/// RevenueCat ile abonelik (Google Play Billing + App Store).
///
/// RevenueCat anahtarı verilmediyse "test modu"nda çalışır: fiyatlar örnek
/// olarak gösterilir, satın alma gerçek ödeme almaz ve sadece debug derlemede
/// premium'u açar (ekranları denemek için).
class PurchaseService {
  final ValueNotifier<bool> isPremium = ValueNotifier(false);
  bool _configured = false;

  bool get isTestMode => !_configured;

  Future<void> init({required bool cachedPremium}) async {
    isPremium.value = cachedPremium;
    if (!AppConfig.purchasesConfigured) {
      debugPrint('RevenueCat anahtarı yok — abonelik test modunda.');
      return;
    }
    try {
      await Purchases.configure(PurchasesConfiguration(AppConfig.revenueCatKey));
      _configured = true;
      Purchases.addCustomerInfoUpdateListener(_apply);
      _apply(await Purchases.getCustomerInfo());
    } catch (e) {
      debugPrint('RevenueCat başlatılamadı: $e');
    }
  }

  void _apply(CustomerInfo info) {
    isPremium.value = info.entitlements.active.containsKey(AppConfig.premiumEntitlement);
  }

  Future<List<PlanOption>> loadPlans() async {
    if (!_configured) {
      return const [
        PlanOption(id: 'annual', title: 'Yıllık Abonelik', price: 'CHF 29.00', subtitle: 'İlk 3 gün ücretsiz, sonra yılda bir kez faturalandırılır'),
        PlanOption(id: 'monthly', title: 'Aylık Abonelik', price: 'CHF 4.90', subtitle: 'İstediğin zaman iptal et'),
      ];
    }
    try {
      final offering = (await Purchases.getOfferings()).current;
      if (offering == null) return const [];
      return [
        if (offering.annual != null)
          PlanOption(
            id: 'annual',
            title: 'Yıllık Abonelik',
            price: offering.annual!.storeProduct.priceString,
            subtitle: 'Deneme süresi bitince yılda bir kez faturalandırılır',
            package: offering.annual,
          ),
        if (offering.monthly != null)
          PlanOption(
            id: 'monthly',
            title: 'Aylık Abonelik',
            price: offering.monthly!.storeProduct.priceString,
            subtitle: 'İstediğin zaman iptal et',
            package: offering.monthly,
          ),
      ];
    } catch (e) {
      debugPrint('Planlar yüklenemedi: $e');
      return const [];
    }
  }

  Future<PurchaseOutcome> buy(PlanOption plan) async {
    if (!_configured || plan.package == null) {
      if (kDebugMode) {
        isPremium.value = true; // sadece geliştirme sırasında ekranları denemek için
        return PurchaseOutcome.success;
      }
      return PurchaseOutcome.notConfigured;
    }
    try {
      final result = await Purchases.purchasePackage(plan.package!);
      _apply(result.customerInfo);
      return isPremium.value ? PurchaseOutcome.success : PurchaseOutcome.failed;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return PurchaseOutcome.cancelled;
      debugPrint('Satın alma hatası: $e');
      return PurchaseOutcome.failed;
    }
  }

  Future<bool> restore() async {
    if (!_configured) return false;
    try {
      _apply(await Purchases.restorePurchases());
      return isPremium.value;
    } catch (e) {
      debugPrint('Geri yükleme hatası: $e');
      return false;
    }
  }
}
