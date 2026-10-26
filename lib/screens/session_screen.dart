import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../logic/answer_checker.dart';
import '../logic/session_builder.dart';
import '../logic/srs.dart';
import '../models/word.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky.dart';
import 'links.dart';
import 'paywall_screen.dart';
import 'result_screen.dart';

/// Oturumu başlatır: kota kontrolü -> kelime seçimi -> kart ekranı.
Future<void> startSession(BuildContext context, SessionRequest request) async {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);

  if (!app.isPremium && app.remainingToday == 0) {
    final ok = await PaywallScreen.open(context, reason: PaywallReason.quota);
    if (!ok) return;
  }
  final words = app.buildSessionWords(request);
  if (words.isEmpty) {
    messenger.showSnackBar(SnackBar(
      content: Text(request.kind == SessionKind.mistakes
          ? 'Hata listen boş. Harika!'
          : 'Bu seçimde çalışılacak kelime kalmadı. Başka bir seviye ya da kategori dene.'),
    ));
    return;
  }
  await nav.push(MaterialPageRoute(builder: (_) => SessionScreen(words: words, mode: app.studyMode)));
}

enum _Phase { question, feedback }

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.words, required this.mode});
  final List<Word> words;
  final StudyMode mode;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _checker = const AnswerChecker();
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _results = <(Word, CardOutcome, RecallRating)>[];
  final _rnd = math.Random();

  late List<Word> _words = [...widget.words];
  int _i = 0;
  _Phase _phase = _Phase.question;
  CardOutcome? _outcome;
  AnswerResult? _answer;
  String _given = '';
  RecallRating _rating = RecallRating.known;
  List<String> _choices = const [];
  bool _saving = false;

  AppState get _app => context.read<AppState>();
  Word get _w => _words[_i];
  bool get _reverse => widget.mode == StudyMode.typeEn || widget.mode == StudyMode.listen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareCard());
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _app.tts.stop();
    super.dispose();
  }

  void _prepareCard() {
    _input.clear();
    _given = '';
    if (widget.mode == StudyMode.choice) {
      _choices = [..._app.allWords.isEmpty ? <String>[] : distractorsFor(_w, _app.allWords, random: _rnd), _w.mainTr]
        ..shuffle(_rnd);
    }
    setState(() {
      _phase = _Phase.question;
      _outcome = null;
      _answer = null;
    });
    if (widget.mode == StudyMode.listen || (_app.autoPlayAudio && widget.mode != StudyMode.typeEn)) {
      _app.tts.speak(_w.en);
    }
    if (widget.mode != StudyMode.choice) _focus.requestFocus();
  }

  void _check([String? choice]) {
    final given = choice ?? _input.text;
    if (given.trim().isEmpty) return;
    final accepted = _reverse ? [_w.en] : _w.tr;
    final res = choice != null
        ? AnswerResult(choice == _w.mainTr || _w.tr.contains(choice) ? AnswerVerdict.correct : AnswerVerdict.wrong, matched: choice)
        : _checker.check(given, accepted);
    _finishCard(res.isAccepted ? CardOutcome.correct : CardOutcome.wrong, res, given);
  }

  void _dontKnow() => _finishCard(CardOutcome.dontKnow, null, '');

  void _finishCard(CardOutcome o, AnswerResult? res, String given) {
    _focus.unfocus();
    _app.haptic(o == CardOutcome.correct);
    setState(() {
      _phase = _Phase.feedback;
      _outcome = o;
      _answer = res;
      _given = given;
      _rating = o == CardOutcome.correct ? RecallRating.known : RecallRating.forgot;
    });
    if (_app.autoPlayAudio || widget.mode == StudyMode.typeEn) _app.tts.speak(_w.en);
  }

  Future<void> _next() async {
    if (_saving) return;
    _saving = true;
    final app = _app;
    await app.recordCard(_w, _outcome!, _rating);
    _results.add((_w, _outcome!, _rating));
    _saving = false;
    if (!mounted) return;

    final hasMore = _i + 1 < _words.length;
    if (hasMore && !app.isPremium && app.remainingToday == 0) {
      final cont = await PaywallScreen.open(context, reason: PaywallReason.quota);
      if (!mounted) return;
      if (!cont) return _finish();
      if (app.isPremium) {
        // Premium'a geçti: oturumu istenen boyuta kadar tamamla.
      } else {
        // Reklamla +N hak kazandı: kalan kartları buna göre kısalt.
        final allowed = _i + 1 + app.remainingToday;
        if (allowed < _words.length) _words = _words.sublist(0, allowed);
      }
    }
    if (_i + 1 >= _words.length) return _finish();
    _i++;
    _prepareCard();
  }

  Future<void> _finish() async {
    final summary = await _app.finishSession(_results);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultScreen(summary: summary)));
  }

  Future<bool> _confirmExit() async {
    if (_results.isEmpty) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Çalışmayı bitir?'),
        content: Text('${_results.length} kelime çalıştın. İlerlemen kaydedildi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Devam et')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Bitir')),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final feedback = _phase == _Phase.feedback;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit()) {
          if (_results.isEmpty) {
            if (mounted) Navigator.of(this.context).pop();
          } else {
            await _finish();
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(children: [
            // Soru alanı (geri bildirimde soluklaşır)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: feedback ? 0.35 : 1,
              child: IgnorePointer(
                ignoring: feedback,
                child: ListView(padding: const EdgeInsets.fromLTRB(18, 6, 18, 24), children: [
                  Row(children: [
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 30, color: pal.lockInk),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Kapat',
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: ChunkyProgress(value: (_i + (feedback ? 1 : 0)) / _words.length)),
                    const SizedBox(width: 12),
                    Text('${_i + 1}/${_words.length}',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: pal.lockInk)),
                  ]),
                  const SizedBox(height: 16),
                  _questionCard(pal),
                  const SizedBox(height: 22),
                  ..._questionControls(pal),
                ]),
              ),
            ),
            // Cevap paneli
            AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: feedback ? Offset.zero : const Offset(0, 1.1),
              child: Align(alignment: Alignment.bottomCenter, child: feedback ? _feedbackSheet(pal) : const SizedBox.shrink()),
            ),
          ]),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ soru
  Widget _questionCard(Pal pal) {
    final showWord = widget.mode != StudyMode.listen;
    final prompt = widget.mode == StudyMode.typeEn ? _w.mainTr : _w.en;
    return ChunkyCard(
      key: ValueKey('q$_i'),
      lip: 7,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 30),
      child: Column(children: [
        Tag(_w.isCustom ? _w.pos.label : '${_w.pos.label} · ${_w.level}'),
        const SizedBox(height: 18),
        if (showWord)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(prompt,
                key: const ValueKey('prompt-word'),
                style: TextStyle(fontSize: 50, fontWeight: FontWeight.w900, color: pal.ink, letterSpacing: -0.5)),
          )
        else
          Text('Dinle ve yaz', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: pal.muted)),
        const SizedBox(height: 18),
        if (widget.mode != StudyMode.typeEn)
          _SpeakButton(size: widget.mode == StudyMode.listen ? 76 : 60, onTap: () => _app.tts.speak(_w.en)),
      ]),
    );
  }

  List<Widget> _questionControls(Pal pal) {
    if (widget.mode == StudyMode.choice) {
      return [
        for (final c in _choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChunkyButton(label: c, style: ChunkyStyle.ghost, onPressed: () => _check(c)),
          ),
        const SizedBox(height: 4),
        TextButton(onPressed: _dontKnow, child: const Text('Bilmiyorum')),
      ];
    }
    return [
      TextField(
        controller: _input,
        focusNode: _focus,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _check(),
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: pal.ink),
        decoration: InputDecoration(labelText: _reverse ? 'İngilizcesi' : 'Türkçe karşılığı'),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: ChunkyButton(label: 'Bilmiyorum', style: ChunkyStyle.ghost, onPressed: _dontKnow)),
        const SizedBox(width: 12),
        Expanded(
          child: ChunkyButton(label: 'Kontrol et', onPressed: _input.text.trim().isEmpty ? null : _check),
        ),
      ]),
    ];
  }

  // ------------------------------------------------------------- geri bildirim
  Widget _feedbackSheet(Pal pal) {
    final ok = _outcome == CardOutcome.correct;
    final almost = _answer?.verdict == AnswerVerdict.almost;
    final bg = ok ? pal.okBg : pal.badBg;
    final ink = ok ? pal.okInk : pal.badInk;
    final accent = ok ? AppColors.emerald : AppColors.rose;
    final title = switch (_outcome!) {
      CardOutcome.correct => almost ? 'Neredeyse doğru!' : 'Harika, doğru!',
      CardOutcome.wrong => 'Doğrusu şu',
      CardOutcome.dontKnow => 'Birlikte öğrenelim',
    };
    final meaning = _reverse ? _w.en : _w.mainTr;
    final others = _reverse ? _w.tr : _w.tr.skip(1).toList();

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: accent.withValues(alpha: 0.35), width: 3)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 23))),
            IconButton(
              tooltip: 'Dinle',
              icon: Icon(Icons.volume_up_rounded, color: ink),
              onPressed: () => _app.tts.speak(_w.en),
            ),
          ]),
          if (_outcome == CardOutcome.wrong && _given.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Senin cevabın: $_given',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w700, decoration: TextDecoration.lineThrough)),
            ),
          if (almost)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Doğru yazımı: ${_answer!.matched}', style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
            ),
          const SizedBox(height: 10),
          Text(meaning, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: pal.ink)),
          Text(_reverse ? _w.mainTr : _w.en, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: pal.muted)),
          if (others.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Diğer anlamları: ${others.join(', ')}',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 14.5)),
            ),
          if (_w.exampleEn.isNotEmpty) ...[
            const SizedBox(height: 12),
            Material(
              color: pal.card,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _app.tts.speak(_w.exampleEn),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_w.exampleEn, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: pal.ink, height: 1.3)),
                        if (_w.exampleTr.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(_w.exampleTr, style: TextStyle(fontWeight: FontWeight.w700, color: pal.muted)),
                          ),
                      ]),
                    ),
                    Icon(Icons.volume_up_rounded, color: AppColors.teal.withValues(alpha: 0.9)),
                  ]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text('Bu kelimeyi ne kadar hatırlıyorsun?', style: TextStyle(fontWeight: FontWeight.w900, color: pal.ink)),
          const SizedBox(height: 8),
          Row(children: [
            for (final r in RecallRating.values) ...[
              Expanded(child: _RatingChip(rating: r, selected: _rating == r, accent: accent, onTap: () => setState(() => _rating = r))),
              if (r != RecallRating.values.last) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 14),
          ChunkyButton(
            label: _i + 1 >= _words.length ? 'Bitir' : 'Devam et',
            style: ok ? ChunkyStyle.success : ChunkyStyle.danger,
            onPressed: _next,
          ),
          if (AppConfig.supportEmail.isNotEmpty)
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: const Text('Bu kelimede hata mı var? Bildir'),
                onPressed: () => reportWord(context, _w),
              ),
            ),
        ]),
      ),
    );
  }
}

class _SpeakButton extends StatelessWidget {
  const _SpeakButton({required this.size, required this.onTap});
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Telaffuzu dinle',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(size / 3),
              boxShadow: const [BoxShadow(color: AppColors.tealDeep, offset: Offset(0, 5))],
            ),
            child: Icon(Icons.volume_up_rounded, color: Colors.white, size: size * 0.48),
          ),
        ),
      );
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, required this.selected, required this.accent, required this.onTap});
  final RecallRating rating;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.16) : pal.card,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: selected ? accent : pal.border, width: 3),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(rating.label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: pal.ink)),
            ),
          ),
        ),
      ),
    );
  }
}
