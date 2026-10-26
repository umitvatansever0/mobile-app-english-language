import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingilizce_calisma_kartlari/main.dart' as app;
import 'package:ingilizce_calisma_kartlari/screens/session_screen.dart';
import 'package:ingilizce_calisma_kartlari/state/app_state.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

/// Uygulamayı baştan sona gezip her ekranın görüntüsünü alır (CI: screens.yml).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester t, [int ms = 1200]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shot(WidgetTester t, String name) async {
    await wait(t, 700);
    await binding.takeScreenshot(name);
  }

  Future<void> tapText(WidgetTester t, String text, {int ms = 1200}) async {
    await t.tap(find.text(text).last);
    await wait(t, ms);
  }

  testWidgets('ekran turu', (t) async {
    app.main();
    await wait(t, 5000);
    await binding.convertFlutterSurfaceToImage();
    await wait(t, 800);

    await shot(t, '01-tanitim');
    await tapText(t, 'Atla');
    await tapText(t, 'Orta seviye', ms: 500);
    await shot(t, '02-seviye-secimi');
    await tapText(t, 'Başlayalım', ms: 4000);
    await shot(t, '03-ana-sayfa');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await wait(t);
    await shot(t, '04-ana-sayfa-yol');
    await t.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await wait(t);

    // Kart oturumu
    await tapText(t, 'Çalışmaya başla', ms: 2500);
    await shot(t, '05-kart');
    final st = Provider.of<AppState>(t.element(find.byType(SessionScreen)), listen: false);
    final prompt = t.widget<Text>(find.byKey(const ValueKey('prompt-word'))).data!;
    final word = st.allWords.firstWhere((w) => w.en == prompt);
    await t.enterText(find.byType(TextField), word.mainTr);
    await wait(t, 500);
    await shot(t, '06-kart-yazildi');
    await tapText(t, 'Kontrol et', ms: 1500);
    await shot(t, '07-dogru');
    await tapText(t, 'Devam et', ms: 1500);
    await t.enterText(find.byType(TextField), 'yanlış cevap');
    await wait(t, 300);
    await tapText(t, 'Kontrol et', ms: 1500);
    await shot(t, '08-yanlis');
    await tapText(t, 'Devam et', ms: 1500);

    // Oturumu bitir -> rozet -> sonuç
    await t.tap(find.byTooltip('Kapat').first);
    await wait(t, 800);
    await tapText(t, 'Bitir', ms: 2500);
    if (find.text('Harika').evaluate().isNotEmpty) {
      await shot(t, '09-rozet');
      await tapText(t, 'Harika', ms: 1500);
    }
    await shot(t, '10-sonuc');
    await tapText(t, 'Tamamla', ms: 2000);

    // Sekmeler
    await t.tap(find.byIcon(Icons.school_outlined));
    await wait(t);
    await shot(t, '11-calis');
    await t.tap(find.byIcon(Icons.menu_book_outlined));
    await wait(t);
    await shot(t, '12-kelimeler');
    await t.tap(find.byIcon(Icons.person_outline_rounded));
    await wait(t);
    await shot(t, '13-profil');
    await tapText(t, "Premium'a geç", ms: 2500);
    await shot(t, '14-premium');
    await t.tap(find.byTooltip('Kapat').first);
    await wait(t);

    // Koyu tema
    st.setThemeMode('dark');
    await t.tap(find.byIcon(Icons.home_outlined));
    await wait(t, 1500);
    await shot(t, '15-ana-sayfa-koyu');
  });
}
