import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'proposal.dart';

const statuses = ['ongoing', 'completed', 'abandoned'];

/// Home: Ongoing / Completed / Abandoned, personalized from the survey.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<String, Future<List<Map<String, dynamic>>>> _lists = {};

  @override
  void initState() {
    super.initState();
    homeTab.addListener(_onTab);
  }

  @override
  void dispose() {
    homeTab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() => setState(() {
        _lists.clear(); // coming back home refreshes the lists
      });

  Future<List<Map<String, dynamic>>> _load(String status, {bool force = false}) {
    if (force || !_lists.containsKey(status)) {
      _lists[status] = context.read<AppState>().api.proposals(status);
    }
    return _lists[status]!;
  }

  Future<void> _refresh(String status) async {
    setState(() {
      _load(status, force: true);
    });
    await _lists[status];
    if (mounted) await context.read<AppState>().refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;
    final tab = homeTab.value;
    final status = statuses[tab];
    return AppShell(
      title: '${tr(lang, 'hello')} ${state.username}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillTabs(
            labels: [tr(lang, 'ongoing'), tr(lang, 'completed'), tr(lang, 'abandoned')],
            selected: tab,
            onChanged: (i) => setState(() => homeTab.value = i),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Panel(
              tone: tab,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _load(status),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) return const LoadingView();
                  if (snap.hasError) {
                    final e = snap.error;
                    if (e is ApiException && e.unauthorized) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().signOut());
                    }
                    return ErrorView(message: e.toString(), onRetry: () => _refresh(status));
                  }
                  final items = snap.data!;
                  return RefreshIndicator(
                    color: C.navy,
                    onRefresh: () => _refresh(status),
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: _children(items, status, lang),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _children(List<Map<String, dynamic>> items, String status, String lang) {
    if (items.isEmpty) return [EmptyNote(status == 'ongoing' ? 'Nothing ongoing right now.' : 'Nothing here yet.')];
    if (status == 'ongoing') return [for (final p in items) ProposalCard(p, onChanged: () => _refresh(status))];
    final mine = items.where((p) => p['following'] == true).toList();
    final rest = items.where((p) => p['following'] != true).toList();
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Muted(status == 'completed'
            ? 'Decisions that were made, with updates on the ones you follow.'
            : 'Proposals that were withdrawn, deferred or fell through, and why.'),
      ),
      if (mine.isNotEmpty) ...[
        const _Sub('Updates on proposals you follow'),
        for (final p in mine) ProposalCard(p, onChanged: () => _refresh(status)),
        if (rest.isNotEmpty) _Sub('Other ${tr(lang, status).toLowerCase()} proposals'),
      ],
      for (final p in rest) ProposalCard(p, onChanged: () => _refresh(status)),
    ];
  }
}

class _Sub extends StatelessWidget {
  const _Sub(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(2, 4, 2, 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)));
}

/// A brief proposal card used on Home.
class ProposalCard extends StatelessWidget {
  const ProposalCard(this.p, {super.key, this.onChanged});
  final Map<String, dynamic> p;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    final latest = p['latest_update'] as Map<String, dynamic>?;
    final cats = List<String>.from(p['categories'] as List? ?? const []);
    return WhiteCard(
      onTap: () async {
        await push(context, ProposalScreen(id: p['id'] as int));
        onChanged?.call();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            Tag.status(p['status'] as String, p['stage_label'] as String? ?? ''),
            if (p['is_illustrative'] == true) Tag(tr(lang, 'illustrative'), bg: Colors.white, border: const Color(0xFF9AA8B6)),
            if (p['near'] == true)
              Tag(tr(lang, 'nearYou'), bg: C.forYou, fg: const Color(0xFF6B4E00))
            else if (p['matches'] == true)
              Tag(tr(lang, 'matches'), bg: C.forYou, fg: const Color(0xFF6B4E00)),
            if (p['can_say'] == true) Tag(tr(lang, 'canSay'), bg: C.navy, fg: Colors.white),
          ]),
          const SizedBox(height: 8),
          Text(p['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Muted(p['summary'] as String? ?? '', size: 13.5),
          if (latest != null && p['status'] != 'ongoing')
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(left: 10),
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: C.blue, width: 3))),
              child: Text('${latest['title']} · ${latest['date']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 6),
          Muted('${p['neighbourhood']} · ${cats.join(', ')}', size: 12),
        ],
      ),
    );
  }
}
