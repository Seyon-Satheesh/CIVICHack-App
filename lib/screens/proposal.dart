import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'funding.dart';

const _prompts = {
  'support': ('What do you like most? What should the city make sure to keep?', 'e.g. The protected lanes would make my commute safer.'),
  'neutral': ('What would help you decide? Is anything unclear?', "e.g. I'd like to know how many parking spots are removed."),
  'oppose': ('What would make this better? Suggest a change the city could make.', 'e.g. Keep parking on one side and add a loading zone for shops.'),
};

/// One proposal: Breakdown, Pros & Cons (or Impacts once completed), Process and Sources tabs.
class ProposalScreen extends StatefulWidget {
  const ProposalScreen({super.key, required this.id});
  final int id;
  @override
  State<ProposalScreen> createState() => _ProposalScreenState();
}

class _ProposalScreenState extends State<ProposalScreen> {
  late Future<Map<String, dynamic>> _future;
  Map<String, dynamic>? p;
  int tab = 0;
  bool whatIs = false;
  String? choice;
  bool sending = false;
  final comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final data = await context.read<AppState>().api.proposal(widget.id);
    final mine = data['my_feedback'] as Map<String, dynamic>?;
    if (mine != null) {
      choice = mine['choice'] as String?;
      comment.text = (mine['comment'] as String?) ?? '';
    }
    p = data;
    return data;
  }

  Future<void> _toggleFollow() async {
    final state = context.read<AppState>();
    try {
      final on = await state.api.toggleFollow(widget.id);
      state.setFollowing(widget.id, on);
      setState(() => p = {...?p, 'following': on});
      if (mounted) toast(context, tr(state.language, on ? 'followMap' : 'unfollowMap'));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _send() async {
    final state = context.read<AppState>();
    if (choice == null) return;
    setState(() => sending = true);
    try {
      final res = await state.api.sendFeedback(widget.id, choice!, comment.text.trim());
      setState(() => p = {...?p, 'my_feedback': res['my_feedback']});
      if (mounted) toast(context, tr(state.language, res['updated'] == true ? 'fbUpdated' : 'fbThanks'));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return AppShell(title: t(context, 'loading'), child: const LoadingView());
        if (snap.hasError) {
          return AppShell(
            title: t(context, 'summary'),
            child: ErrorView(message: snap.error.toString(), onRetry: () => setState(() => _future = _load())),
          );
        }
        return _page(context, p ?? snap.data!);
      },
    );
  }

  Widget _page(BuildContext context, Map<String, dynamic> p) {
    final lang = context.watch<AppState>().language;
    final done = p['status'] != 'ongoing';
    final following = p['following'] == true;
    final tabs = [tr(lang, 'breakdown'), done ? tr(lang, 'impacts') : tr(lang, 'proscons'), tr(lang, 'process'), tr(lang, 'sources')];
    final illustrative = p['is_illustrative'] == true;
    final tone = {'ongoing': 0, 'completed': 1, 'abandoned': 2}[p['status']] ?? 0;
    return AppShell(
      title: p['title'] as String? ?? '',
      wrapTitle: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            TextButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back, size: 18), label: Text(tr(lang, 'back'))),
            const Spacer(),
            Semantics(
              button: true,
              toggled: following,
              label: following ? tr(lang, 'following') : tr(lang, 'followPin'),
              child: Tooltip(
                message: following ? tr(lang, 'following') : tr(lang, 'followPin'),
                child: Material(
                  shape: CircleBorder(side: BorderSide(color: following ? C.navy : const Color(0xFFCFD6DC))),
                  color: following ? C.navy : Colors.white,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggleFollow,
                    child: SizedBox(width: 46, height: 46, child: Icon(following ? Icons.check : Icons.add, color: following ? Colors.white : C.navy)),
                  ),
                ),
              ),
            ),
          ]),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Tag.status(p['status'] as String, '${tr(lang, p['status'] as String)} · ${p['stage_label']}'),
            InkWell(
              onTap: () => setState(() => whatIs = !whatIs),
              borderRadius: BorderRadius.circular(999),
              child: Tag('${illustrative ? tr(lang, 'illustrative') : tr(lang, 'real')} ⓘ',
                  bg: Colors.white, border: illustrative ? const Color(0xFF9AA8B6) : C.ok, fg: illustrative ? const Color(0xFF4A5868) : C.ok),
            ),
          ]),
          if (whatIs) NoteBox(illustrative ? tr(lang, 'illusWhat') : tr(lang, 'realWhat')),
          const SizedBox(height: 10),
          PillTabs(labels: tabs, selected: tab, onChanged: (i) => setState(() => tab = i)),
          const SizedBox(height: 10),
          Expanded(
            child: Panel(
              tone: tone,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: switch (tab) {
                  0 => _breakdown(p, lang),
                  1 => done ? _impacts(p, lang) : _prosCons(p, lang),
                  2 => _process(p, lang),
                  _ => _sources(p, lang),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _list(Map<String, dynamic> p, String key) => List<String>.from(p[key] as List? ?? const []);

  List<Widget> _breakdown(Map<String, dynamic> p, String lang) {
    final updates = List<Map<String, dynamic>>.from(p['updates'] as List? ?? const []);
    final cost = p['cost'] as Map<String, dynamic>? ?? {};
    final canSay = p['can_say'] == true;
    final actions = _list(p, 'actions');
    final part = p['participation'] as Map<String, dynamic>? ?? {};
    final mine = p['my_feedback'] as Map<String, dynamic>?;
    final readText = [
      p['title'],
      p['summary'],
      ...updates.map((u) => '${u['title']}. ${u['summary']}'),
      '${tr(lang, 'whatsChanging')}: ${_list(p, 'changes').join('. ')}',
    ].join('. ');
    return [
      if (lang != 'en') NoteBox(tr(lang, 'contentLang')),
      if (lang != 'en') const SizedBox(height: 10),
      ReadAloudButton(readText),
      WhiteCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeading(tr(lang, 'summary'), number: 1),
          Text(p['summary'] as String? ?? ''),
          for (final u in updates)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFF4F8FB),
                border: Border(left: BorderSide(color: C.navy, width: 3)),
              ),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${tr(lang, 'latest')} · ${u['date']}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: '${u['title']}. ${u['summary']}'),
              ]), style: const TextStyle(fontSize: 13.5)),
            ),
          if (p['near'] == true)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.forYou, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.location_on, color: C.pin, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('${tr(lang, 'nearYou')}. ${p['address'] ?? ''}${p['radius_km'] != null ? ' · ${p['radius_km']} km' : ''}')),
              ]),
            ),
          if ((p['affected'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Muted('${tr(lang, 'whoAffected')}: ${p['affected']}'),
          ],
        ]),
      ),
      WhiteCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeading(tr(lang, 'whatsChanging'), number: 2),
          Bullets(_list(p, 'changes')),
          const SizedBox(height: 8),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: C.line)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => push(context, FundingScreen(id: widget.id, title: p['title'] as String? ?? '')),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr(lang, 'costWho'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${cost['estimate']} · ${List<String>.from(cost['payers'] as List? ?? const []).join(', ')}', style: const TextStyle(fontSize: 13)),
                      Muted('${tr(lang, 'when')}: ${cost['when']}', size: 12.5),
                    ]),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ),
          ),
        ]),
      ),
      if (canSay)
        WhiteCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeading(tr(lang, 'yourView'), number: 3),
            Row(children: [
              for (final (key, icon) in [('support', Icons.thumb_up_outlined), ('neutral', Icons.remove), ('oppose', Icons.thumb_down_outlined)]) ...[
                Expanded(child: _VoteButton(label: tr(lang, key), icon: icon, selected: choice == key, onTap: () => setState(() => choice = key))),
                if (key != 'oppose') const SizedBox(width: 8),
              ],
            ]),
            if (choice != null) ...[
              const SizedBox(height: 10),
              Text('${_prompts[choice]!.$1} (${tr(lang, 'optional')})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 6),
              TextField(controller: comment, maxLines: 4, maxLength: 500, decoration: InputDecoration(hintText: _prompts[choice]!.$2)),
              Row(children: [
                if (mine != null) Text('✓ ${tr(lang, 'sent')}', style: const TextStyle(color: C.ok, fontWeight: FontWeight.w700)),
                const Spacer(),
                FilledButton(onPressed: sending ? null : _send, child: Text(mine != null ? tr(lang, 'update') : tr(lang, 'submit'))),
              ]),
            ],
            const SizedBox(height: 6),
            Muted(tr(lang, 'notVote'), size: 12.5),
          ]),
        ),
      WhiteCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeading(tr(lang, 'whatYouCanDo'), number: canSay ? 4 : 3),
          if (canSay && actions.isNotEmpty) ...[
            Bullets(actions),
            if ((part['deadline'] as String?) != null) Muted('Official deadline: ${(part['deadline'] as String).substring(0, 10)}'),
            if ((part['url'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => openLink(context, part['url'] as String),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(tr(lang, 'goThere')),
              ),
            ],
          ] else
            Text.rich(TextSpan(children: [
              TextSpan(text: '${tr(lang, 'na')} · ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: tr(lang, 'closedNote')),
            ])),
        ]),
      ),
    ];
  }

  List<Widget> _prosCons(Map<String, dynamic> p, String lang) {
    final pros = _list(p, 'pros'), cons = _list(p, 'cons');
    if (pros.isEmpty && cons.isEmpty) return [EmptyNote(tr(lang, 'na'))];
    Widget col(String title, List<String> items, Color bg, Color line, Color fg) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionHeading(title, color: line), DefaultTextStyle.merge(style: TextStyle(color: fg), child: Bullets(items))]),
        );
    return [
      ReadAloudButton('${tr(lang, 'pros')}: ${pros.join('. ')}. ${tr(lang, 'cons')}: ${cons.join('. ')}'),
      col(tr(lang, 'pros'), pros, const Color(0xFFE7F5EC), C.statusCompleted, const Color(0xFF16402A)),
      col(tr(lang, 'cons'), cons, const Color(0xFFFBEFE2), C.statusAbandoned, const Color(0xFF5A3A10)),
      const Muted('Pros and cons come from the staff report, the application and public comments, so you can weigh them yourself. Check them in the Sources tab.', size: 12.5),
    ];
  }

  List<Widget> _impacts(Map<String, dynamic> p, String lang) {
    final impacts = List<Map<String, dynamic>>.from(p['impacts'] as List? ?? const []);
    if (p['status'] == 'abandoned') {
      final updates = List<Map<String, dynamic>>.from(p['updates'] as List? ?? const []);
      return [
        WhiteCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeading(tr(lang, 'impacts')),
            Text(p['summary'] as String? ?? ''),
            for (final u in updates) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${u['date']}: ${u['title']}. ${u['summary']}')),
          ]),
        ),
      ];
    }
    const tagColors = {
      'positive': (Color(0xFFCDEBD8), Color(0xFF16402A)),
      'neutral': (Color(0xFFE3E7EA), Color(0xFF33404A)),
      'negative': (Color(0xFFF6D9B8), Color(0xFF5A3A10)),
    };
    return [
      ReadAloudButton(impacts.map((i) => '${tr(lang, i['kind'] as String)}: ${i['text']}').join('. ')),
      const Padding(padding: EdgeInsets.only(bottom: 10), child: Muted('What has happened since this was completed. City staff add new impacts as information comes in.')),
      if (impacts.isEmpty) EmptyNote(tr(lang, 'na')),
      for (final i in impacts)
        WhiteCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tag(tr(lang, i['kind'] as String), bg: tagColors[i['kind']]?.$1 ?? C.line, fg: tagColors[i['kind']]?.$2 ?? C.ink),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Muted('${i['date']}', size: 12), Text(i['text'] as String? ?? '')])),
          ]),
        ),
    ];
  }

  List<Widget> _process(Map<String, dynamic> p, String lang) {
    final steps = List<Map<String, dynamic>>.from(p['steps'] as List? ?? const []);
    return [
      WhiteCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeading(tr(lang, 'process')),
          if (steps.isEmpty) Muted(tr(lang, 'na')),
          for (var i = 0; i < steps.length; i++) _StepRow(step: steps[i], last: i == steps.length - 1, ongoing: p['status'] == 'ongoing', lang: lang),
          const SizedBox(height: 4),
          Muted('${tr(lang, 'stepsIntro')} A meeting date is not a comment deadline.', size: 12.5),
        ]),
      ),
    ];
  }

  List<Widget> _sources(Map<String, dynamic> p, String lang) {
    final sources = List<Map<String, dynamic>>.from(p['sources'] as List? ?? const []);
    final part = p['participation'] as Map<String, dynamic>? ?? {};
    return [
      WhiteCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeading(tr(lang, 'sources')),
          if (sources.isEmpty) Muted(tr(lang, 'na')),
          for (final s in sources)
            _LinkRow(label: '${s['kind']}: ${s['title']}${s['date'] != null ? ' (${s['date']})' : ''}', url: s['url'] as String),
          if ((part['url'] as String? ?? '').isNotEmpty) _LinkRow(label: '${tr(lang, 'official')}: ${tr(lang, 'whatYouCanDo')}', url: part['url'] as String),
          if (p['is_illustrative'] == true) Padding(padding: const EdgeInsets.only(top: 8), child: Muted(tr(lang, 'illusWhat'), size: 12.5)),
        ]),
      ),
    ];
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: selected ? C.navy : const Color(0xFFCFD6DC), width: selected ? 2 : 1)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(children: [
                Icon(icon, color: selected ? C.navy : C.ink),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        ),
      );
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.last, required this.ongoing, required this.lang});
  final Map<String, dynamic> step;
  final bool last;
  final bool ongoing;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final state = step['state'] as String? ?? 'unknown';
    final done = state == 'done', current = state == 'current';
    final canSay = step['can_participate'] == true && !done && ongoing;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 26,
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? C.ok : Colors.white,
                border: Border.all(color: done ? C.ok : (current ? C.navy : const Color(0xFF9FB0BC)), width: current ? 3 : 2),
              ),
            ),
            if (!last) Expanded(child: Container(width: 2, color: C.line)),
          ]),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, children: [
                Text(step['label'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (canSay) Text(tr(lang, 'canSay'), style: sans(size: 11, color: C.ok, weight: FontWeight.w700)),
              ]),
              Text(
                '${step['level_label']} · ${step['state_label']}${step['date'] != null ? ' · ${step['date']}' : ''}',
                style: sans(size: 11.5, color: C.muted, weight: FontWeight.w500),
              ),
              if ((step['note'] as String? ?? '').isNotEmpty) Text(step['note'] as String, style: const TextStyle(fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.url});
  final String label;
  final String url;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => openLink(context, url),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(color: C.focus, decoration: TextDecoration.underline))),
            const Icon(Icons.open_in_new, size: 16, color: C.focus),
          ]),
        ),
      );
}
