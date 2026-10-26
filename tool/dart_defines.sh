#!/usr/bin/env bash
# Ortam değişkenlerinde (GitHub Secrets) tanımlı olan anahtarları --dart-define
# olarak basar. Boş olanlar atlanır; böylece kod içindeki varsayılanlar (ör. AdMob
# test kimlikleri) geçerli kalır.
for name in REVENUECAT_ANDROID_KEY REVENUECAT_IOS_KEY \
            ADMOB_REWARDED_ANDROID ADMOB_BANNER_ANDROID ADMOB_REWARDED_IOS ADMOB_BANNER_IOS \
            SUPPORT_EMAIL PRIVACY_URL TERMS_URL IOS_APP_ID; do
  val="${!name}"
  if [ -n "$val" ]; then printf -- '--dart-define=%s=%s ' "$name" "$val"; fi
done
