import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/proposal.dart';
import 'theme.dart';

/// Lets push handling open screens and show messages from outside a widget.
final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Push notifications (Firebase Cloud Messaging).
///
/// The Django admin console sends them when a proposal that matches you is published, changes,
/// or gets an update. If Firebase isn't set up for this build, the app works normally without push.
class PushService {
  PushService._();
  static final instance = PushService._();

  bool available = false;
  String? _token;
  ApiClient? _api;
  VoidCallback? _onReceived;
  StreamSubscription<String>? _refreshSub;

  /// Call once at startup, before runApp.
  Future<void> init({VoidCallback? onReceived}) async {
    _onReceived = onReceived;
    if (kIsWeb) return; // web push needs extra setup; the bell still works
    try {
      await Firebase.initializeApp(); // reads google-services.json / GoogleService-Info.plist
      available = true;
    } catch (e) {
      debugPrint('Push notifications off (Firebase not configured): $e');
      return;
    }

    // Shown while the app is open: a snackbar with an Open button.
    FirebaseMessaging.onMessage.listen((m) {
      _onReceived?.call();
      final title = m.notification?.title ?? 'CivicSpeak';
      final id = int.tryParse(m.data['proposal_id']?.toString() ?? '');
      messengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(title),
        backgroundColor: C.navy,
        behavior: SnackBarBehavior.floating,
        action: id == null ? null : SnackBarAction(label: 'Open', textColor: Colors.white, onPressed: () => _open(id)),
      ));
    });

    // Tapped while the app was in the background, or launched the app.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // Wait for the first screen to be ready.
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTap(initial));
    }
  }

  void _handleTap(RemoteMessage m) {
    _onReceived?.call();
    final id = int.tryParse(m.data['proposal_id']?.toString() ?? '');
    if (id != null) _open(id);
  }

  void _open(int id) {
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ProposalScreen(id: id)));
  }

  String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// After sign-in: ask permission (Android 13+, iOS) and send this phone's token to the server.
  Future<void> register(ApiClient api) async {
    if (!available) return;
    _api = api;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) await api.registerDevice(_token!, _platform);
      _refreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        _token = t;
        if (_api?.token != null) {
          try {
            await _api!.registerDevice(t, _platform);
          } catch (_) {/* try again next launch */}
        }
      });
    } catch (e) {
      debugPrint('Could not register for push: $e');
    }
  }

  /// Before sign-out: stop this phone getting the account's notifications.
  Future<void> unregister(ApiClient api) async {
    if (!available || _token == null) return;
    try {
      await api.unregisterDevice(_token!);
    } catch (_) {/* the server also drops tokens Firebase reports as invalid */}
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _token = null;
  }
}
