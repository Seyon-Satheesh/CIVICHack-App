import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Where a proposal's money comes from: its cost, and the reserve fund statements behind it.
class FundingScreen extends StatefulWidget {
  const FundingScreen({super.key, required this.id, required this.title});
  final int id;
  final String title;
  @override
  State<FundingScreen> createState() => _FundingScreenState();
}

class _FundingScreenState extends State<FundingScreen> {
  late Future<Map<String, dynamic>> _future = context.read<AppState>().api.funding(widget.id);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    return AppShell(
      title: tr(lang, 'costWho'),
      child: Panel(
        tone: 1,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingView();
            if (snap.hasError) {
              return ErrorView(
                message: snap.error.toString(),
                onRetry: () => setState(() => _future = context.read<AppState>().api.funding(widget.id)),
              );
            }
            final d = snap.data!;
            final cost = d['cost'] as Map<String, dynamic>? ?? {};
            final allocations = List<Map<String, dynamic>>.from(d['allocations'] as List? ?? const []);
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(d['title'] as String? ?? widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 10),
                WhiteCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SectionHeading(tr(lang, 'costLabel')),
                    _kv(tr(lang, 'costLabel'), cost['estimate']),
                    _kv(tr(lang, 'whoPays'), List<String>.from(cost['payers'] as List? ?? const []).join(', ')),
                    _kv(tr(lang, 'when'), cost['when']),
                    _kv(tr(lang, 'budgetLine'), cost['budget_line']),
                    if ((cost['note'] as String? ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Muted(cost['note'] as String)),
                  ]),
                ),
                WhiteCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SectionHeading(tr(lang, 'moneyFlowing')),
                    if (allocations.isEmpty) Muted(tr(lang, 'notLinked')),
                    for (final a in allocations) _Allocation(a: a, lang: lang),
                  ]),
                ),
                const Muted('Figures come from the city\'s published reserve fund statements. Only funds linked to this proposal are shown.', size: 12.5),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kv(String k, Object? v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: sans(size: 12.5, color: C.muted))),
          Expanded(child: Text('${v ?? '—'}'.isEmpty ? '—' : '${v ?? '—'}')),
        ]),
      );
}

class _Allocation extends StatelessWidget {
  const _Allocation({required this.a, required this.lang});
  final Map<String, dynamic> a;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final pct = ((a['percent_spent'] as num?) ?? 0).toDouble().clamp(0, 100) / 100;
    final st = a['statement'] as Map<String, dynamic>?;
    final src = st?['source'] as Map<String, dynamic>?;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.greenLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${a['fund']} · ${a['year']}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Semantics(
          label: '${tr(lang, 'spent')} ${a['spent']} / ${tr(lang, 'allocated')} ${a['allocated']}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: pct, minHeight: 10, backgroundColor: Colors.white, color: C.statusCompleted),
          ),
        ),
        const SizedBox(height: 4),
        Text('${tr(lang, 'spent')}: ${a['spent']} · ${tr(lang, 'allocated')}: ${a['allocated']}', style: const TextStyle(fontSize: 13)),
        if (st != null) ...[
          const SizedBox(height: 6),
          Muted('Fund statement: collected ${st['collected']}, draws ${st['draws']}, closing balance ${st['closing_balance']}', size: 12.5),
          if (src != null && (src['url'] as String? ?? '').isNotEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => openLink(context, src['url'] as String),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(src['title'] as String? ?? tr(lang, 'official')),
            ),
        ],
      ]),
    );
  }
}
