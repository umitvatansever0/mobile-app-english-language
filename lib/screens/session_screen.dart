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
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Bitir')),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 30),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: (_i + (_phase == _Phase.feedback ? 1 : 0)) / _words.length, minHeight: 8),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(child: Text('${_i + 1} / ${_words.length}', style: TextStyle(fontSize: 17, color: cs.onSurfaceVariant))),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _phase == _Phase.question ? _questionCard(cs) : _feedbackCard(cs),
            ),
            const SizedBox(height: 20),
            if (_phase == _Phase.question) ..._questionControls(cs) else ..._feedbackControls(cs),
          ]),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ soru
  Widget _questionCard(ColorScheme cs) {
    final showWord = widget.mode != StudyMode.listen;
    final prompt = widget.mode == StudyMode.typeEn ? _w.mainTr : _w.en;
    return Container(
      key: ValueKey('q$_i'),
      height: 300,
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(28)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_w.pos.label.toUpperCase(), style: TextStyle(letterSpacing: 1.5, color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        if (showWord)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(prompt, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800)),
            ),
          )
        else
          Text('Dinle ve yaz', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        if (widget.mode != StudyMode.typeEn)
          IconButton(
            iconSize: widget.mode == StudyMode.listen ? 64 : 40,
            color: cs.primary,
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: () => _app.tts.speak(_w.en),
          ),
      ]),
    );
  }

  List<Widget> _questionControls(ColorScheme cs) {
    if (widget.mode == StudyMode.choice) {
      return [
        for (final c in _choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(
              onPressed: () => _check(c),
              child: Text(c, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
            ),
          ),
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
        style: const TextStyle(fontSize: 22),
        decoration: InputDecoration(labelText: _reverse ? 'İngilizcesi' : 'Türkçe karşılığı'),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _dontKnow, child: const Text('Bilmiyorum'))),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(onPressed: _input.text.trim().isEmpty ? null : _check, child: const Text('Kontrol Et')),
        ),
      ]),
    ];
  }

  // ------------------------------------------------------------- geri bildirim
  Widget _feedbackCard(ColorScheme cs) {
    final ok = _outcome == CardOutcome.correct;
    final almost = _answer?.verdict == AnswerVerdict.almost;
    final color = ok ? AppColors.success : AppColors.danger;
    final title = switch (_outcome!) {
      CardOutcome.correct => almost ? 'Neredeyse doğru!' : 'Doğru bildin!',
      CardOutcome.wrong => 'Yanlış',
      CardOutcome.dontKnow => 'Öğrenelim',
    };
    final meaning = _reverse ? _w.en : _w.mainTr;
    final others = _reverse ? _w.tr : _w.tr.skip(1).toList();

    return Container(
      key: ValueKey('f$_i'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(28)),
      child: Column(children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color,
          child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
        if (_outcome == CardOutcome.wrong && _given.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Senin cevabın: $_given',
                style: TextStyle(color: cs.onSurfaceVariant, decoration: TextDecoration.lineThrough)),
          ),
        if (almost)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Doğru yazımı: ${_answer!.matched}', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        const SizedBox(height: 12),
        Text(_reverse ? 'İNGİLİZCESİ' : 'ANLAMI', style: TextStyle(color: color, letterSpacing: 1.2)),
        Text(meaning, textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: color)),
        if (!_reverse || widget.mode == StudyMode.listen)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_reverse ? _w.mainTr : _w.en, style: TextStyle(fontSize: 18, color: cs.onSurfaceVariant)),
          ),
        if (others.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Diğer anlamlar: ${others.join(', ')}',
                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        if (_w.exampleEn.isNotEmpty) ...[
          const Divider(height: 32),
          Text(_w.exampleEn,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontStyle: FontStyle.italic)),
          if (_w.exampleTr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_w.exampleTr, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          IconButton(
            color: cs.primary,
            iconSize: 36,
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: () => _app.tts.speak(_w.exampleEn),
          ),
        ],
      ]),
    );
  }

  List<Widget> _feedbackControls(ColorScheme cs) => [
        const Center(
          child: Text('Bu kelimeyi ne kadar hatırlıyorsun?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          for (final r in RecallRating.values) ...[
            Expanded(
              child: ChoiceChip(
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(vertical: 12),
                label: SizedBox(width: double.infinity, child: Text(r.label, textAlign: TextAlign.center)),
                selected: _rating == r,
                selectedColor: AppColors.lilac,
                labelStyle: TextStyle(
                  fontSize: 15,
                  color: _rating == r ? Colors.black87 : cs.onSurface,
                  fontWeight: _rating == r ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (_) => setState(() => _rating = r),
              ),
            ),
            if (r != RecallRating.values.last) const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _next,
          child: Text(_i + 1 >= _words.length ? 'Bitir' : 'Sıradaki kelime'),
        ),
        if (AppConfig.supportEmail.isNotEmpty)
          TextButton.icon(
            icon: const Icon(Icons.flag_rounded),
            label: const Text('Bu kelimeyle ilgili bir sorun mu var? Bildir'),
            onPressed: () => reportWord(context, _w),
          ),
      ];
}
