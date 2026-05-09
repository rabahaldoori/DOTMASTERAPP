import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_client.dart';

// ─── Data model ───────────────────────────────────────────────────────────────
class RouteOption {
  final String label;        // "Fastest", "Avoid Tolls", "Avoid Highways"
  final String viaSummary;   // highway name from Google
  final double totalMiles;
  final String durationText;
  final int durationSeconds;
  final String originAddress;
  final String destinationAddress;
  final Map<String, dynamic> milesPerState;
  final String statesTraveled;
  final String routePolyline;

  const RouteOption({
    required this.label,
    required this.viaSummary,
    required this.totalMiles,
    required this.durationText,
    required this.durationSeconds,
    required this.originAddress,
    required this.destinationAddress,
    required this.milesPerState,
    required this.statesTraveled,
    required this.routePolyline,
  });
}

// ─── Public entry point ───────────────────────────────────────────────────────
/// Shows the route picker bottom sheet.
/// Returns the chosen [RouteOption] or null if dismissed.
Future<RouteOption?> showRoutePicker(
  BuildContext context, {
  required String origin,
  required String destination,
}) {
  return showModalBottomSheet<RouteOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RoutePickerSheet(origin: origin, destination: destination),
  );
}

// ─── Sheet widget ─────────────────────────────────────────────────────────────
class _RoutePickerSheet extends StatefulWidget {
  final String origin;
  final String destination;
  const _RoutePickerSheet({required this.origin, required this.destination});

  @override
  State<_RoutePickerSheet> createState() => _RoutePickerSheetState();
}

class _RoutePickerSheetState extends State<_RoutePickerSheet> {
  static const _navy   = Color(0xFF0A1628);
  static const _blue   = Color(0xFF1E3A8A);
  static const _accent = Color(0xFF3B82F6);

  bool _loading = true;
  String? _error;
  List<RouteOption> _routes = [];
  int _selectedIdx = 0;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  // ── Fetch 3 route variants in parallel ─────────────────────────────────────
  Future<void> _fetchRoutes() async {
    setState(() { _loading = true; _error = null; });

    try {
      final results = await Future.wait([
        _calcRoute('Fastest',        avoidTolls: false, avoidHighways: false),
        _calcRoute('Avoid Tolls',    avoidTolls: true,  avoidHighways: false),
        _calcRoute('Avoid Highways', avoidTolls: false, avoidHighways: true),
      ]);

      // Remove nulls and deduplicate by duration bucket (5-min windows)
      final seen = <int>{};
      final unique = results.whereType<RouteOption>().where((r) {
        final key = (r.durationSeconds / 300).round();
        return seen.add(key);
      }).toList()
        ..sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));

