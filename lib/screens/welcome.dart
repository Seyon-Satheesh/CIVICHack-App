import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'survey.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _signIn = false;
  bool _busy = false;
  String? _error;
  final _user = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _doSignIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().login(_user.text.trim(), _pass.text);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'CivicSpeak',
      icons: false,
      child: Panel(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 34, 22, 22),
          child: Column(
            children: [
              const Icon(Icons.location_on, color: C.pin, size: 56),
              const SizedBox(height: 8),
              Text('YOUR CITY. YOUR VOICE. YOUR FUTURE.', style: sans(size: 11, color: C.muted, weight: FontWeight.w600), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(t(context, 'welcomeTitle'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Muted(t(context, 'welcomeBody'), size: 15),
              const SizedBox(height: 22),
              if (!_signIn) ...[
                FilledButton(
                  onPressed: () => push(context, const SurveyScreen()),
                  child: Text(t(context, 'getStarted')),
                ),
                TextButton(onPressed: () => setState(() => _signIn = true), child: Text(t(context, 'haveAccount'))),
              ] else ...[
                TextField(
                  controller: _user,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: t(context, 'username')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  onSubmitted: (_) => _doSignIn(),
                  decoration: InputDecoration(labelText: t(context, 'password')),
                ),
                if (_error != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E)))),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  OutlinedButton(onPressed: _busy ? null : () => setState(() => _signIn = false), child: Text(t(context, 'back'))),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: _busy ? null : _doSignIn, child: Text(_busy ? t(context, 'loading') : t(context, 'signIn'))),
                ]),
              ],
              const SizedBox(height: 18),
              Muted(t(context, 'twoMinutes'), size: 13),
            ],
          ),
        ),
      ),
    );
  }
}
