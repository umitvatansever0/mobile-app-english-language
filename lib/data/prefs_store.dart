import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logic/daily.dart';

/// Ayarlar, günlük istatistik, seri ve rozetler (küçük veriler).
class PrefsStore {
  PrefsStore(this._p);
  final SharedPreferences _p;

  static Future<PrefsStore> open() async => PrefsStore(await SharedPreferences.getInstance());

  // --- Ayarlar ---
  bool get onboardingDone => _p.getBool('onboardingDone') ?? false;
  set onboardingDone(bool v) => _p.setBool('onboardingDone', v);

  String get targetLevel => _p.getString('targetLevel') ?? 'A1';
  set targetLevel(String v) => _p.setString('targetLevel', v);

  bool get vibration => _p.getBool('vibration') ?? true;
  set vibration(bool v) => _p.setBool('vibration', v);

  bool get autoPlayAudio => _p.getBool('autoPlayAudio') ?? true;
  set autoPlayAudio(bool v) => _p.setBool('autoPlayAudio', v);

  /// 'en-US' veya 'en-GB'
  String get accent => _p.getString('accent') ?? 'en-US';
  set accent(String v) => _p.setString('accent', v);

  /// 'system' | 'light' | 'dark'
  String get themeMode => _p.getString('themeMode') ?? 'system';
  set themeMode(String v) => _p.setString('themeMode', v);

  String get studyMode => _p.getString('studyMode') ?? 'typeTr';
  set studyMode(String v) => _p.setString('studyMode', v);

  /// Premium durumunun son bilinen değeri (çevrimdışı açılış için önbellek).
  bool get cachedPremium => _p.getBool('cachedPremium') ?? false;
  set cachedPremium(bool v) => _p.setBool('cachedPremium', v);

  bool get ratePrompted => _p.getBool('ratePrompted') ?? false;
  set ratePrompted(bool v) => _p.setBool('ratePrompted', v);

  // --- Günlük istatistikler (son 60 gün tutulur) ---
  Map<String, DailyStats> loadHistory() {
    final raw = _p.getString('history');
    if (raw == null) return {};
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return {for (final j in list) j['day'] as String: DailyStats.fromJson(j)};
  }

  Future<void> saveHistory(Map<String, DailyStats> history) {
    final keys = history.keys.toList()..sort();
    final kept = keys.length > 60 ? keys.sublist(keys.length - 60) : keys;
    return _p.setString('history', jsonEncode([for (final k in kept) history[k]!.toJson()]));
  }

  // --- Seri ---
  StreakState loadStreak() {
    final raw = _p.getString('streak');
    return raw == null ? const StreakState() : StreakState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveStreak(StreakState s) => _p.setString('streak', jsonEncode(s.toJson()));

  // --- Rozetler ve sayaçlar ---
  Set<String> get earnedBadges => (_p.getStringList('badges') ?? const []).toSet();
  Future<void> saveEarnedBadges(Set<String> ids) => _p.setStringList('badges', ids.toList());

  int get sessionsCompleted => _p.getInt('sessions') ?? 0;
  set sessionsCompleted(int v) => _p.setInt('sessions', v);

  int get perfectSessions => _p.getInt('perfectSessions') ?? 0;
  set perfectSessions(int v) => _p.setInt('perfectSessions', v);

  int get totalCorrect => _p.getInt('totalCorrect') ?? 0;
  set totalCorrect(int v) => _p.setInt('totalCorrect', v);

  Future<void> clearProgress() async {
    for (final k in ['history', 'streak', 'badges', 'sessions', 'perfectSessions', 'totalCorrect']) {
      await _p.remove(k);
    }
  }
}
