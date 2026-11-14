import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'push.dart';

/// App-wide state: sign-in, profile, display preferences and the unread count.
class AppState extends ChangeNotifier {
  AppState({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;
  final FlutterTts _tts = FlutterTts();

  bool ready = false;
  Map<String, dynamic>? profile;
  Map<String, dynamic>? meta;
  int unread = 0;

  // Display preferences (kept on the device too, so they apply before sign-in).
  String language = 'en';
  bool audioMode = false;
  bool largeText = false;

  bool get signedIn => api.token != null && profile != null;
  String get username => (profile?['username'] as String?) ?? '';
  List<int> get following => List<int>.from(profile?['following'] as List? ?? const []);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString('language') ?? 'en';
    audioMode = prefs.getBool('audioMode') ?? false;
    largeText = prefs.getBool('largeText') ?? false;
    api.token = prefs.getString('token');
    if (api.token != null) {
      try {
        profile = (await api.me())['profile'] as Map<String, dynamic>;
        _applyProfilePrefs();
        await refreshUnread();
        unawaited(PushService.instance.register(api));
      } on ApiException catch (e) {
        if (e.unauthorized) await _clearToken();
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<Map<String, dynamic>> loadMeta() async {
    meta ??= await api.meta();
    return meta!;
  }

  Future<void> _saveToken(String token) async {
    api.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> _clearToken() async {
    api.token = null;
    profile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  void _applyProfilePrefs() {
    final p = profile;
    if (p == null) return;
    language = (p['language'] as String?) ?? language;
    audioMode = (p['audio_mode'] as bool?) ?? audioMode;
    largeText = (p['large_text'] as bool?) ?? largeText;
  }

  Future<void> register(Map<String, dynamic> body) async {
    final data = await api.register({...body, 'language': language, 'audio_mode': audioMode, 'large_text': largeText});
    await _saveToken(data['token'] as String);
    profile = data['profile'] as Map<String, dynamic>;
    await refreshUnread();
    notifyListeners();
    unawaited(PushService.instance.register(api));
  }

  Future<void> login(String username, String password) async {
    final data = await api.login(username, password);
    await _saveToken(data['token'] as String);
    profile = data['profile'] as Map<String, dynamic>;
    _applyProfilePrefs();
    await refreshUnread();
    notifyListeners();
    unawaited(PushService.instance.register(api));
  }

  Future<void> signOut() async {
    await PushService.instance.unregister(api); // while the token is still valid
    await _clearToken();
    unread = 0;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> changes) async {
    final data = await api.updateMe(changes);
    profile = data['profile'] as Map<String, dynamic>;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (api.token == null) return;
    profile = (await api.me())['profile'] as Map<String, dynamic>;
    notifyListeners();
  }

  Future<void> refreshUnread() async {
    if (api.token == null) return;
    try {
      unread = (await api.notifications())['unread'] as int? ?? 0;
      notifyListeners();
    } on ApiException {
      // Not critical.
    }
  }

  void setFollowing(int id, bool on) {
    final list = following;
    if (on && !list.contains(id)) {
      list.add(id);
    } else if (!on) {
      list.remove(id);
    }
    profile = {...?profile, 'following': list};
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    language = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', code);
    notifyListeners();
    if (signedIn) await updateProfile({'language': code});
  }

  Future<void> setAudioMode(bool on) async {
    audioMode = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audioMode', on);
    if (!on) await _tts.stop();
    notifyListeners();
    if (signedIn) await updateProfile({'audio_mode': on});
  }

  Future<void> setLargeText(bool on) async {
    largeText = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('largeText', on);
    notifyListeners();
    if (signedIn) await updateProfile({'large_text': on});
  }

  /// Reads text aloud (only offered when audio mode is on).
  Future<void> speak(String text) async {
    const voices = {'en': 'en-CA', 'fr': 'fr-CA', 'es': 'es-ES', 'zh': 'zh-CN'};
    await _tts.setLanguage(voices[language] ?? 'en-CA');
    await _tts.setSpeechRate(0.45);
    await _tts.stop();
    await _tts.speak(text);
  }
}
