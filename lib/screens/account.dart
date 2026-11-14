import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Last onboarding step: choose a username and password. The survey answers come with it.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.draft});
  final Map<String, dynamic> draft;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _user.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_.-]{2,24}$').hasMatch(name)) {
      setState(() => _error = 'Use 2 to 24 letters, numbers, dots, dashes or underscores.');
      return;
    }
    if (_pass.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters for your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().register({...widget.draft, 'username': name, 'password': _pass.text});
      if (!mounted) return;
      homeTab.value = 0;
      toast(context, 'Welcome, $name! Your home is set up from your answers.');
      Navigator.of(context).popUntil((r) => r.isFirst); // the root now shows Home
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: t(context, 'createAccount'),
      icons: false,
      child: Panel(
        tone: 2,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t(context, 'lastStep').toUpperCase(), style: sans(size: 11, color: C.muted)),
            const SizedBox(height: 6),
            Text(t(context, 'chooseUsername'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Muted(t(context, 'answersSaved')),
            const SizedBox(height: 16),
            TextField(
              controller: _user,
              autocorrect: false,
              maxLength: 24,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: t(context, 'username'), hintText: 'e.g. mika_w', counterText: ''),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pass,
              obscureText: true,
              onSubmitted: (_) => _create(),
              decoration: InputDecoration(labelText: t(context, 'password'), helperText: 'At least 8 characters'),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E)))),
            const SizedBox(height: 18),
            Row(children: [
              OutlinedButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(t(context, 'back'))),
              const Spacer(),
              FilledButton(onPressed: _busy ? null : _create, child: Text(_busy ? t(context, 'loading') : t(context, 'createAccount'))),
            ]),
          ],
        ),
      ),
    );
  }
}
