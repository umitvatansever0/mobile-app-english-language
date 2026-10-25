#!/usr/bin/env bash
# Emülatörde uygulamayı kurup açar; logcat ve ekran görüntüsünü /tmp/smoke-out'a yazar.
set -x
OUT=/tmp/smoke-out; mkdir -p $OUT
PKG=com.umitvatansever.ingilizce_calisma_kartlari
adb install -r /tmp/ingilizce-kartlar.apk > $OUT/install.txt 2>&1
adb logcat -c
adb shell am start -W -n $PKG/.MainActivity > $OUT/start.txt 2>&1
sleep 25
adb shell pidof $PKG > $OUT/pid.txt 2>&1 || echo "PROCESS NOT RUNNING" >> $OUT/pid.txt
adb exec-out screencap -p > $OUT/screen1.png
# Tanıtımdaki "Atla" + "Başlayalım" yerine ekranın altına dokun (İleri düğmesi)
for i in 1 2 3 4; do adb shell input tap 540 2200; sleep 2; done
sleep 8
adb exec-out screencap -p > $OUT/screen2.png
adb shell pidof $PKG >> $OUT/pid.txt 2>&1 || echo "PROCESS NOT RUNNING (after taps)" >> $OUT/pid.txt
adb logcat -d > $OUT/logcat-full.txt
grep -E "AndroidRuntime|FATAL|flutter|E/|Exception|ingilizce" $OUT/logcat-full.txt | tail -400 > $OUT/logcat-errors.txt
adb shell wm size > $OUT/wm.txt
exit 0
