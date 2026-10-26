import '../config/app_config.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// Takvim günü farkı (yaz saati değişimine dayanıklı).
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Bir günün çalışma istatistiği + kota durumu.
class DailyStats {
  const DailyStats({
    required this.day,
    this.studied = 0,
    this.correct = 0,
    this.wrong = 0,
    this.dontKnow = 0,
    this.newWords = 0,
    this.adsWatched = 0,
  });

  final String day;
  final int studied;
  final int correct;
  final int wrong;
  final int dontKnow;
  final int newWords;
  final int adsWatched;

  factory DailyStats.empty(DateTime now) => DailyStats(day: dayKey(now));

  /// Ücretsiz kullanıcının bugünkü toplam hakkı (reklamla kazanılanlar dahil).
  int get freeAllowance => AppConfig.dailyFreeWords + adsWatched * AppConfig.rewardedBonusWords;

  int remainingFree() => (freeAllowance - studied).clamp(0, 1 << 30);

  bool get canWatchRewardedAd {
    final max = AppConfig.maxRewardedAdsPerDay;
    return max == null || adsWatched < max;
  }

  DailyStats copyWith({int? studied, int? correct, int? wrong, int? dontKnow, int? newWords, int? adsWatched}) =>
      DailyStats(
        day: day,
        studied: studied ?? this.studied,
        correct: correct ?? this.correct,
        wrong: wrong ?? this.wrong,
        dontKnow: dontKnow ?? this.dontKnow,
        newWords: newWords ?? this.newWords,
        adsWatched: adsWatched ?? this.adsWatched,
      );

  Map<String, Object?> toJson() => {
        'day': day,
        'studied': studied,
        'correct': correct,
        'wrong': wrong,
        'dontKnow': dontKnow,
        'newWords': newWords,
        'ads': adsWatched,
      };

  factory DailyStats.fromJson(Map<String, dynamic> j) => DailyStats(
        day: j['day'] as String,
        studied: j['studied'] as int? ?? 0,
        correct: j['correct'] as int? ?? 0,
        wrong: j['wrong'] as int? ?? 0,
        dontKnow: j['dontKnow'] as int? ?? 0,
        newWords: j['newWords'] as int? ?? 0,
        adsWatched: j['ads'] as int? ?? 0,
      );
}

/// Seri (streak) durumu.
class StreakState {
  const StreakState({this.current = 0, this.best = 0, this.lastActiveDay, this.freezes = 0});

  final int current;
  final int best;
  final String? lastActiveDay;

  /// Seri dondurma hakkı: bir günü kaçırınca seri bozulmaz, hak harcanır.
  final int freezes;

  static const maxFreezes = 2;

  /// Bugün çalışıldı mı?
  bool activeOn(DateTime now) => lastActiveDay == dayKey(now);

  /// Bugünden bakınca hâlâ geçerli seri (dün çalışılmadıysa ve dondurma yoksa 0).
  int displayStreak(DateTime now) {
    if (lastActiveDay == null) return 0;
    final gap = daysBetween(DateTime.parse(lastActiveDay!), _dayStart(now));
    if (gap <= 1) return current;
    if (gap - 1 <= freezes) return current; // dondurmayla korunuyor
    return 0;
  }

  /// Bugün bir çalışma tamamlandığında çağrılır.
  StreakState registerActivity(DateTime now) {
    final today = dayKey(now);
    if (lastActiveDay == today) return this;
    if (lastActiveDay == null) {
      return StreakState(current: 1, best: best < 1 ? 1 : best, lastActiveDay: today, freezes: freezes);
    }
    final gap = daysBetween(DateTime.parse(lastActiveDay!), _dayStart(now));
    var next = 1;
    var f = freezes;
    if (gap == 1) {
      next = current + 1;
    } else if (gap > 1 && gap - 1 <= freezes) {
      f = freezes - (gap - 1);
      next = current + 1;
    }
    return StreakState(current: next, best: next > best ? next : best, lastActiveDay: today, freezes: f);
  }

  StreakState addFreeze() =>
      StreakState(current: current, best: best, lastActiveDay: lastActiveDay, freezes: (freezes + 1).clamp(0, maxFreezes));

  Map<String, Object?> toJson() => {'current': current, 'best': best, 'last': lastActiveDay, 'freezes': freezes};

  factory StreakState.fromJson(Map<String, dynamic> j) => StreakState(
        current: j['current'] as int? ?? 0,
        best: j['best'] as int? ?? 0,
        lastActiveDay: j['last'] as String?,
        freezes: j['freezes'] as int? ?? 0,
      );
}
