# İngilizce Çalışma Kartları

Türkçe konuşanlar için İngilizce kelime kartları uygulaması (Flutter — Android + iOS).

## Özellikler

- **Kart çalışması, 4 mod:** Yazarak (EN → TR), Ters yön (TR → EN), Çoktan seçmeli, Dinle ve yaz
- **Hoşgörülü cevap kontrolü:**
  - Türkçe karakter olmadan yazmak kabul edilir ("soylemek" = "söylemek").
  - Eş anlamlılar kabul edilir.
  - Uzun kelimelerde 1–2 harflik yazım hatası "neredeyse doğru" sayılır.
- **Aralıklı tekrar (SM-2):** Unuttum / Öğreniyorum / Biliyorum etiketleri. Zamanı gelen tekrarlar oturuma önce eklenir.
- **Hataları Çalış:** Yanlış yapılan kelimeler ayrı bir listede toplanır.
- **Seri ve dondurma:** Seri tutulur. Ödüllü reklamla seri dondurma hakkı kazanılır (en fazla 2).
- **35 rozet:** Bronz, gümüş, altın ve elmas seviyeleri. Rozet kartları kodla çizilir, görsel dosyası gerekmez.
- **İstatistikler:** Ana sayfa, günlük hedef (dalga göstergesi), son 7 gün grafiği
- **Kelimeler ekranı:** Arama, durum ve seviye filtreleri, kelime detayı
- **Kendi kelimelerim:** Premium özelliği
- **Seslendirme:** Kelime ve örnek cümle, cihazın kendi TTS motoruyla. US/UK aksan seçilebilir.
- **Diğer:** Koyu tema, titreşim ve otomatik seslendirme ayarları
- **Ücretsiz model:**
  - Günde 20 kelime.
  - Kota dolunca paywall açılır ve **"Reklam izle, +20 kelime"** seçeneği sunulur (günlük reklam sınırı yok; `AppConfig.maxRewardedAdsPerDay` ile sınır konabilir).
  - Ücretsiz sürümde banner reklam gösterilir, kart ekranında gösterilmez.
- **Premium:** Sınırsız kelime, 50/100'lük seanslar, kategoriler ve konu desteleri, ek modlar, reklamsız deneyim
- **Kelime verisi:** 1386 kelime, 6 seviye (A1: 402, A2: 235, B1: 293, B2: 186, C1: 142, C2: 128). Her kelimede Türkçe karşılıklar, kelime türü, konu ve Türkçe çevirili örnek cümle var. Yeni kelimeler kullanıcının hedef seviyesinden gelir; hedef seviye bitince bir alt seviyeye geçilir.

## Yerelde çalıştırma

Flutter 3.38 veya üstü gerekir.

```bash
flutter pub get
flutter run
```

Hiçbir anahtar vermeden de çalışır:
- Reklamlar Google'ın **test** reklamlarıdır.
- Abonelik **test modundadır**: gerçek ödeme alınmaz. Debug derlemede "Seçimi Onayla" premium'u açar, böylece ekranları deneyebilirsin.

## Yayına hazırlık (yapılması gerekenler)

### 1. RevenueCat (abonelik)

1. Play Console ve App Store Connect'te iki abonelik ürünü oluştur:
   - Aylık
   - Yıllık (3 gün ücretsiz deneme ile)
2. RevenueCat'te `premium` adında bir entitlement oluştur ve iki ürünü buna bağla.
3. Varsayılan offering'e `$rc_monthly` ve `$rc_annual` paketlerini ekle.
4. Derlerken anahtarları ver:

```bash
flutter build appbundle \
  --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx \
  --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-XXX/YYY \
  --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXX/ZZZ \
  --dart-define=SUPPORT_EMAIL=destek@ornek.com \
  -PADMOB_APP_ID=ca-app-pub-XXX~AAA
```

iOS için aynı değerleri `REVENUECAT_IOS_KEY`, `ADMOB_REWARDED_IOS` ve `ADMOB_BANNER_IOS` adlarıyla ver. Ayrıca `ios/Runner/Info.plist` içindeki `GADApplicationIdentifier` değerini kendi AdMob iOS App ID'nle değiştir.

### 2. AdMob

- Android ve iOS için birer uygulama oluştur.
- Her platform için bir **Ödüllü** ve bir **Banner** reklam birimi oluştur.
- AdMob'da **Gizlilik ve mesajlaşma** bölümünden GDPR onay mesajını yayınla. Uygulama onay formunu Google UMP ile otomatik gösterir.

### 3. Android imzası

1. Bir keystore oluştur.
2. `android/key.properties` dosyasını yaz. Bu dosya git'e eklenmez:

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/tam/yol/upload-keystore.jks
```

### 4. iOS

- Apple Developer hesabı (yıllık ücretli) ve bir Mac gerekir.
- Xcode'da Bundle ID ve Team ayarlanıp imzalanmalıdır.

### 5. Mağaza

- `docs/privacy.md` ve `docs/terms.md` şablonlarını kendi bilgilerinle tamamla.
- Mağaza girişlerinde bu sayfaların bağlantısını ver.
- Google Play, yeni kişisel geliştirici hesaplarında yayından önce kapalı test şartı arıyor (12 test kullanıcısı, 14 gün). Güncel kuralı Play Console'da kontrol et.

## Kelime eklemek / düzeltmek

1. `data_src/` altındaki seviye dosyasını (`a1.txt` … `c2.txt`) düzenle. Satır biçimi:

```
ingilizce|türkçe1;türkçe2|tür|konu|English example.|Türkçe örnek.
```

2. JSON'u yeniden üret: `python3 tool/build_words.py` → `assets/data/words.json`

CI, JSON güncel değilse hata verir.

## CI

Her push'ta GitHub Actions şunları yapar:
- `flutter analyze`
- testler
- Android APK derlemesi. APK'yı Actions › ilgili çalıştırma › **Artifacts** bölümünden indirip telefona kurabilirsin.
- iOS imzasız derleme kontrolü

## Teşekkür

Dalga ilerleme göstergesi (`lib/widgets/wave_progress.dart`), tanıtım akışı ve renk paleti [best-flutter-ui-templates](https://github.com/mitesh77/best-flutter-ui-templates) projesinden uyarlanmıştır (MIT Lisansı, © 2019 Mitesh Chodvadiya).

Aralıklı tekrar ve seri mantığı `weblearningapp` (DeutschStep) projesinden aktarılmıştır.
