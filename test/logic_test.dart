import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ingilizce_calisma_kartlari/logic/answer_checker.dart';
import 'package:ingilizce_calisma_kartlari/logic/badges.dart';
import 'package:ingilizce_calisma_kartlari/logic/daily.dart';
import 'package:ingilizce_calisma_kartlari/logic/session_builder.dart';
import 'package:ingilizce_calisma_kartlari/logic/srs.dart';
import 'package:ingilizce_calisma_kartlari/models/word.dart';
import 'package:ingilizce_calisma_kartlari/models/word_progress.dart';

void main() {
  group('AnswerChecker', () {
    const c = AnswerChecker();

    test('birebir ve büyük/küçük harf', () {
      expect(c.check('söylemek', ['söylemek', 'demek']).verdict, AnswerVerdict.correct);
      expect(c.check('  Demek ', ['söylemek', 'demek']).verdict, AnswerVerdict.correct);
    });

    test('Türkçe karakter olmadan yazılan cevap doğru sayılır', () {
      expect(c.check('soylemek', ['söylemek']).verdict, AnswerVerdict.correct);
      expect(c.check('ISIK', ['ışık']).verdict, AnswerVerdict.correct);
    });

    test('küçük yazım hatası neredeyse doğru', () {
      final r = c.check('kahvaltu', ['kahvaltı']);
      expect(r.verdict, AnswerVerdict.almost);
      expect(r.matched, 'kahvaltı');
    });

    test('kısa kelimede yazım hatası kabul edilmez', () {
      expect(c.check('ek', ['et']).verdict, AnswerVerdict.wrong);
    });

    test('parantez içi açıklama yok sayılır', () {
      expect(c.check('o', ['o (erkek)']).verdict, AnswerVerdict.correct);
    });

    test('İngilizcede "to" ve artikel yok sayılır', () {
      expect(c.check('to go', ['go']).verdict, AnswerVerdict.correct);
      expect(c.check('an apple', ['apple']).verdict, AnswerVerdict.correct);
    });

    test('yanlış ve boş cevap', () {
      expect(c.check('gelmek', ['gitmek']).verdict, AnswerVerdict.wrong);
      expect(c.check('   ', ['gitmek']).verdict, AnswerVerdict.wrong);
    });
  });

  group('SM-2', () {
    final now = DateTime(2026, 10, 25, 12);
    const fresh = WordProgress(wordId: 'x');

    test('doğru + Biliyorum: 1 gün, sonra 6 gün', () {
      final a = applySm2(fresh, gradeFor(correct: true, rating: RecallRating.known), now, correct: true);
      expect(a.interval, 1);
      expect(a.inMistakes, isFalse);
      final b = applySm2(a, Sm2Grade.good, now, correct: true);
      expect(b.interval, 6);
      expect(b.timesSeen, 2);
      expect(b.timesCorrect, 2);
    });

    test('yanlış cevap etiketten bağımsız olarak hata listesine girer', () {
      final a = applySm2(fresh, gradeFor(correct: false, rating: RecallRating.known), now, correct: false);
      expect(a.repetitions, 0);
      expect(a.inMistakes, isTrue);
      expect(a.easeFactor, closeTo(2.3, 1e-9));
      expect(a.isDue(now.add(const Duration(minutes: 11))), isTrue);
    });

    test('ease 1.3 altına inmez', () {
      var p = fresh;
      for (var i = 0; i < 20; i++) {
        p = applySm2(p, Sm2Grade.again, now, correct: false);
      }
      expect(p.easeFactor, closeTo(1.3, 1e-9));
    });
  });

  group('Kota', () {
    test('günlük 20 + reklam başına 5, en fazla 3 reklam', () {
      var d = DailyStats.empty(DateTime(2026, 10, 25));
      expect(d.remainingFree(), 20);
      d = d.copyWith(studied: 20);
      expect(d.remainingFree(), 0);
      d = d.copyWith(adsWatched: 1);
      expect(d.remainingFree(), 5);
      expect(d.canWatchRewardedAd, isTrue);
      d = d.copyWith(adsWatched: 3);
      expect(d.canWatchRewardedAd, isFalse);
      expect(d.remainingFree(), 15);
    });
  });

  group('Seri', () {
    test('art arda günler seriyi artırır, gün atlanınca sıfırlanır', () {
      var s = const StreakState();
      s = s.registerActivity(DateTime(2026, 10, 1, 9));
      s = s.registerActivity(DateTime(2026, 10, 1, 22)); // aynı gün
      expect(s.current, 1);
      s = s.registerActivity(DateTime(2026, 10, 2, 8));
      expect(s.current, 2);
      expect(s.displayStreak(DateTime(2026, 10, 3)), 2);
      expect(s.displayStreak(DateTime(2026, 10, 4)), 0);
      s = s.registerActivity(DateTime(2026, 10, 5));
      expect(s.current, 1);
      expect(s.best, 2);
    });

    test('seri dondurma bir kaçırılan günü kurtarır', () {
      var s = const StreakState().registerActivity(DateTime(2026, 10, 1)).addFreeze();
      expect(s.displayStreak(DateTime(2026, 10, 3)), 1);
      s = s.registerActivity(DateTime(2026, 10, 3));
      expect(s.current, 2);
      expect(s.freezes, 0);
    });
  });

  group('Rozetler', () {
    test('eşik aşılınca kazanılır, tekrar verilmez', () {
      const stats = BadgeStats(wordsStudied: 25, wordsMastered: 0, bestStreak: 3, sessions: 1, perfectSessions: 0, totalCorrect: 17);
      final ids = newlyEarned(stats, {}).map((b) => b.id).toSet();
      expect(ids, containsAll(['first_session', 'explore_25', 'streak_3']));
      expect(newlyEarned(stats, ids), isEmpty);
    });

    test('rozet kimlikleri benzersiz', () {
      final ids = allBadges.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('Kelime verisi ve oturum', () {
    late List<Word> words;
    setUpAll(() {
      final raw = File('assets/data/words.json').readAsStringSync();
      words = [for (final j in jsonDecode(raw) as List) Word.fromJson(j as Map<String, dynamic>)];
    });

    test('veri geçerli', () {
      expect(words.length, greaterThan(500));
      expect(words.map((w) => w.id).toSet().length, words.length);
      for (final w in words) {
        expect(w.tr, isNotEmpty, reason: w.id);
        expect(w.exampleEn, isNotEmpty, reason: w.id);
      }
    });

    test('oturum yeni kelimelerle dolar, seviye filtresine uyar', () {
      final s = buildSession(
        words: words,
        progress: {},
        request: const SessionRequest(size: 20, level: 'A1'),
        now: DateTime(2026, 10, 25),
        random: Random(1),
      );
      expect(s.length, 20);
      expect(s.every((w) => w.level == 'A1'), isTrue);
      expect(s.map((w) => w.id).toSet().length, 20);
    });

    test('altı seviyenin hepsinde kelime var', () {
      for (final l in levelOrder) {
        expect(words.where((w) => w.level == l).length, greaterThan(100), reason: l);
      }
    });

    test('yeni kelimeler hedef seviyeden gelir (C1 hedefi A1 kelimesi getirmez)', () {
      for (final target in ['B2', 'C1', 'C2']) {
        final s = buildSession(
          words: words,
          progress: {},
          request: SessionRequest(size: 20, level: target),
          now: DateTime(2026, 10, 26),
          random: Random(3),
        );
        expect(s.length, 20);
        expect(s.every((w) => w.level == target), isTrue, reason: target);
      }
    });

    test('hedef seviye bitince bir alt seviyeye geçer', () {
      final now = DateTime(2026, 10, 26);
      final seenB1 = {
        for (final w in words.where((w) => w.level == 'B1'))
          w.id: WordProgress(wordId: w.id, timesSeen: 1, interval: 30, dueDate: now.add(const Duration(days: 30))),
      };
      final s = buildSession(
          words: words, progress: seenB1, request: const SessionRequest(size: 20, level: 'B1'), now: now, random: Random(4));
      expect(s.every((w) => w.level == 'A2'), isTrue);
    });

    test('zamanı gelen tekrarlar önce gelir', () {
      final now = DateTime(2026, 10, 25, 12);
      final due = {
        for (final w in words.take(5))
          w.id: WordProgress(wordId: w.id, timesSeen: 1, interval: 1, dueDate: now.subtract(const Duration(days: 1))),
      };
      final s = buildSession(words: words, progress: due, request: const SessionRequest(size: 20, level: 'A2'), now: now);
      expect(s.where((w) => due.containsKey(w.id)).length, 5);
    });

    test('hata oturumu sadece hata listesindekileri içerir', () {
      final m = {words[3].id: WordProgress(wordId: words[3].id, timesSeen: 1, inMistakes: true)};
      final s = buildSession(
        words: words,
        progress: m,
        request: const SessionRequest(size: 20, level: allLevels, kind: SessionKind.mistakes),
        now: DateTime(2026, 10, 25),
      );
      expect(s.map((w) => w.id), [words[3].id]);
    });

    test('çoktan seçmeli seçenekleri doğru cevabı içermez ve tekrarsız', () {
      final target = words.firstWhere((w) => w.en == 'sagen' || w.en == 'say');
      final d = distractorsFor(target, words, random: Random(2));
      expect(d.length, 3);
      expect(d.toSet().length, 3);
      expect(d.any(target.tr.contains), isFalse);
    });
  });
}
