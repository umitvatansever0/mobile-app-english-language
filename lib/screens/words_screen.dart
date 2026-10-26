import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/session_builder.dart';
import '../models/word.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'paywall_screen.dart';

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key});
  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

enum _Status { all, learning, mastered }

class _WordsScreenState extends State<WordsScreen> {
  int _tab = 0;
  String _query = '';
  _Status _status = _Status.all;
  String? _level;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelimeler'), actions: const [StreakChip(), SizedBox(width: 16)]),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Kelime ekle'),
              onPressed: () => app.isPremium
                  ? showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const _AddWordSheet())
                  : PaywallScreen.open(context, reason: PaywallReason.feature),
            )
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Çalıştıklarım')),
              ButtonSegment(value: 1, label: Text('Kendi kelimelerim')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        Expanded(child: _tab == 0 ? _studied(app, cs) : _custom(app, cs)),
      ]),
    );
  }

  Widget _studied(AppState app, ColorScheme cs) {
    final started = app.allWords.where((w) => app.progressOf(w.id)?.isStarted ?? false).toList();
    final learning = started.where((w) => !app.progressOf(w.id)!.isMastered).length;
    final mastered = started.length - learning;
    final q = _query.toLowerCase();
    final list = started.where((w) {
      final p = app.progressOf(w.id)!;
      if (_status == _Status.learning && p.isMastered) return false;
      if (_status == _Status.mastered && !p.isMastered) return false;
      if (_level != null && w.level != _level) return false;
      if (q.isNotEmpty && !w.en.toLowerCase().contains(q) && !w.tr.any((t) => t.toLowerCase().contains(q))) return false;
      return true;
    }).toList()
      ..sort((a, b) => (app.progressOf(b.id)!.lastReviewed ?? DateTime(0)).compareTo(app.progressOf(a.id)!.lastReviewed ?? DateTime(0)));

    int lvlCount(String l) => started.where((w) => w.level == l).length;

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text('${started.length} kelime çalıştın · $mastered ustalaştın (${app.totalWordCount} kelimeden)',
            style: const TextStyle(fontSize: 16)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          decoration: const InputDecoration(hintText: 'İngilizce veya Türkçe ara', prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      _chips('Durum', [
        ('Hepsi ${started.length}', _status == _Status.all, () => setState(() => _status = _Status.all)),
        ('Öğreniyor $learning', _status == _Status.learning, () => setState(() => _status = _Status.learning)),
        ('Ustalaştı $mastered', _status == _Status.mastered, () => setState(() => _status = _Status.mastered)),
      ]),
      _chips('Seviye', [
        ('Hepsi ${started.length}', _level == null, () => setState(() => _level = null)),
        for (final l in levelOrder) ('$l ${lvlCount(l)}', _level == l, () => setState(() => _level = l)),
      ]),
      const Divider(height: 24),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(started.isEmpty ? 'Henüz kelime çalışmadın. "Çalış" sekmesinden başla!' : 'Sonuç bulunamadı.',
              textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      for (final w in list) _WordRow(word: w),
    ]);
  }

  Widget _chips(String label, List<(String, bool, VoidCallback)> items) => SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          Center(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(width: 10),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(i.$1), selected: i.$2, onSelected: (_) => i.$3()),
            ),
        ]),
      );

  Widget _custom(AppState app, ColorScheme cs) {
    final words = app.customWords;
    if (words.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit_note_rounded, size: 64, color: cs.primary),
            const SizedBox(height: 12),
            const Text('Kendi kelime listeni oluştur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Dizide, işte ya da okulda karşılaştığın kelimeleri ekle; uygulama onları da tekrar ettirsin.',
                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          ]),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.only(top: 12, bottom: 96), children: [
      for (final w in words)
        Dismissible(
          key: ValueKey(w.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: AppColors.danger,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          onDismissed: (_) => app.deleteCustomWord(w.id),
          child: _WordRow(word: w),
        ),
    ]);
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.word});
  final Word word;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final p = app.progressOf(word.id);
    final cs = Theme.of(context).colorScheme;
    final mastered = p?.isMastered ?? false;
    return InkWell(
      onTap: () => showModalBottomSheet<void>(context: context, builder: (_) => _WordDetail(word: word)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)))),
        child: Row(children: [
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(word.en, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              Text(word.mainTr, style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
            child: Text(word.level, style: const TextStyle(fontSize: 13)),
          ),
          SizedBox(width: 36, child: Text('${p?.timesSeen ?? 0}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
          SizedBox(
            width: 32,
            child: Text('${p?.timesCorrect ?? 0}',
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
          ),
          if (p != null && p.isStarted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: mastered ? AppColors.success.withValues(alpha: 0.15) : cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(mastered ? 'Ustalaştı' : 'Öğreniyor',
                  style: TextStyle(color: mastered ? AppColors.success : cs.primary, fontSize: 13)),
            ),
        ]),
      ),
    );
  }
}

