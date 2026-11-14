import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'funding.dart';
import 'proposal.dart';

/// Map of Ongoing and Completed proposals (never Abandoned), with impact circles.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int tab = 0;
  bool onlyFollowing = false;
  Map<String, dynamic>? selected;
  late Future<Map<String, dynamic>> _future = _load();
  final _map = MapController();

  String get status => tab == 0 ? 'ongoing' : 'completed';

  Future<Map<String, dynamic>> _load() => context.read<AppState>().api.mapPins(status, onlyFollowing);

  void _reload() => setState(() {
        selected = null;
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    final colour = tab == 0 ? C.statusOngoing : C.statusCompleted;
    return AppShell(
      title: tr(lang, 'map'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillTabs(
            labels: [tr(lang, 'ongoing'), tr(lang, 'completed')],
            selected: tab,
            onChanged: (i) {
              tab = i;
              _reload();
            },
          ),
          SwitchListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(tr(lang, 'onlyFollowing'), style: const TextStyle(fontSize: 14)),
            value: onlyFollowing,
            activeColor: C.navy,
            onChanged: (v) {
              onlyFollowing = v;
              _reload();
            },
          ),
          Expanded(
            child: Panel(
              tone: tab,
              child: FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) return const LoadingView();
                  if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _reload);
                  final pins = List<Map<String, dynamic>>.from(snap.data!['pins'] as List? ?? const []);
                  return Stack(children: [
                    FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: pins.isNotEmpty
                            ? LatLng((pins.first['lat'] as num).toDouble(), (pins.first['lng'] as num).toDouble())
                            : const LatLng(defaultLat, defaultLng),
                        initialZoom: 12,
                        onTap: (_, __) => setState(() => selected = null),
                      ),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'ca.civicspeak.app'),
                        CircleLayer(circles: [
                          for (final p in pins)
                            if (p['radius_km'] != null)
                              CircleMarker(
                                point: _pt(p),
                                radius: (p['radius_km'] as num).toDouble() * 1000,
                                useRadiusInMeter: true,
                                color: colour.withOpacity(0.15),
                                borderColor: colour,
                                borderStrokeWidth: 1.5,
                              ),
                        ]),
                        MarkerLayer(markers: [
                          for (final p in pins)
                            Marker(
                              point: _pt(p),
                              width: 44,
                              height: 44,
                              alignment: Alignment.topCenter,
                              child: Semantics(
                                button: true,
                                label: p['title'] as String? ?? '',
                                child: GestureDetector(
                                  onTap: () => setState(() => selected = p),
                                  child: Icon(Icons.location_on, size: 40, color: p['following'] == true ? C.pin : colour),
                                ),
                              ),
                            ),
                        ]),
                        RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
                      ],
                    ),
                    if (pins.isEmpty) Positioned(left: 10, right: 10, top: 10, child: NoteBox(tr(lang, 'noPins'))),
                    Positioned(
                      left: 10,
                      top: pins.isEmpty ? null : 10,
                      bottom: pins.isEmpty ? 10 : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                        child: Text(tr(lang, 'radiusNote'), style: sans(size: 11)),
                      ),
                    ),
                    if (selected != null) Positioned(left: 10, right: 10, bottom: 10, child: _popup(selected!, lang)),
                  ]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  LatLng _pt(Map<String, dynamic> p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());

  Widget _popup(Map<String, dynamic> p, String lang) {
    final id = p['id'] as int;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(tooltip: tr(lang, 'back'), onPressed: () => setState(() => selected = null), icon: const Icon(Icons.close, size: 20)),
          ]),
          InkWell(
            onTap: () => push(context, FundingScreen(id: id, title: p['title'] as String? ?? '')),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${tr(lang, 'costLabel')}: ${p['cost']}', style: const TextStyle(fontSize: 13.5)),
                Text('${tr(lang, 'whoPays')}: ${List<String>.from(p['payers'] as List? ?? const []).join(', ')}', style: const TextStyle(fontSize: 13.5)),
                Text('${tr(lang, 'when')}: ${p['when']}', style: const TextStyle(fontSize: 13.5)),
                Text('${tr(lang, 'moneyFlowing')} →', style: const TextStyle(fontSize: 13, color: C.focus, decoration: TextDecoration.underline)),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () async {
                await push(context, ProposalScreen(id: id));
                _reload(); // follow state may have changed
              },
              child: Text(tr(lang, 'open')),
            ),
          ),
        ]),
      ),
    );
  }
}
