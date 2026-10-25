import 'dart:math' as math;

/// Cevap kontrol sonucu.
enum AnswerVerdict {
  /// Birebir (normalize edilmiş haliyle) doğru.
  correct,

  /// Küçük bir yazım hatasıyla doğru kabul edildi.
  almost,
  wrong,
}

class AnswerResult {
  const AnswerResult(this.verdict, {this.matched});
  final AnswerVerdict verdict;

  /// Eşleşen kabul edilen cevap (doğru yazımı göstermek için).
  final String? matched;

  bool get isAccepted => verdict != AnswerVerdict.wrong;
}

/// Türkçe/İngilizce cevapları hoşgörülü biçimde karşılaştırır:
/// - büyük/küçük harf, baştaki/sondaki boşluk ve noktalama önemsiz
/// - Türkçe karakterler: "soylemek" de "söylemek" için kabul edilir
/// - parantez içi açıklamalar yok sayılır: "o (erkek)" -> "o"
/// - İngilizcede baştaki "to " ve "a/an/the" yok sayılır
/// - uzun kelimelerde 1-2 harflik yazım hatası "neredeyse doğru" sayılır
class AnswerChecker {
  const AnswerChecker();

  AnswerResult check(String input, List<String> accepted) {
    final given = _normalize(input);
    if (given.isEmpty) return const AnswerResult(AnswerVerdict.wrong);
    final givenAscii = _asciiFold(given);

    String? almostMatch;
    for (final raw in accepted) {
      for (final variant in _variants(raw)) {
        if (variant == given) return AnswerResult(AnswerVerdict.correct, matched: raw);
        final vAscii = _asciiFold(variant);
        if (vAscii == givenAscii) return AnswerResult(AnswerVerdict.correct, matched: raw);
        if (almostMatch == null && _withinTypoTolerance(givenAscii, vAscii)) {
          almostMatch = raw;
        }
      }
    }
    if (almostMatch != null) return AnswerResult(AnswerVerdict.almost, matched: almostMatch);
    return const AnswerResult(AnswerVerdict.wrong);
  }

  Iterable<String> _variants(String raw) sync* {
    final n = _normalize(raw);
    if (n.isEmpty) return;
    yield n;
    final noParen = _normalize(raw.replaceAll(RegExp(r'\([^)]*\)'), ''));
    if (noParen.isNotEmpty && noParen != n) yield noParen;
  }

  static String _normalize(String s) {
    var t = _turkishLower(s.trim());
    t = t.replaceAll(RegExp(r"[.,!?;:’'\x22]"), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceFirst(RegExp(r'^(to|a|an|the) '), '');
    return t;
  }

  /// Dart'ın toLowerCase'i "I" -> "i" yapar; Türkçede "I" -> "ı", "İ" -> "i".
  static String _turkishLower(String s) =>
      s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  static String _asciiFold(String s) {
    const map = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', 'â': 'a', 'î': 'i', 'û': 'u'};
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(map[ch] ?? ch);
    }
    return b.toString();
  }

  static bool _withinTypoTolerance(String a, String b) {
    final len = math.max(a.length, b.length);
    if (len < 5) return false;
    final allowed = len >= 9 ? 2 : 1;
    if ((a.length - b.length).abs() > allowed) return false;
    return levenshtein(a, b) <= allowed;
  }

  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var cur = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      final tmp = prev;
      prev = cur;
      cur = tmp;
    }
    return prev[b.length];
  }
}
