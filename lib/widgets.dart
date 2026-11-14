import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'i18n.dart';
import 'screens/community.dart';
import 'screens/map.dart';
import 'screens/notifications.dart';
import 'screens/settings.dart';
import 'state.dart';
import 'theme.dart';

/// Translate a key in the current language.
String t(BuildContext context, String key) => tr(context.watch<AppState>().language, key);
String tRead(BuildContext context, String key) => tr(context.read<AppState>().language, key);

/// Which Home tab is showing. The Home button resets it to Ongoing.
final homeTab = ValueNotifier<int>(0);

void goHome(BuildContext context) {
  homeTab.value = 0;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

Future<T?> push<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) toast(context, "Couldn't open the link: $url");
  }
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: C.navy, behavior: SnackBarBehavior.floating));
}

/// The card-on-grey layout from the mockups, with the header row of icons.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.title, required this.child, this.icons = true, this.wrapTitle = false, this.leading});
  final String title;
  final Widget child;
  final bool icons;
  final bool wrapTitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (leading != null) leading! else if (canPop && !icons)
                        IconButton(tooltip: tr(state.language, 'back'), onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back)),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            maxLines: wrapTitle ? 3 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: wrapTitle ? 19 : 22),
                          ),
                        ),
                      ),
                      if (icons) ...[
                        _HeaderIcon(tooltip: tr(state.language, 'home'), icon: Icons.home_outlined, onTap: () => goHome(context)),
                        _HeaderIcon(
                          tooltip: tr(state.language, 'map'),
                          icon: Icons.location_on,
                          color: C.pin,
                          size: 30,
                          onTap: () => push(context, const MapScreen()),
                        ),
                        _HeaderIcon(
                          tooltip: tr(state.language, 'notifications'),
                          icon: Icons.notifications_none,
                          badge: state.unread,
                          onTap: () => push(context, const NotificationsScreen()),
                        ),
                        _HeaderIcon(tooltip: tr(state.language, 'community'), icon: Icons.groups_outlined, onTap: () => push(context, const CommunityScreen())),
                        _HeaderIcon(tooltip: tr(state.language, 'settings'), icon: Icons.settings_outlined, onTap: () => push(context, const SettingsScreen())),
                      ] else
                        const Icon(Icons.location_on, color: C.pin, size: 30, semanticLabel: 'CivicSpeak'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.tooltip, required this.icon, required this.onTap, this.color = const Color(0xFF7D868F), this.size = 24, this.badge = 0});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final btn = IconButton(
      tooltip: badge > 0 ? '$tooltip ($badge)' : tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: color, size: size),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
    );
    if (badge <= 0) return btn;
    return Badge(label: Text('$badge'), backgroundColor: C.navy, offset: const Offset(-4, 4), child: btn);
  }
}

/// Coloured pill tabs (blue, green, orange, purple) like the mock.
class PillTabs extends StatelessWidget {
  const PillTabs({super.key, required this.labels, required this.selected, required this.onChanged});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: Material(
                  color: tabColors[i % tabColors.length].withOpacity(i == selected ? 1 : 0.5),
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: i == selected ? FontWeight.w700 : FontWeight.w400),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The soft-coloured rounded panel under the tabs.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.tone = 0});
  final Widget child;
  final int tone;

  @override
  Widget build(BuildContext context) {
    final (bg, border) = panelColors[tone % panelColors.length];
    return Container(
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}

class WhiteCard extends StatelessWidget {
  const WhiteCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final highContrast = context.watch<AppState>().audioMode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: highContrast ? const Color(0xFF7D8A95) : C.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Bold heading with a navy underline, optionally numbered (Breakdown sections).
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.number, this.color = C.navy});
  final String text;
  final int? number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: color, width: 2))),
      child: Row(children: [
        if (number != null) ...[
          CircleAvatar(radius: 11, backgroundColor: color, child: Text('$number', style: sans(size: 11, color: Colors.white, weight: FontWeight.w700))),
          const SizedBox(width: 8),
        ],
        Expanded(child: Semantics(header: true, child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)))),
      ]),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.bg = const Color(0xFFEEF1F3), this.fg = const Color(0xFF33404A), this.border});
  final String text;
  final Color bg;
  final Color fg;
  final Color? border;

  factory Tag.status(String status, String label) {
    switch (status) {
      case 'completed':
        return Tag(label, bg: C.green, fg: const Color(0xFF16402A));
      case 'abandoned':
        return Tag(label, bg: C.orange, fg: const Color(0xFF5A3A10));
      default:
        return Tag(label, bg: C.blue, fg: const Color(0xFF163044));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: border != null ? Border.all(color: border!) : null),
      child: Text(text, style: sans(size: 11.5, color: fg)),
    );
  }
}

class Bullets extends StatelessWidget {
  const Bullets(this.items, {super.key});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 1, right: 8), child: Text('•')),
              Expanded(child: Text(item)),
            ]),
          ),
      ],
    );
  }
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 13, this.italic = false});
  final String text;
  final double size;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final strong = context.watch<AppState>().audioMode;
    return Text(text, style: TextStyle(color: strong ? C.mutedStrong : C.muted, fontSize: size, fontStyle: italic ? FontStyle.italic : FontStyle.normal));
  }
}

class ReadAloudButton extends StatelessWidget {
  const ReadAloudButton(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.audioMode) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton.icon(
          onPressed: () => state.speak(text),
          icon: const Icon(Icons.volume_up_outlined),
          label: Text(tr(state.language, 'readAloud')),
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Semantics(label: t(context, 'loading'), child: const CircularProgressIndicator(color: C.navy)),
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(t(context, 'retry'))),
          ]),
        ),
      );
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 10),
        child: Center(child: Muted(text, size: 14)),
      );
}

class NoteBox extends StatelessWidget {
  const NoteBox(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFCFD6DC))),
        child: Muted(text, size: 12.5),
      );
}