      setState(() { _routes = unique; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<RouteOption?> _calcRoute(
    String label, {
    required bool avoidTolls,
    required bool avoidHighways,
  }) async {
    try {
      final res = await ApiClient.calculateRoute(
        origin:         widget.origin,
        destination:    widget.destination,
        avoidTolls:     avoidTolls,
        avoidHighways:  avoidHighways,
      );
      final d = res.data as Map<String, dynamic>;

      // Parse miles_by_state — comes as {"TX": "641.75", "NM": "164.19", ...}
      final rawState = d['miles_by_state'] as Map<String, dynamic>? ?? {};
      final stateMap = rawState.map((k, v) => MapEntry(k, v));

      final seconds = (d['duration_seconds'] as num?)?.toInt() ?? 0;
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      final durText = d['duration_text'] as String? ??
          (h > 0 ? '${h}h ${m}m' : '${m}m');

      return RouteOption(
        label:               label,
        viaSummary:          d['via_summary'] as String? ?? label,
        totalMiles:          (d['total_miles'] as num?)?.toDouble() ?? 0,
        durationText:        durText,
        durationSeconds:     seconds,
        originAddress:       d['origin_address'] as String? ?? widget.origin,
        destinationAddress:  d['destination_address'] as String? ?? widget.destination,
        milesPerState:       stateMap,
        statesTraveled:      d['states_traveled'] as String? ?? '',
        routePolyline:       d['route_polyline'] as String? ?? '',
      );
    } catch (_) {
      return null; // this variant failed — skip it
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(children: [
              const Icon(Icons.alt_route_rounded, color: _blue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Choose Your Route',
                    style: GoogleFonts.inter(fontSize: 16,
                        fontWeight: FontWeight.w800, color: _navy)),
                  Text('Select the route you want to take',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // Route — From / To summary
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(children: [
                Column(children: [
                  const Icon(Icons.circle, color: Color(0xFF22C55E), size: 8),
                  Container(width: 1, height: 18, color: Colors.grey[300]),
                  const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 12),
                ]),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.origin,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                        color: _navy), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(widget.destination,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                        color: _navy), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
              ]),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Body
          Expanded(child: _loading
            ? const Center(child: _LoadingRoutesWidget())
            : _error != null
              ? _ErrorWidget(error: _error!, onRetry: _fetchRoutes)
              : ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    ..._routes.asMap().entries.map((e) =>
                      _RouteCard(
                        option:     e.value,
                        isSelected: e.key == _selectedIdx,
                        onTap:      () => setState(() => _selectedIdx = e.key),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
          ),

          // Confirm button
          if (!_loading && _error == null && _routes.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text('Start Trip with this Route',
                      style: GoogleFonts.inter(fontSize: 14,
                          fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context, _routes[_selectedIdx]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─── Route card ───────────────────────────────────────────────────────────────
class _RouteCard extends StatelessWidget {
  final RouteOption option;
  final bool isSelected;
  final VoidCallback onTap;

  static const _navy  = Color(0xFF0A1628);
  static const _blue  = Color(0xFF1E3A8A);
  static const _accent = Color(0xFF3B82F6);

  const _RouteCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _accent : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: _accent.withOpacity(0.15),
                blurRadius: 12, offset: const Offset(0, 4)),
          ] : [
            BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Radio dot
          Container(
            width: 20, height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? _accent : Colors.transparent,
              border: Border.all(
                color: isSelected ? _accent : Colors.grey[400]!,
                width: 2,
              ),
            ),
            child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 12)
              : null,
          ),
          const SizedBox(width: 12),

          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Label + duration
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _tag(option.label),
              Text(option.durationText,
                style: GoogleFonts.inter(fontSize: 13,
                    fontWeight: FontWeight.w800, color: _navy)),
            ]),
            const SizedBox(height: 4),

            // Via summary
            Text('via ${option.viaSummary}',
              style: GoogleFonts.inter(fontSize: 11,
                  color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),

            // Miles row
            Row(children: [
              const Icon(Icons.straighten_rounded, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${option.totalMiles.toStringAsFixed(1)} mi total',
                style: GoogleFonts.inter(fontSize: 12,
                    fontWeight: FontWeight.w700, color: _blue)),
            ]),

            // State chips
            if (option.milesPerState.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 4, runSpacing: 4,
                children: option.milesPerState.entries.map((e) {
                  final mi = (e.value as num).toDouble();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F3FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD0D9F5)),
                    ),
                    child: Text('${e.key}  ${mi.toStringAsFixed(1)} mi',
                      style: GoogleFonts.inter(fontSize: 9,
                          fontWeight: FontWeight.w700, color: _blue)),
                  );
                }).toList(),
              ),
            ],
          ])),
        ]),
      ),
    );
  }

  Widget _tag(String label) {
    final Map<String, Color> colors = {
      'Fastest':        const Color(0xFF22C55E),
      'Avoid Tolls':    const Color(0xFFF59E0B),
      'Avoid Highways': const Color(0xFF8B5CF6),
    };
    final color = colors[label] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
        style: GoogleFonts.inter(fontSize: 10,
            fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ─── Loading widget ───────────────────────────────────────────────────────────
class _LoadingRoutesWidget extends StatelessWidget {
  const _LoadingRoutesWidget();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CircularProgressIndicator(color: Color(0xFF1E3A8A)),
      const SizedBox(height: 16),
      Text('Finding best routes…',
        style: GoogleFonts.inter(fontSize: 13,
            fontWeight: FontWeight.w600, color: Colors.grey[600])),
      const SizedBox(height: 4),
      Text('Fastest · Avoid Tolls · Avoid Highways',
        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[400])),
    ],
  );
}

// ─── Error widget ─────────────────────────────────────────────────────────────
class _ErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
        const SizedBox(height: 12),
        Text('Could not load routes', style: GoogleFonts.inter(
            fontWeight: FontWeight.w700, color: const Color(0xFF0A1628))),
        const SizedBox(height: 6),
        Text(error, textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 16),
        TextButton.icon(
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Again'),
          onPressed: onRetry,
        ),
      ]),
    ),
  );
}
