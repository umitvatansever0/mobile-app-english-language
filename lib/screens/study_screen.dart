import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../logic/session_builder.dart';
import '../models/word.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky.dart';
import '../widgets/common.dart';
import '../widgets/level_path.dart';
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

  static const _modeIcons = {
    StudyMode.typeTr: Icons.keyboard_rounded,
    StudyMode.typeEn: Icons.swap_horiz_rounded,
    StudyMode.choice: Icons.checklist_rounded,
    StudyMode.listen: Icons.headphones_rounded,
  };

  void _premiumOnly() => PaywallScreen.open(context, reason: PaywallReason.feature);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pal = Pal.of(context);
    final premium = app.isPremium;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
          Row(children: [
            Expanded(
              child: Text('Çalış',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: pal.dark ? AppColors.sun : AppColors.tealDeep)),
            ),
            const StreakChip(),
          ]),
          if (app.mistakesCount > 0) ...[
            const SizedBox(height: 14),
            ChunkyCard(
              onTap: () => startSession(context, const SessionRequest(size: 20, level: allLevels, kind: SessionKind.mistakes)),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: AppColors.rose.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.replay_rounded, color: AppColors.rose),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Hataları çalış', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: pal.ink)),
                    Text('${app.mistakesCount} kelime seni bekliyor', style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: pal.muted),
              ]),
            ),
          ],
          const SectionTitle('Kaç kelime?'),
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
              if (s != AppState.sessionSizes.last) const SizedBox(width: 10),
            ],
          ]),
          if (!premium)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text('Bugünkü ücretsiz hakkın: ${app.remainingToday} / ${app.today.freeAllowance} kelime',
                  style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700)),
            ),
          const SectionTitle('Çalışma modu'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              for (final m in StudyMode.values)
                _ModeTile(
                  icon: _modeIcons[m]!,
                  title: m.label,
                  subtitle: m.description,
                  selected: app.studyMode == m,
                  locked: m.isPremium && !premium,
                  onTap: () => m.isPremium && !premium ? _premiumOnly() : app.setStudyMode(m),
                ),
            ],
          ),
          const SectionTitle('Seviye'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final l in levelOrder)
              ChoiceChip(
                showCheckmark: false,
                label: Text('$l · ${levelNames[l]}'),
                selected: app.targetLevel == l,
                onSelected: (_) => app.setTargetLevel(l),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text('Yeni kelimeler seçtiğin seviyeden gelir. Tekrarlar tüm seviyelerden.',
                style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          SectionTitle('Kelime türü',
              trailing: TextButton(onPressed: premium ? () => setState(_cats.clear) : _premiumOnly, child: const Text('Hepsi'))),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in StudyCategory.values)
              FilterChip(
                showCheckmark: false,
                avatar: Icon(premium ? _categoryIcons[c] : Icons.lock_rounded, size: 18),
                label: Text(c.label),
                selected: premium && _cats.contains(c),
                onSelected: premium ? (v) => setState(() => v ? _cats.add(c) : _cats.remove(c)) : (_) => _premiumOnly(),
              ),
          ]),
          const SectionTitle('Konu desteleri'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in topicLabels.entries.where((e) => e.key != 'custom' && e.key != 'general'))
              FilterChip(
                showCheckmark: false,
                label: Text(e.value),
                avatar: premium ? null : const Icon(Icons.lock_rounded, size: 16),
                selected: _topics.contains(e.key),
                onSelected: premium ? (v) => setState(() => v ? _topics.add(e.key) : _topics.remove(e.key)) : (_) => _premiumOnly(),
              ),
            if (app.customWords.isNotEmpty)
              FilterChip(
                showCheckmark: false,
                label: const Text('Kendi kelimelerim'),
                selected: _topics.contains('custom'),
                onSelected: (v) => setState(() => v ? _topics.add('custom') : _topics.remove('custom')),
              ),
          ]),
          const SizedBox(height: 24),
          ChunkyButton(
            label: 'Başla',
            icon: Icons.play_arrow_rounded,
            onPressed: () => startSession(
              context,
              SessionRequest(size: _size, level: app.targetLevel, categories: {..._cats}, topics: {..._topics}),
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: BannerAdBox()),
        ]),
      ),
    );
  }
}

class _SizeOption extends StatelessWidget {
  const _SizeOption({required this.value, required this.caption, required this.selected, required this.locked, required this.onTap});
  final int value;
  final String caption;
  final bool selected, locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return ChunkyCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16),
      borderColor: selected ? AppColors.teal : null,
      color: selected ? (pal.dark ? const Color(0xFF123533) : AppColors.tealSoft) : null,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$value',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: selected ? AppColors.teal : pal.ink)),
          if (locked) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.lock_rounded, size: 18, color: pal.lockInk)),
        ]),
        Text(caption, style: TextStyle(color: pal.muted, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final bool selected, locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return ChunkyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      borderColor: selected ? AppColors.teal : null,
      color: selected ? (pal.dark ? const Color(0xFF123533) : AppColors.tealSoft) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: selected ? AppColors.teal : pal.muted),
          const Spacer(),
          if (locked) Icon(Icons.lock_rounded, size: 18, color: pal.lockInk),
          if (selected) const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.teal),
        ]),
        const Spacer(),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: pal.ink)),
        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: pal.muted, height: 1.2)),
      ]),
    );
  }
}
