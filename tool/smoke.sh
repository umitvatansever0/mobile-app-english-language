#!/usr/bin/env bash
# Emülatörde uygulamayı kurup açar, tanıtımı geçip ana ekrana ve Çalış sekmesine gider.
# logcat ve ekran görüntülerini /tmp/smoke-out'a yazar.
set -x
OUT=/tmp/smoke-out; mkdir -p $OUT
PKG=com.umitvatansever.ingilizce_calisma_kartlari
adb install -r /tmp/ingilizce-kartlar.apk > $OUT/install.txt 2>&1
adb logcat -c
adb shell am start -W -n $PKG/.MainActivity > $OUT/start.txt 2>&1
sleep 25
adb shell pidof $PKG > $OUT/pid.txt 2>&1 || echo "PROCESS NOT RUNNING" >> $OUT/pid.txt
adb exec-out screencap -p > $OUT/1-onboarding.png
SIZE=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1)
W=${SIZE%x*}; H=${SIZE#*x}
echo "$W x $H" > $OUT/wm.txt
BTN_Y=$((H * 915 / 1000))   # alttaki büyük düğme (İleri / Başlayalım)
for i in 1 2 3; do adb shell input tap $((W / 2)) $BTN_Y; sleep 2; done
adb exec-out screencap -p > $OUT/2-level.png
# Seviye listesinde 3. seçenek (B1) — liste üstten başlar
adb shell input tap $((W / 2)) $((H * 50 / 100)); sleep 1
adb exec-out screencap -p > $OUT/3-level-picked.png
adb shell input tap $((W / 2)) $BTN_Y; sleep 8
adb exec-out screencap -p > $OUT/4-home.png
# Alt menü: Çalış sekmesi (2. sekme)
adb shell input tap $((W * 3 / 8)) $((H * 96 / 100)); sleep 3
adb exec-out screencap -p > $OUT/5-study.png
adb shell pidof $PKG >> $OUT/pid.txt 2>&1 || echo "PROCESS NOT RUNNING (after taps)" >> $OUT/pid.txt
adb logcat -d > $OUT/logcat-full.txt
grep -E "AndroidRuntime|FATAL|flutter|Exception" $OUT/logcat-full.txt | grep -v SliceDataConverter | tail -300 > $OUT/logcat-errors.txt
exit 0
