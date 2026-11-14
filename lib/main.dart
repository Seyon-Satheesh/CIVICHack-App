import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'push.dart';
import 'screens/home.dart';
import 'screens/welcome.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  // Push notifications: a new one refreshes the bell count. Skipped if Firebase isn't set up.
  await PushService.instance.init(onReceived: state.refreshUnread);
  state.init();
  runApp(ChangeNotifierProvider.value(value: state, child: const CivicSpeakApp()));
}

class CivicSpeakApp extends StatelessWidget {
  const CivicSpeakApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'CivicSpeak',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: buildTheme(highContrast: state.audioMode),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scale = state.largeText || state.audioMode ? 1.2 : 1.0;
        return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(scale)), child: child!);
      },
      home: const _Root(),
    );
  }
}

/// Splash until the saved session is checked, then Home (signed in) or Welcome (survey first).
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.ready) {
      return const Scaffold(
        backgroundColor: C.page,
        body: Center(child: Icon(Icons.location_on, color: C.pin, size: 64, semanticLabel: 'CivicSpeak')),
      );
    }
    return state.signedIn ? const HomeScreen() : const WelcomeScreen();
  }
}
