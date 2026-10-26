#!/usr/bin/env bash
# Emülatörde integration_test ekran turunu çalıştırır; çıktılar /tmp/screens-out'a.
OUT=/tmp/screens-out; mkdir -p "$OUT"
exec > >(tee -a "$OUT/run.txt") 2>&1
set -x
adb devices
adb shell wm size
# Telefon benzeri çözünürlük (varsayılan emülatör ekranı çok küçük)
adb shell wm size 1080x2340
adb shell wm density 440
sleep 5
adb shell wm size
adb shell getprop ro.build.version.sdk
flutter devices
flutter drive -d emulator-5554 --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk --driver=test_driver/integration_test.dart --target=integration_test/screens_test.dart > "$OUT/drive.txt" 2>&1
echo "drive exit: $?" >> "$OUT/drive.txt"
adb logcat -d | grep -E "flutter|AndroidRuntime|FATAL" | tail -300 > "$OUT/logcat.txt"
exit 0
