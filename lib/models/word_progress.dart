/// Bir kelimenin kullanıcıya özel öğrenme durumu (SM-2 alanları + istatistik).
class WordProgress {
  const WordProgress({
    required this.wordId,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    this.dueDate,
    this.lastReviewed,
    this.timesSeen = 0,
    this.timesCorrect = 0,
    this.inMistakes = false,
  });

  final String wordId;
  final double easeFactor;
  final int interval; // gün
  final int repetitions;
  final DateTime? dueDate;
  final DateTime? lastReviewed;
  final int timesSeen;
  final int timesCorrect;

  /// "Hataları Çalış" listesinde mi?
  final bool inMistakes;

  /// Aralık bu kadar güne ulaşınca kelime "ustalaşıldı" sayılır.
  static const masteredIntervalDays = 21;

  bool get isMastered => interval >= masteredIntervalDays;
  bool get isStarted => timesSeen > 0;

  bool isDue(DateTime now) => isStarted && dueDate != null && !dueDate!.isAfter(now);

  WordProgress copyWith({
    double? easeFactor,
    int? interval,
    int? repetitions,
    DateTime? dueDate,
    DateTime? lastReviewed,
    int? timesSeen,
    int? timesCorrect,
    bool? inMistakes,
  }) =>
      WordProgress(
        wordId: wordId,
        easeFactor: easeFactor ?? this.easeFactor,
        interval: interval ?? this.interval,
        repetitions: repetitions ?? this.repetitions,
        dueDate: dueDate ?? this.dueDate,
        lastReviewed: lastReviewed ?? this.lastReviewed,
        timesSeen: timesSeen ?? this.timesSeen,
        timesCorrect: timesCorrect ?? this.timesCorrect,
        inMistakes: inMistakes ?? this.inMistakes,
      );

  Map<String, Object?> toMap() => {
        'word_id': wordId,
        'ease': easeFactor,
        'interval_days': interval,
        'reps': repetitions,
        'due': dueDate?.millisecondsSinceEpoch,
        'last_reviewed': lastReviewed?.millisecondsSinceEpoch,
        'seen': timesSeen,
        'correct': timesCorrect,
        'in_mistakes': inMistakes ? 1 : 0,
      };

  factory WordProgress.fromMap(Map<String, Object?> m) {
    DateTime? d(Object? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
    return WordProgress(
      wordId: m['word_id'] as String,
      easeFactor: (m['ease'] as num).toDouble(),
      interval: m['interval_days'] as int,
      repetitions: m['reps'] as int,
      dueDate: d(m['due']),
      lastReviewed: d(m['last_reviewed']),
      timesSeen: m['seen'] as int,
      timesCorrect: m['correct'] as int,
      inMistakes: (m['in_mistakes'] as int) == 1,
    );
  }
}
