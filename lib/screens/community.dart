import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'proposal.dart';

/// Community: one staff-written story per completed proposal. No points, no rewards.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late Future<Map<String, dynamic>> _future = context.read<AppState>().api.community();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    return AppShell(
      title: tr(lang, 'community'),
      child: Panel(
        tone: 1,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingView();
            if (snap.hasError) {
              return ErrorView(message: snap.error.toString(), onRetry: () => setState(() => _future = context.read<AppState>().api.community()));
            }
            final summary = snap.data!['summary'] as Map<String, dynamic>? ?? {};
            final posts = List<Map<String, dynamic>>.from(snap.data!['posts'] as List? ?? const []);
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(tr(lang, 'togetherTag').toUpperCase(), style: sans(size: 11, color: C.muted)),
                const SizedBox(height: 4),
                Text(tr(lang, 'togetherTitle'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(children: [
                  _Stat(value: summary['voices_shared'], label: tr(lang, 'voicesShared')),
                  const SizedBox(width: 8),
                  _Stat(value: summary['projects_completed'], label: tr(lang, 'projectsCompleted')),
                  const SizedBox(width: 8),
                  _Stat(value: summary['ideas_used'], label: tr(lang, 'changesFromInput')),
                ]),
                const SizedBox(height: 6),
                Muted(tr(lang, 'postsNote'), size: 12.5),
                const SizedBox(height: 10),
                if (posts.isEmpty) EmptyNote(tr(lang, 'noPosts')),
                for (final p in posts) _Post(p: p, lang: lang),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final Object? value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.greenLine)),
          child: Column(children: [
            Text('${value ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.navy)),
            Text(label, textAlign: TextAlign.center, style: sans(size: 11, color: C.muted, weight: FontWeight.w500)),
          ]),
        ),
      );
}

class _Post extends StatelessWidget {
  const _Post({required this.p, required this.lang});
  final Map<String, dynamic> p;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final prop = p['proposal'] as Map<String, dynamic>?;
    final did = List<String>.from(p['did'] as List? ?? const []);
    final changed = List<String>.from(p['changed'] as List? ?? const []);
    return WhiteCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Muted('${p['date']}${prop != null ? ' · ${prop['neighbourhood']}' : ''}', size: 12),
        const SizedBox(height: 2),
        Text(p['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [
          Tag('${p['voices'] ?? 0} ${tr(lang, 'neighboursSpoke')}', bg: C.greenSoft, fg: const Color(0xFF16402A)),
          Tag('${p['ideas'] ?? 0} ${tr(lang, 'ideasShared')}', bg: C.blueSoft, fg: const Color(0xFF163044)),
        ]),
        ReadAloudButton('${p['title']}. ${did.join('. ')}. ${changed.join('. ')}. ${p['thanks'] ?? ''}'),
        if (did.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(tr(lang, 'whatCommunityDid'), style: const TextStyle(fontWeight: FontWeight.w700)),
          Bullets(did),
        ],
        if (changed.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(tr(lang, 'whatChanged'), style: const TextStyle(fontWeight: FontWeight.w700)),
          Bullets(changed),
        ],
        if ((p['thanks'] as String? ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Muted(p['thanks'] as String, italic: true)),
        if (prop != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => push(context, ProposalScreen(id: prop['id'] as int)), child: Text('${tr(lang, 'seeProposal')} →')),
          ),
      ]),
    );
  }
}
