import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../i18n.dart';
import '../state.dart';
import '../survey_data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'account.dart';

/// The 5-question onboarding survey. Also used from Settings to change answers.
class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key, this.editing = false});
  final bool editing;
  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  static const stepNames = ['Interests', 'Have a say', 'Your time', 'Local issues', 'Alerts'];
  int step = 0;
  String? error;
  bool saving = false;
  late Map<String, dynamic> draft;
  late Future<Map<String, dynamic>> metaFuture;
  final otherCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final postalCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    metaFuture = state.loadMeta();
    final p = widget.editing ? state.profile : null;
    final a = Map<String, dynamic>.from(p?['answers'] as Map? ?? {});
    draft = {
      'answers': {
        'q1': List<String>.from(a['q1'] as List? ?? []),
        'q2': List<String>.from(a['q2'] as List? ?? []),
        'q3': List<String>.from(a['q3'] as List? ?? []),
        'q4': List<String>.from(a['q4'] as List? ?? []),
        'q4other': (a['q4other'] as String?) ?? '',
      },
      'notify_trigger': p?['notify_trigger'] ?? '',
      'notify_channels': List<String>.from(p?['notify_channels'] as List? ?? ['app']),
      'area_type': p?['area_type'] ?? '',
      'neighbourhood_id': (p?['neighbourhood'] as Map?)?['id'],
    };
    otherCtrl.text = draft['answers']['q4other'] as String;
    emailCtrl.text = (p?['email'] as String?) ?? '';
    phoneCtrl.text = (p?['phone'] as String?) ?? '';
    postalCtrl.text = (p?['postal_fsa'] as String?) ?? '';
  }

  @override
  void dispose() {
    for (final c in [otherCtrl, emailCtrl, phoneCtrl, postalCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get answers => draft['answers'] as Map<String, dynamic>;
  List<String> list(String key) => answers[key] as List<String>;
  List<String> get channels => draft['notify_channels'] as List<String>;

  void toggle(SurveyQuestion q, String key) {
    final sel = list(q.key);
    setState(() {
      if (sel.contains(key)) {
        sel.remove(key);
      } else if (q.exclusive == key) {
        sel
          ..clear()
          ..add(key);
      } else {
        sel.remove(q.exclusive);
        final countable = sel.where((k) => k != q.exclusive).length;
        if (q.max != null && countable >= q.max!) return;
        sel.add(key);
      }
    });
  }

  String? validateAlerts() {
    final lang = context.read<AppState>().language;
    if ((draft['notify_trigger'] as String).isEmpty) return 'Choose when you would like to be notified.';
    if (channels.contains('email') && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(emailCtrl.text.trim())) {
      return 'Enter a valid email address.';
    }
    if (channels.contains('sms') && phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length < 10) return 'Enter a 10-digit mobile number.';
    if ((draft['area_type'] as String).isEmpty) return 'Choose your whole city or your neighbourhood.';
    if (draft['area_type'] == 'neighbourhood' && draft['neighbourhood_id'] == null) return tr(lang, 'chooseNeighbourhood');
    final fsa = postalCtrl.text.trim().toUpperCase();
    if (fsa.isNotEmpty && !RegExp(r'^[A-Z]\d[A-Z]$').hasMatch(fsa)) return 'Postal code start should look like A1A.';
    return null;
  }

  Map<String, dynamic> payload() {
    answers['q4other'] = otherCtrl.text.trim();
    return {
      'answers': answers,
      'notify_trigger': draft['notify_trigger'],
      'notify_channels': channels,
      'email': emailCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'area_type': draft['area_type'],
      'neighbourhood_id': draft['neighbourhood_id'],
      'postal_fsa': postalCtrl.text.trim().toUpperCase(),
    };
  }

  Future<void> next() async {
    if (step < 4) {
      setState(() {
        step++;
        error = null;
      });
      return;
    }
    final problem = validateAlerts();
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    if (!widget.editing) {
      push(context, AccountScreen(draft: payload()));
      return;
    }
    setState(() => saving = true);
    try {
      await context.read<AppState>().updateProfile(payload());
      if (!mounted) return;
      toast(context, 'Your answers were saved.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    return AppShell(
      title: widget.editing ? 'Edit your answers' : tr(lang, 'yourView'),
      icons: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(child: _StepBar(names: stepNames, current: step)),
          const SizedBox(height: 10),
          Expanded(
            child: Panel(
              tone: [0, 1, 2, 0, 1][step],
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Text('${tr(lang, 'question')} ${step + 1} ${tr(lang, 'of')} 5'.toUpperCase(), style: sans(size: 11, color: C.muted)),
                  const SizedBox(height: 6),
                  if (step < 4) ..._question(surveyQuestions[step]) else ..._alerts(lang),
                  if (error != null)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Color(0xFFB3261E)))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            OutlinedButton(
              onPressed: () => step == 0 ? Navigator.of(context).maybePop() : setState(() => step--),
              child: Text(step == 0 && widget.editing ? tr(lang, 'cancel') : tr(lang, 'back')),
            ),
            const Spacer(),
            Muted('${step + 1} / 5'),
            const Spacer(),
            FilledButton(
              onPressed: saving ? null : next,
              child: Text(step < 4 ? tr(lang, 'next') : (widget.editing ? tr(lang, 'saveChanges') : tr(lang, 'continue'))),
            ),
          ]),
        ],
      ),
    );
  }

  List<Widget> _question(SurveyQuestion q) {
    final sel = list(q.key);
    final exclOn = q.exclusive != null && sel.contains(q.exclusive);
    final atMax = q.max != null && sel.where((k) => k != q.exclusive).length >= q.max!;
    return [
      Text(q.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Muted(q.hint),
      const SizedBox(height: 10),
      for (final o in q.options)
        _OptionTile(
          title: o.title,
          subtitle: o.description,
          selected: sel.contains(o.key),
          disabled: !sel.contains(o.key) && o.key != q.exclusive && (exclOn || atMax),
          onTap: () => toggle(q, o.key),
        ),
      if (q.other && sel.contains('other'))
        TextField(controller: otherCtrl, maxLength: 300, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe the street, park or issue')),
    ];
  }

  List<Widget> _alerts(String lang) {
    Widget sub(String text) => Padding(padding: const EdgeInsets.fromLTRB(0, 14, 0, 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)));
    Widget inline(String label, TextEditingController c, {TextInputType? type, int? max, String? hint}) => Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 0, 10),
          child: TextField(
            controller: c,
            keyboardType: type,
            maxLength: max,
            textCapitalization: max == 3 ? TextCapitalization.characters : TextCapitalization.none,
            decoration: InputDecoration(labelText: label, hintText: hint, counterText: ''),
          ),
        );
    return [
      const Text('How and when should we notify you?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      sub(tr(lang, 'when')),
      _OptionTile(title: tr(lang, 'openOnly'), radio: true, selected: draft['notify_trigger'] == 'open', onTap: () => setState(() => draft['notify_trigger'] = 'open')),
      _OptionTile(title: tr(lang, 'every'), radio: true, selected: draft['notify_trigger'] == 'every', onTap: () => setState(() => draft['notify_trigger'] = 'every')),
      sub(tr(lang, 'how')),
      for (final (key, label) in [('app', tr(lang, 'appNotifs')), ('email', tr(lang, 'emailDigest')), ('sms', tr(lang, 'sms'))]) ...[
        _OptionTile(
          title: label,
          selected: channels.contains(key),
          onTap: () => setState(() {
            if (channels.contains(key)) {
              channels.remove(key);
            } else {
              channels.add(key);
            }
          }),
        ),
        if (key == 'email' && channels.contains('email')) inline('Email', emailCtrl, type: TextInputType.emailAddress, hint: 'you@example.com'),
        if (key == 'sms' && channels.contains('sms')) inline('Mobile', phoneCtrl, type: TextInputType.phone, hint: '555-555-0123'),
      ],
      sub(tr(lang, 'whichArea')),
      _OptionTile(
        title: tr(lang, 'wholeCity'),
        radio: true,
        selected: draft['area_type'] == 'city',
        onTap: () => setState(() {
          draft['area_type'] = 'city';
          draft['neighbourhood_id'] = null;
        }),
      ),
      _OptionTile(title: tr(lang, 'myNeighbourhood'), radio: true, selected: draft['area_type'] == 'neighbourhood', onTap: () => setState(() => draft['area_type'] = 'neighbourhood')),
      if (draft['area_type'] == 'neighbourhood')
        FutureBuilder<Map<String, dynamic>>(
          future: metaFuture,
          builder: (context, snap) {
            if (snap.hasError) return Padding(padding: const EdgeInsets.only(left: 32), child: Text(snap.error.toString()));
            if (!snap.hasData) return const LoadingView();
            final hoods = List<Map<String, dynamic>>.from(snap.data!['neighbourhoods'] as List? ?? []);
            if (hoods.isEmpty) return const Padding(padding: EdgeInsets.only(left: 32, bottom: 10), child: Muted('No neighbourhoods are set up yet. Choose "My whole city" for now.'));
            return Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 0, 10),
              child: DropdownButtonFormField<int>(
                value: draft['neighbourhood_id'] as int?,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr(lang, 'chooseNeighbourhood')),
                items: [for (final n in hoods) DropdownMenuItem(value: n['id'] as int, child: Text(n['name'] as String))],
                onChanged: (v) => setState(() => draft['neighbourhood_id'] = v),
              ),
            );
          },
        ),
      if (draft['area_type'] == 'neighbourhood') inline(tr(lang, 'postal'), postalCtrl, max: 3, hint: 'A1A'),
      NoteBox(tr(lang, 'postalOnly')),
    ];
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.names, required this.current});
  final List<String> names;
  final int current;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Row(children: [
          for (var i = 0; i < names.length; i++)
            Expanded(
              child: Container(
                color: [C.blue, C.green, C.orange][i % 3].withOpacity(i == current ? 1 : (i < current ? 0.8 : 0.45)),
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                child: Text(names[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: i == current ? FontWeight.w700 : FontWeight.w400)),
              ),
            ),
        ]),
      );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.title, required this.selected, required this.onTap, this.subtitle = '', this.disabled = false, this.radio = false});
  final String title;
  final String subtitle;
  final bool selected;
  final bool disabled;
  final bool radio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: radio,
        enabled: !disabled,
        button: true,
        child: Opacity(
          opacity: disabled ? 0.45 : 1,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: selected ? C.focus : C.line, width: selected ? 2 : 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: disabled ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(
                    radio
                        ? (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked)
                        : (selected ? Icons.check_box : Icons.check_box_outline_blank),
                    color: selected ? C.focus : const Color(0xFF9FB0BC),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: TextStyle(fontWeight: subtitle.isEmpty ? FontWeight.w400 : FontWeight.w700)),
                      if (subtitle.isNotEmpty) Muted(subtitle),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
