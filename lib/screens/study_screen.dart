import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../logic/session_builder.dart';
import '../models/word.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'paywall_screen.dart';
import 'session_screen.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});
  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _size = AppConfig.dailyFreeWords;
  final Set<StudyCategory> _cats = {};
  final Set<String> _topics = {};

  static const _categoryIcons = {
    StudyCategory.nouns: Icons.abc_rounded,
    StudyCategory.verbs: Icons.directions_run_rounded,
    StudyCategory.adjectives: Icons.palette_rounded,
    StudyCategory.adverbs: Icons.schedule_rounded,
    StudyCategory.other: Icons.more_horiz_rounded,
  };

  void _premiumOnly() => PaywallScreen.open(context, reason: PaywallReason.feature);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final premium = app.isPremium;

    return Scaffold(
      appBar: AppBar(title: const Text('Çalış'), actions: const [StreakChip(), SizedBox(width: 16)]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        if (app.mistakesCount > 0)
          SectionCard(
            onTap: () => startSession(context, const SessionRequest(size: 20, level: allLevels, kind: SessionKind.mistakes)),
            child: Row(children: [
              const Icon(Icons.replay_rounded, color: AppColors.warning, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Hataları Çalış', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  Text('${app.mistakesCount} hatalı kelime seni bekliyor', style: TextStyle(color: cs.onSurfaceVariant)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        const SizedBox(height: 20),
        Text('Bugün kaç kelime çalışmak istersin?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Row(children: [
          for (final s in AppState.sessionSizes) ...[
            Expanded(
              child: _SizeOption(
                value: s,
                caption: s == AppConfig.dailyFreeWords && !premium ? 'Ücretsiz' : 'Kelime',
                selected: _size == s,
                locked: !premium && s != AppConfig.dailyFreeWords,
                onTap: () => !premium && s != AppConfig.dailyFreeWords ? _premiumOnly() : setState(() => _size = s),
              ),
            ),
            if (s != AppState.sessionSizes.last) const SizedBox(width: 12),
          ],
        ]),
        if (!premium)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Bugünkü ücretsiz hakkın: ${app.remainingToday} / ${app.today.freeAllowance} kelime',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
          ),
        const SizedBox(height: 24),
        _Header('ÇALIŞMA MODU'),
        for (final m in StudyMode.values)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              app.studyMode == m ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: app.studyMode == m ? cs.primary : cs.onSurfaceVariant,
            ),
            onTap: () => m.isPremium && !premium ? _premiumOnly() : app.setStudyMode(m),
            title: Row(children: [
              Flexible(child: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (m.isPremium && !premium) ...[const SizedBox(width: 6), const Icon(Icons.lock_rounded, size: 16)],
            ]),
            subtitle: Text(m.description),
          ),
        const SizedBox(height: 16),
        _Header('SEVİYE'),
        Wrap(spacing: 8, children: [
          for (final l in levelOrder)
            ChoiceChip(label: Text(l), selected: app.targetLevel == l, onSelected: (_) => app.setTargetLevel(l)),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Yeni kelimeler seçtiğin seviyeden gelir. Tekrarlar tüm seviyelerden.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ),
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: _Header('KATEGORİLER')),
          TextButton(
            onPressed: premium ? () => setState(_cats.clear) : _premiumOnly,
            child: const Text('Hepsini Seç'),
          ),
        ]),
        for (final c in StudyCategory.values) ...[
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            onTap: premium ? () => setState(() => _cats.contains(c) ? _cats.remove(c) : _cats.add(c)) : _premiumOnly,
            child: Row(children: [
              CircleAvatar(
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(_categoryIcons[c], color: cs.primary),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(c.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
              if (!premium)
                const Icon(Icons.lock_rounded)
              else
                Icon(_cats.isEmpty || _cats.contains(c) ? Icons.check_circle_rounded : Icons.circle_outlined, color: cs.primary),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        _Header('KONU DESTELERİ'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in topicLabels.entries.where((e) => e.key != 'custom' && e.key != 'general'))
            FilterChip(
              label: Text(e.value),
              avatar: premium ? null : const Icon(Icons.lock_rounded, size: 16),
              selected: _topics.contains(e.key),
              onSelected: premium ? (v) => setState(() => v ? _topics.add(e.key) : _topics.remove(e.key)) : (_) => _premiumOnly(),
            ),
          if (app.customWords.isNotEmpty)
            FilterChip(
              label: const Text('Kendi kelimelerim'),
              selected: _topics.contains('custom'),
              onSelected: (v) => setState(() => v ? _topics.add('custom') : _topics.remove('custom')),
            ),
        ]),
        const SizedBox(height: 28),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Başla'),
          onPressed: () => startSession(
            context,
            SessionRequest(size: _size, level: app.targetLevel, categories: {..._cats}, topics: {..._topics}),
          ),
        ),
        const SizedBox(height: 16),
        const Center(child: BannerAdBox()),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
      );
}

class _SizeOption extends StatelessWidget {
  const _SizeOption({required this.value, required this.caption, required this.selected, required this.locked, required this.onTap});
  final int value;
  final String caption;
  final bool selected, locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$value',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: selected ? cs.primary : cs.onSurface)),
              if (locked) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.lock_rounded, size: 18)),
            ]),
            Text(caption, style: TextStyle(color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
