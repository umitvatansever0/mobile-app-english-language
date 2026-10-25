import 'dart:math' as math;

import '../models/word.dart';
import '../models/word_progress.dart';

/// Çalışma modu.
enum StudyMode {
  typeTr('Yazarak (EN → TR)', 'İngilizce kelimeyi gör, Türkçesini yaz'),
  typeEn('Ters yön (TR → EN)', 'Türkçesini gör, İngilizcesini yaz'),
  choice('Çoktan seçmeli', '4 seçenekten doğrusunu seç'),
  listen('Dinle ve yaz', 'Kelimeyi dinle, İngilizcesini yaz');

  const StudyMode(this.label, this.description);
  final String label;
  final String description;

  bool get isPremium => this == StudyMode.typeEn || this == StudyMode.listen;
}

enum SessionKind { normal, mistakes }

class SessionRequest {
  const SessionRequest({
    required this.size,
    required this.level,
    this.categories = const {},
    this.topics = const {},
    this.kind = SessionKind.normal,
  });

  final int size;

  /// Hedef seviye ve altındaki seviyeler dahil edilir.
  final String level;
  final Set<StudyCategory> categories; // boş = hepsi
  final Set<String> topics; // boş = hepsi
  final SessionKind kind;
}

const levelOrder = ['A1', 'A2', 'B1', 'B2', 'C1'];

bool _levelIncluded(String wordLevel, String target) {
  final w = levelOrder.indexOf(wordLevel);
  final t = levelOrder.indexOf(target);
  if (w < 0 || t < 0) return true;
  return w <= t;
}

/// Oturum için kelime seçer. Öncelik sırası:
/// 1) zamanı gelmiş tekrarlar (en gecikmiş önce)
/// 2) hata listesindekiler
/// 3) yeni kelimeler (seviye sırasıyla, hedef seviyenin kendisi en sona kalmasın diye karışık)
List<Word> buildSession({
  required List<Word> words,
  required Map<String, WordProgress> progress,
  required SessionRequest request,
  required DateTime now,
  math.Random? random,
}) {
  final rnd = random ?? math.Random();
  bool matches(Word w) =>
      (w.isCustom || _levelIncluded(w.level, request.level)) &&
      (request.categories.isEmpty || request.categories.contains(w.pos.category)) &&
      (request.topics.isEmpty || request.topics.contains(w.topic));

  final pool = words.where(matches).toList();

  if (request.kind == SessionKind.mistakes) {
    final m = pool.where((w) => progress[w.id]?.inMistakes ?? false).toList()..shuffle(rnd);
    return m.take(request.size).toList();
  }

  final due = pool.where((w) => progress[w.id]?.isDue(now) ?? false).toList()
    ..sort((a, b) => progress[a.id]!.dueDate!.compareTo(progress[b.id]!.dueDate!));
  final mistakes =
      pool.where((w) => (progress[w.id]?.inMistakes ?? false) && !due.contains(w)).toList()..shuffle(rnd);
  final fresh = pool.where((w) => !(progress[w.id]?.isStarted ?? false)).toList();
  // Seviye seviye karıştır: önce düşük seviyedeki yeni kelimeler gelir.
  fresh.sort((a, b) => levelOrder.indexOf(a.level).compareTo(levelOrder.indexOf(b.level)));
  final byLevel = <String, List<Word>>{};
  for (final w in fresh) {
    byLevel.putIfAbsent(w.level, () => []).add(w);
  }
  final freshOrdered = <Word>[for (final l in byLevel.values) ...(l..shuffle(rnd))];

  // Her oturumda en az ~%40 yeni kelime olsun ki ilerleme hissedilsin.
  final minFresh = math.min(freshOrdered.length, (request.size * 0.4).ceil());
  final reviewSlots = request.size - minFresh;
  final reviews = [...due, ...mistakes].take(reviewSlots).toList();
  final out = <Word>[...reviews, ...freshOrdered.take(request.size - reviews.length)];

  // Hâlâ boşluk varsa (yeni kelime bittiyse) tekrar edilmiş kelimelerle doldur.
  if (out.length < request.size) {
    final rest = pool.where((w) => !out.contains(w)).toList()..shuffle(rnd);
    out.addAll(rest.take(request.size - out.length));
  }
  return out..shuffle(rnd);
}

/// Çoktan seçmeli mod için 3 yanlış seçenek üretir (mümkünse aynı türden).
List<String> distractorsFor(Word target, List<Word> all, {math.Random? random, int count = 3}) {
  final rnd = random ?? math.Random();
  final same = all.where((w) => w.id != target.id && w.pos == target.pos && w.mainTr != target.mainTr).toList()
    ..shuffle(rnd);
  final picked = <String>{};
  for (final w in same) {
    if (picked.length >= count) break;
    if (!target.tr.contains(w.mainTr)) picked.add(w.mainTr);
  }
  if (picked.length < count) {
    final other = all.where((w) => w.id != target.id).toList()..shuffle(rnd);
    for (final w in other) {
      if (picked.length >= count) break;
      if (!target.tr.contains(w.mainTr)) picked.add(w.mainTr);
    }
  }
  return picked.toList();
}
