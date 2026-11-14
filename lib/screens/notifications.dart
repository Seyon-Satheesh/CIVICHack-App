import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'community.dart';
import 'proposal.dart';

/// Notifications: only followed proposals, community stories and open decisions that match the survey.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    final state = context.read<AppState>();
    final data = await state.api.notifications();
    if ((data['unread'] as int? ?? 0) > 0) {
      try {
        await state.api.markNotificationsRead();
      } catch (_) {/* not critical */}
    }
    await state.refreshUnread();
    return data;
  }

  static const _icons = {
    'update': Icons.update,
    'impact': Icons.insights_outlined,
    'community': Icons.groups_outlined,
    'open': Icons.campaign_outlined,
    'new': Icons.fiber_new_outlined,
    'changed': Icons.edit_note,
  };

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    return AppShell(
      title: tr(lang, 'notifications'),
      child: Panel(
        tone: 0,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingView();
            if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: () => setState(() => _future = _load()));
            final items = List<Map<String, dynamic>>.from(snap.data!['results'] as List? ?? const []);
            return RefreshIndicator(
              color: C.navy,
              onRefresh: () async {
                final f = _load();
                setState(() => _future = f);
                await f;
              },
              child: ListView(
                padding: const EdgeInsets.all(12),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Muted(tr(lang, 'notifNote'), size: 12.5),
                  const SizedBox(height: 10),
                  if (items.isEmpty) EmptyNote(tr(lang, 'noNotifs')),
                  for (final n in items)
                    WhiteCard(
                      onTap: () {
                        final pid = n['proposal_id'] as int?;
                        if (n['kind'] == 'community') {
                          push(context, const CommunityScreen());
                        } else if (pid != null) {
                          push(context, ProposalScreen(id: pid));
                        }
                      },
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(_icons[n['kind']] ?? Icons.notifications_none, color: C.navy),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n['text'] as String? ?? '', style: TextStyle(fontWeight: n['read'] == true ? FontWeight.w400 : FontWeight.w700)),
                            if (n['date'] != null) Muted('${n['date']}', size: 12),
                          ]),
                        ),
                        if (n['read'] != true) Tag(tr(lang, 'new'), bg: C.navy, fg: Colors.white),
                      ]),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
