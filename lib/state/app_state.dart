import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../data/database.dart';
import '../data/prefs_store.dart';
import '../logic/badges.dart';
import '../logic/daily.dart';
import '../logic/session_builder.dart';
import '../logic/srs.dart';
import '../models/word.dart';
import '../models/word_progress.dart';
import '../services/ads_service.dart';
import '../services/purchase_service.dart';
import '../services/tts_service.dart';

/// Bir kartın oturum içindeki sonucu.
enum CardOutcome { correct, wrong, dontKnow }

/// Oturum sonu özeti.
class SessionSummary {
  SessionSummary({required this.total, required this.correct, required this.wrong, required this.dontKnow,
      required this.ratings, required this.newBadges, required this.streak});
  final int total;
  final int correct;
  final int wrong;
  final int dontKnow;
  final Map<RecallRating, int> ratings;
  final List<BadgeDef> newBadges;
  final int streak;

  double get accuracy => total == 0 ? 0 : correct / total;
}

class AppState extends ChangeNotifier {
  AppState._(this._db, this._prefs, this.tts, this.ads, this.purchases);

  final AppDatabase _db;
  final PrefsStore _prefs;
  final TtsService tts;
  final AdsService ads;
  final PurchaseService purchases;

  List<Word> _builtIn = [];
  List<Word> _custom = [];
  Map<String, WordProgress> _progress = {};
  Map<String, DailyStats> _history = {};
  StreakState _streak = const StreakState();
  Set<String> _earned = {};

  static Future<AppState> load() async {
    final db = await AppDatabase.open();
    final prefs = await PrefsStore.open();
    final state = AppState._(db, prefs, TtsService(), AdsService(), PurchaseService());
    final raw = await rootBundle.loadString('assets/data/words.json');
    state._builtIn = [for (final j in jsonDecode(raw) as List) Word.fromJson(j as Map<String, dynamic>)];
    state._custom = await db.loadCustomWords();
    state._progress = await db.loadProgress();
    state._history = prefs.loadHistory();
    state._streak = prefs.loadStreak();
    state._earned = prefs.earnedBadges;
    // Ses ve abonelik başlatma açılışı asla bekletmesin.
    unawaited(state.tts.init(prefs.accent).timeout(const Duration(seconds: 5), onTimeout: () {}).catchError((Object e) {
      debugPrint('TTS init hata: $e');
    }));
    unawaited(state.purchases.init(cachedPremium: prefs.cachedPremium).timeout(const Duration(seconds: 8), onTimeout: () {}).catchError((Object e) {
      debugPrint('Purchases init hata: $e');
    }));
    state.purchases.isPremium.addListener(() {
      prefs.cachedPremium = state.purchases.isPremium.value;
      state.notifyListeners();
    });
    return state;
  }

  /// Reklam SDK'sı ve onay formu: ilk karede değil, ana ekran açıldıktan sonra.
  Future<void> initAdsIfNeeded() async {
    if (!isPremium) await ads.init();
  }

