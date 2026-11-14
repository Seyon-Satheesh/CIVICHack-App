import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../i18n.dart';
import '../state.dart';
import '../survey_data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'survey.dart';

/// Settings: your answers, language, audio mode, text size, data sources and account.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;
    final p = state.profile ?? {};
    final answers = p['answers'] as Map<String, dynamic>? ?? {};
    String labels(String q) {
      final question = surveyQuestions.firstWhere((s) => s.key == q, orElse: () => surveyQuestions.first);
      final keys = List<String>.from(answers[q] as List? ?? const []);
      final names = [
        for (final k in keys) question.options.firstWhere((o) => o.key == k, orElse: () => SurveyOption(k, k)).title,
      ];
      return names.isEmpty ? '—' : names.join(', ');
    }

    final hood = p['neighbourhood'] as Map<String, dynamic>?;
    final area = p['area_type'] == 'neighbourhood' && hood != null ? hood['name'] : tr(lang, 'wholeCity');
    final muni = p['municipality'] as Map<String, dynamic>?;

    return AppShell(
      title: tr(lang, 'settings'),
      child: Panel(
        tone: 3,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            WhiteCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHeading(tr(lang, 'yourAnswers')),
                _row(tr(lang, 'whichArea'), '$area${muni != null ? ' · ${muni['name']}' : ''}'),
                _row('Topics', labels('q1')),
                _row('Have a say in', labels('q2')),
                _row(tr(lang, 'when'), p['notify_trigger'] == 'every' ? tr(lang, 'every') : tr(lang, 'openOnly')),
                _row(tr(lang, 'how'), List<String>.from(p['notify_channels'] as List? ?? const []).join(', ')),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () => push(context, const SurveyScreen(editing: true)),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(tr(lang, 'changeAnswers')),
                ),
              ]),
            ),
            WhiteCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHeading(tr(lang, 'language')),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in languageNames.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: lang == e.key,
                      selectedColor: C.blue,
                      onSelected: (_) => _guard(context, () => state.setLanguage(e.key)),
                    ),
                ]),
                if (lang != 'en') Padding(padding: const EdgeInsets.only(top: 8), child: Muted(tr(lang, 'contentLang'), size: 12.5)),
              ]),
            ),
            WhiteCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHeading(tr(lang, 'accessibility')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(lang, 'audioMode')),
                  subtitle: Muted(tr(lang, 'audioDesc'), size: 12.5),
                  value: state.audioMode,
                  activeColor: C.navy,
                  onChanged: (v) => _guard(context, () => state.setAudioMode(v)),
                ),
                const SizedBox(height: 4),
                Text(tr(lang, 'textSize'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(tr(lang, 'normal'))),
                    ButtonSegment(value: true, label: Text(tr(lang, 'large'))),
                  ],
                  selected: {state.largeText},
                  onSelectionChanged: (s) => _guard(context, () => state.setLargeText(s.first)),
                ),
              ]),
            ),
            WhiteCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHeading(tr(lang, 'aboutData')),
                const Muted('Proposals, steps and sources are entered by city staff from public records. Each proposal lists its sources.', size: 12.5),
                _link(context, 'Toronto Open Data: Council Voting Record', 'https://open.toronto.ca/dataset/members-of-toronto-city-council-voting-record/'),
                _link(context, 'Toronto Open Data: Reserve fund statements', 'https://open.toronto.ca/'),
                _link(context, 'OpenStreetMap (map tiles)', 'https://www.openstreetmap.org/copyright'),
                Muted('Server: $apiBaseUrl', size: 11),
              ]),
            ),
            WhiteCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHeading(tr(lang, 'account')),
                Text('${tr(lang, 'username')}: ${state.username}'),
                if ((p['email'] as String? ?? '').isNotEmpty) Muted('${p['email']}'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    await state.signOut();
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(tr(lang, 'signOut')),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: sans(size: 12.5, color: C.muted))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 14))),
        ]),
      );

  static Widget _link(BuildContext context, String label, String url) => InkWell(
        onTap: () => openLink(context, url),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(label, style: const TextStyle(color: C.focus, decoration: TextDecoration.underline, fontSize: 14)),
        ),
      );

  static Future<void> _guard(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) toast(context, 'Saved on this device. Could not reach the server: $e');
    }
  }
}