class _WordDetail extends StatelessWidget {
  const _WordDetail({required this.word});
  final Word word;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final p = app.progressOf(word.id);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(word.en, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800))),
            IconButton(iconSize: 32, color: cs.primary, icon: const Icon(Icons.volume_up_rounded), onPressed: () => app.tts.speak(word.en)),
          ]),
          Text('${word.pos.label} · ${word.level} · ${topicLabels[word.topic] ?? word.topic}', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          Text(word.tr.join(', '), style: TextStyle(fontSize: 20, color: cs.primary, fontWeight: FontWeight.w700)),
          if (word.exampleEn.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(word.exampleEn, style: const TextStyle(fontSize: 17, fontStyle: FontStyle.italic)),
            if (word.exampleTr.isNotEmpty) Text(word.exampleTr, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
          if (p != null && p.isStarted) ...[
            const SizedBox(height: 16),
            Text(
              '${p.timesSeen} kez görüldü · ${p.timesCorrect} doğru'
              '${p.dueDate != null ? ' · sonraki tekrar: ${_fmt(p.dueDate!)}' : ''}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ]),
      ),
    );
  }

  static String _fmt(DateTime d) {
    final days = DateTime(d.year, d.month, d.day).difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
    if (days <= 0) return 'bugün';
    if (days == 1) return 'yarın';
    return '$days gün sonra';
  }
}

class _AddWordSheet extends StatefulWidget {
  const _AddWordSheet();
  @override
  State<_AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends State<_AddWordSheet> {
  final _en = TextEditingController();
  final _tr = TextEditingController();
  final _ex = TextEditingController();
  PartOfSpeech _pos = PartOfSpeech.noun;

  @override
  void dispose() {
    _en.dispose();
    _tr.dispose();
    _ex.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tr = _tr.text.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (_en.text.trim().isEmpty || tr.isEmpty) return;
    await context.read<AppState>().addCustomWord(en: _en.text, tr: tr, pos: _pos, example: _ex.text);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Yeni kelime', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: _en, autofocus: true, decoration: const InputDecoration(labelText: 'İngilizce')),
          const SizedBox(height: 12),
          TextField(
            controller: _tr,
            decoration: const InputDecoration(labelText: 'Türkçe karşılık(lar)', helperText: 'Birden fazlaysa virgülle ayır'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PartOfSpeech>(
            initialValue: _pos,
            decoration: const InputDecoration(labelText: 'Tür'),
            items: [for (final p in PartOfSpeech.values) DropdownMenuItem(value: p, child: Text(p.label))],
            onChanged: (v) => setState(() => _pos = v ?? _pos),
          ),
          const SizedBox(height: 12),
          TextField(controller: _ex, decoration: const InputDecoration(labelText: 'Örnek cümle (isteğe bağlı)')),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Kaydet')),
        ]),
      );
}