  // ---------------- Okuma ----------------
  bool get isPremium => purchases.isPremium.value;
  bool get onboardingDone => _prefs.onboardingDone;
  String get targetLevel => _prefs.targetLevel;
  bool get vibration => _prefs.vibration;
  bool get autoPlayAudio => _prefs.autoPlayAudio;
  String get accent => _prefs.accent;
  StudyMode get studyMode =>
      StudyMode.values.firstWhere((m) => m.name == _prefs.studyMode, orElse: () => StudyMode.typeTr);
  ThemeMode get themeMode => switch (_prefs.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  List<Word> get allWords => [..._custom, ..._builtIn];
  List<Word> get customWords => List.unmodifiable(_custom);
  int get totalWordCount => _builtIn.length;
  WordProgress? progressOf(String id) => _progress[id];

  DailyStats get today {
    final now = DateTime.now();
    return _history[dayKey(now)] ?? DailyStats.empty(now);
  }

  Map<String, DailyStats> get history => Map.unmodifiable(_history);
  int get streak => _streak.displayStreak(DateTime.now());
  int get bestStreak => _streak.best;
  int get streakFreezes => _streak.freezes;
  bool get studiedToday => _streak.activeOn(DateTime.now());

  int get studiedWordCount => _progress.values.where((p) => p.isStarted).length;
  int get masteredCount => _progress.values.where((p) => p.isMastered).length;
  int get mistakesCount => allWords.where((w) => _progress[w.id]?.inMistakes ?? false).length;
  int get dueCount {
    final now = DateTime.now();
    return _progress.values.where((p) => p.isDue(now)).length;
  }

  /// Seçili hedef seviyedeki kelime sayısı ve ustalaşılanlar.
  ({int total, int mastered}) levelProgress(String level) {
    final ws = _builtIn.where((w) => w.level == level);
    final mastered = ws.where((w) => _progress[w.id]?.isMastered ?? false).length;
    return (total: ws.length, mastered: mastered);
  }

  Set<String> get earnedBadgeIds => Set.unmodifiable(_earned);

  /// Ücretsiz kullanıcının bugün çalışabileceği kalan kart sayısı (premium: sınırsız).
  int get remainingToday => isPremium ? 1 << 30 : today.remainingFree();

  bool get canWatchRewardedAd => !isPremium && today.canWatchRewardedAd;

  // ---------------- Ayarlar ----------------
  void completeOnboarding(String level) {
    _prefs.targetLevel = level;
    _prefs.onboardingDone = true;
    notifyListeners();
  }

  void setTargetLevel(String level) {
    _prefs.targetLevel = level;
    notifyListeners();
  }

  void setVibration(bool v) {
    _prefs.vibration = v;
    notifyListeners();
  }

  void setAutoPlay(bool v) {
    _prefs.autoPlayAudio = v;
    notifyListeners();
  }

  Future<void> setAccent(String a) async {
    _prefs.accent = a;
    await tts.setAccent(a);
    notifyListeners();
  }

  void setThemeMode(String m) {
    _prefs.themeMode = m;
    notifyListeners();
  }

  void setStudyMode(StudyMode m) {
    _prefs.studyMode = m.name;
    notifyListeners();
  }

  // ---------------- Oturum ----------------
  List<Word> buildSessionWords(SessionRequest req) {
    final size = isPremium ? req.size : req.size.clamp(0, remainingToday);
    return buildSession(
      words: allWords,
      progress: _progress,
      request: SessionRequest(size: size, level: req.level, categories: req.categories, topics: req.topics, kind: req.kind),
      now: DateTime.now(),
    );
  }

  void haptic(bool positive) {
    if (!vibration) return;
    positive ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
  }

  /// Her kart için: SM-2 güncelle, günlük sayaçları artır.
  Future<void> recordCard(Word w, CardOutcome outcome, RecallRating rating) async {
    final now = DateTime.now();
    final before = _progress[w.id] ?? WordProgress(wordId: w.id);
    final correct = outcome == CardOutcome.correct;
    final after = applySm2(before, gradeFor(correct: correct, rating: rating), now, correct: correct);
    _progress[w.id] = after;
    await _db.saveProgress(after);

    final d = today;
    _history[d.day] = d.copyWith(
      studied: d.studied + 1,
      correct: d.correct + (outcome == CardOutcome.correct ? 1 : 0),
      wrong: d.wrong + (outcome == CardOutcome.wrong ? 1 : 0),
      dontKnow: d.dontKnow + (outcome == CardOutcome.dontKnow ? 1 : 0),
      newWords: d.newWords + (before.isStarted ? 0 : 1),
    );
    if (correct) _prefs.totalCorrect = _prefs.totalCorrect + 1;
    await _prefs.saveHistory(_history);
    notifyListeners();
  }

  /// Oturum bittiğinde: seri, oturum sayacı, rozetler.
  Future<SessionSummary> finishSession(List<(Word, CardOutcome, RecallRating)> results) async {
    final now = DateTime.now();
    if (results.isNotEmpty) {
      _streak = _streak.registerActivity(now);
      await _prefs.saveStreak(_streak);
      _prefs.sessionsCompleted = _prefs.sessionsCompleted + 1;
    }
    final correct = results.where((r) => r.$2 == CardOutcome.correct).length;
    if (results.length >= 10 && correct == results.length) {
      _prefs.perfectSessions = _prefs.perfectSessions + 1;
    }
    final earned = newlyEarned(
      BadgeStats(
        wordsStudied: studiedWordCount,
        wordsMastered: masteredCount,
        bestStreak: _streak.best,
        sessions: _prefs.sessionsCompleted,
        perfectSessions: _prefs.perfectSessions,
        totalCorrect: _prefs.totalCorrect,
      ),
      _earned,
    );
    if (earned.isNotEmpty) {
      _earned = {..._earned, ...earned.map((b) => b.id)};
      await _prefs.saveEarnedBadges(_earned);
    }
    notifyListeners();
    return SessionSummary(
      total: results.length,
      correct: correct,
      wrong: results.where((r) => r.$2 == CardOutcome.wrong).length,
      dontKnow: results.where((r) => r.$2 == CardOutcome.dontKnow).length,
      ratings: {for (final r in RecallRating.values) r: results.where((x) => x.$3 == r).length},
      newBadges: earned,
      streak: _streak.current,
    );
  }

  // ---------------- Reklam ödülü ----------------
  /// Ödüllü reklamı gösterir; izlenirse +3 kelime hakkı verir.
  Future<bool> watchAdForBonus() async {
    if (!canWatchRewardedAd) return false;
    final ok = await ads.showRewarded();
    if (ok) {
      final d = today;
      _history[d.day] = d.copyWith(adsWatched: d.adsWatched + 1);
      await _prefs.saveHistory(_history);
      notifyListeners();
    }
    return ok;
  }

  /// Ödüllü reklamla seri dondurma hakkı kazan.
  Future<bool> watchAdForStreakFreeze() async {
    if (isPremium || _streak.freezes >= StreakState.maxFreezes) return false;
    final ok = await ads.showRewarded();
    if (ok) {
      _streak = _streak.addFreeze();
      await _prefs.saveStreak(_streak);
      notifyListeners();
    }
    return ok;
  }

  // ---------------- Kendi kelimelerim ----------------
  Future<void> addCustomWord({required String en, required List<String> tr, required PartOfSpeech pos, String example = ''}) async {
    final w = Word(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      en: en.trim(),
      tr: tr,
      pos: pos,
      level: 'Özel',
      topic: 'custom',
      exampleEn: example.trim(),
      exampleTr: '',
      isCustom: true,
    );
    await _db.saveCustomWord(w);
    _custom = [w, ..._custom];
    notifyListeners();
  }

  Future<void> deleteCustomWord(String id) async {
    await _db.deleteCustomWord(id);
    _custom = _custom.where((w) => w.id != id).toList();
    _progress.remove(id);
    notifyListeners();
  }

  Future<void> resetProgress() async {
    await _db.resetAll();
    await _prefs.clearProgress();
    _progress = {};
    _history = {};
    _streak = const StreakState();
    _earned = {};
    notifyListeners();
  }

  bool get shouldAskForRating => !_prefs.ratePrompted && _prefs.sessionsCompleted >= 3;
  void markRatePrompted() => _prefs.ratePrompted = true;

  /// Ücretsiz modda haftalık grafik için son 7 gün.
  List<DailyStats> lastDays(int n) {
    final now = DateTime.now();
    return [
      for (var i = n - 1; i >= 0; i--)
        _history[dayKey(now.subtract(Duration(days: i)))] ?? DailyStats(day: dayKey(now.subtract(Duration(days: i)))),
    ];
  }

  static const sessionSizes = AppConfig.premiumSessionSizes;
}
