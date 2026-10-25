import 'dart:math' as math;

import '../models/word_progress.dart';

/// Kullanıcının kart sonrası seçtiği etiket.
enum RecallRating {
  forgot('Unuttum'),
  learning('Öğreniyorum'),
  known('Biliyorum');

  const RecallRating(this.label);
  final String label;
}

/// SM-2 notları (weblearningapp/src/lib/spacedRepetition.ts'den aktarıldı).
enum Sm2Grade { again, hard, good, easy }

const _minEase = 1.3;

/// Cevabın doğruluğu + kullanıcının etiketi -> SM-2 notu.
/// Yanlış cevap her zaman "again" sayılır; doğru cevapta etiket belirleyicidir.
Sm2Grade gradeFor({required bool correct, required RecallRating rating}) {
  if (!correct) return Sm2Grade.again;
  return switch (rating) {
    RecallRating.forgot => Sm2Grade.again,
    RecallRating.learning => Sm2Grade.hard,
    RecallRating.known => Sm2Grade.good,
  };
}

/// SM-2 algoritmasını uygular ve yeni ilerlemeyi döndürür.
WordProgress applySm2(WordProgress p, Sm2Grade grade, DateTime now, {required bool correct}) {
  int reps;
  int interval;
  double ease;

  switch (grade) {
    case Sm2Grade.again:
      reps = 0;
      interval = 0; // aynı gün içinde tekrar gelebilsin
      ease = math.max(_minEase, p.easeFactor - 0.2);
    case Sm2Grade.hard:
      reps = p.repetitions + 1;
      interval = reps == 1 ? 1 : (p.interval * 1.2).ceil();
      ease = math.max(_minEase, p.easeFactor - 0.15);
    case Sm2Grade.good:
      reps = p.repetitions + 1;
      interval = reps == 1
          ? 1
          : reps == 2
              ? 6
              : (p.interval * p.easeFactor).ceil();
      ease = p.easeFactor;
    case Sm2Grade.easy:
      reps = p.repetitions + 1;
      interval = reps == 1
          ? 4
          : reps == 2
              ? 10
              : (p.interval * p.easeFactor * 1.3).ceil();
      ease = p.easeFactor + 0.15;
  }

  final due = interval == 0
      ? now.add(const Duration(minutes: 10))
      : DateTime(now.year, now.month, now.day).add(Duration(days: interval));

  return p.copyWith(
    repetitions: reps,
    interval: interval,
    easeFactor: ease,
    dueDate: due,
    lastReviewed: now,
    timesSeen: p.timesSeen + 1,
    timesCorrect: p.timesCorrect + (correct ? 1 : 0),
    // Yanlış/unutulan kelime hata listesine girer, doğru bilinince çıkar.
    inMistakes: grade == Sm2Grade.again,
  );
}
