import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _navy   = Color(0xFF031634);
const _blue   = Color(0xFF0453CD);
const _green  = Color(0xFF22C55E);
const _orange = Color(0xFFF97316);
const _red    = Color(0xFFDC2626);

// ── Public entry-point ────────────────────────────────────────────────────────
void showTripDetail(BuildContext context, Map trip) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TripDetailSheet(trip: trip),
  );
}

// ── FMCSA Stop calculation ────────────────────────────────────────────────────
class _FmcsaStop {
  final String type;      // 'break' | 'overnight' | 'restart'
  final String title;
  final String subtitle;
  final DateTime stopBy;
  final DateTime resumeAt;
  final double milesAtStop;
  final double milesRemaining;

  _FmcsaStop({
    required this.type, required this.title, required this.subtitle,
    required this.stopBy, required this.resumeAt,
    required this.milesAtStop, required this.milesRemaining,
  });
}

List<_FmcsaStop> calcStops({
  required DateTime departure,
  required double totalMiles,
  required double avgMph,
}) {
  final stops = <_FmcsaStop>[];
  if (totalMiles <= 0 || avgMph <= 0) return stops;

  // FMCSA constants (hours)
  const breakAfterH     = 8.0;
  const breakDurH       = 0.5;
  const drivingLimitH   = 11.0;
  const overnightRestH  = 10.0;

  double drivenH    = 0.0;      // hours driven this shift
  double elapsedH   = 0.0;      // wall-clock hours since departure
  double drivenMi   = 0.0;      // miles covered so far
  bool   breakTaken = false;
  int    day        = 1;

  while (drivenMi < totalMiles) {
    final remainingMi = totalMiles - drivenMi;

    // --- Check 30-min break (at 8h driving, once per shift) ---
    if (!breakTaken && drivenH >= breakAfterH) {
      final stopAt   = departure.add(Duration(milliseconds: (elapsedH * 3600000).round()));
      final resumeAt = stopAt.add(const Duration(minutes: 30));
      stops.add(_FmcsaStop(
        type:          'break',
        title:         '30-Min Break (Day $day)',
        subtitle:      'After 8h driving — by ${_fmtDateTime(stopAt)}',
        stopBy:        stopAt,
        resumeAt:      resumeAt,
        milesAtStop:   drivenMi,
        milesRemaining: remainingMi,
      ));
      elapsedH  += breakDurH;
      breakTaken = true;
      continue;
    }

    // --- Check overnight (at 11h driving limit) ---
    if (drivenH >= drivingLimitH) {
      final stopAt   = departure.add(Duration(milliseconds: (elapsedH * 3600000).round()));
      final resumeAt = stopAt.add(Duration(hours: overnightRestH.round()));
      stops.add(_FmcsaStop(
        type:          'overnight',
        title:         'Overnight Stop',
        subtitle:      'Stop by: ${_fmtDateTime(stopAt)} · 10-hour rest\n'
                       'Resume: ${_fmtDateTime(resumeAt)} · Remaining: ${_fmtMi(remainingMi)}',
        stopBy:        stopAt,
        resumeAt:      resumeAt,
        milesAtStop:   drivenMi,
        milesRemaining: remainingMi,
      ));
      // Reset shift
      elapsedH  += overnightRestH;
      drivenH    = 0.0;
      breakTaken = false;
      day++;
      continue;
    }

    // --- Drive until next event ---
    double hoursUntilBreak    = breakTaken ? double.infinity : breakAfterH - drivenH;
    double hoursUntilOvernight = drivingLimitH - drivenH;
    double nextEventH         = math.min(hoursUntilBreak, hoursUntilOvernight);
    double hoursToDestination = remainingMi / avgMph;

    if (hoursToDestination <= nextEventH) {
      // Reached destination before next event
      break;
    }

    // Drive to next event
    final driveH = nextEventH;
    drivenMi  += driveH * avgMph;
    drivenH   += driveH;
    elapsedH  += driveH;
  }

  return stops;
}

String _fmtDateTime(DateTime dt) {
  final d = dt.toLocal();
  final weekday = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d.weekday - 1];
  final mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month - 1];
  final h   = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m   = d.minute.toString().padLeft(2, '0');
  final ap  = d.hour >= 12 ? 'PM' : 'AM';
  return '$weekday, $mon ${d.day}, $h:$m $ap';
}

String _fmtMi(double mi) => '${mi.toStringAsFixed(0)} mi';

// ── Bottom sheet widget ───────────────────────────────────────────────────────
class _TripDetailSheet extends StatelessWidget {
  final Map trip;
  const _TripDetailSheet({required this.trip});

  String _loc(List<String> cityK, List<String> stateK, String? addrK) {
    String _s(dynamic v) => v?.toString() ?? '';
    final city  = cityK.map((k) => _s(trip[k])).firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final state = stateK.map((k) => _s(trip[k])).firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final combo = [city, state].where((s) => s.isNotEmpty).join(', ');
    if (combo.isNotEmpty) return combo;
    if (addrK != null) return _s(trip[addrK]).isNotEmpty ? _s(trip[addrK]) : '—';
    return '—';
  }

  String _fmtDate(dynamic d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
      final mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dt.month - 1];
      return '$mon ${dt.day}, ${dt.year}';
    } catch (_) { return d.toString(); }
  }

  String _fmtTime(dynamic d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
      final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m  = dt.minute.toString().padLeft(2, '0');
      final ap = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ap';
    } catch (_) { return d.toString(); }
  }

  @override
  Widget build(BuildContext context) {
    final from  = _loc(['origin_city','origin'], ['origin_state','origin_st'], 'origin_address');
    final to    = _loc(['destination_city','destination'], ['destination_state','destination_st'], 'destination_address');

    final tripId     = trip['trip_number'] as String? ?? trip['id']?.toString() ?? '—';
    final statusRaw  = trip['status'] as String? ?? 'active';
    final driver     = trip['driver_name'] as String?
        ?? (trip['driver'] != null ? trip['driver'].toString() : null)
        ?? '—';
    final truck      = trip['truck_number'] as String?
        ?? trip['truck__unit_number'] as String?
        ?? (trip['truck'] != null ? trip['truck'].toString() : null)
        ?? '—';
    final totalMiles = (trip['total_miles'] as num?)?.toDouble() ?? 0;
    final drivenMiles = (trip['miles_driven'] as num?)?.toDouble() ?? 0;
    final startDate  = _fmtDate(trip['start_date']);
    final endDate    = _fmtDate(trip['end_date']);
    final depTime    = _fmtTime(trip['departure_time'] ?? trip['start_date']);
    final estArrival = _fmtDateTime(_parseOrNow(trip['end_date']));

    // Drive duration from miles at 60mph average
    final avgMph        = 60.0;
    final totalDriveH   = totalMiles > 0 ? totalMiles / avgMph : 0.0;
    final durH          = totalDriveH.floor();
    final durM          = ((totalDriveH - durH) * 60).round();
    final driveDuration = '${durH}h ${durM}m';

    // Miles by state
    final stateBreakdown = <String, double>{};
    if (trip['state_miles'] is Map) {
      (trip['state_miles'] as Map).forEach((k, v) =>
          stateBreakdown[k.toString()] = (v as num).toDouble());
    }

    // FMCSA stops
    final departure = _parseOrNow(trip['departure_time'] ?? trip['start_date']);
    final stops     = calcStops(departure: departure, totalMiles: totalMiles, avgMph: avgMph);
    final needStop  = stops.any((s) => s.type == 'overnight');
    final needBreak = stops.any((s) => s.type == 'break');

    final statusColor = switch (statusRaw) {
      'active' || 'in_progress' => _blue,
      'completed' => _green,
      _ => _orange };
    final statusLabel = statusRaw.replaceAll('_', ' ').toUpperCase();

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Drag handle
          Padding(padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),
          Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16,8,16,24), children: [
            // ── Header ────────────────────────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tripId, style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w900, color: _navy)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.35)),
                  ),
                  child: Text(statusLabel, style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 28, height: 28,
                  decoration: BoxDecoration(color: Colors.grey.shade100,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 15, color: Colors.grey)),
              ),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 10),

            // ── Trip details grid ──────────────────────────────────────────────
            _row2('FROM', from, 'TO', to),
            _row2('DRIVER', driver, 'TRUCK', truck),
            _row2('DATE RANGE', '$startDate – $endDate', 'TOTAL MILES',
                '${totalMiles.toStringAsFixed(2)} mi', bold2: true),
            _row2('DEPARTURE TIME', depTime, 'DRIVE DURATION', driveDuration),

            // Est arrival spans full width
            const SizedBox(height: 4),
            _label('EST. ARRIVAL'),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.flight_land_rounded, size: 14, color: _blue),
              const SizedBox(width: 6),
              Text(estArrival, style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
            ]),

            // ── Miles by state ─────────────────────────────────────────────────
            if (stateBreakdown.isNotEmpty) ...[
              const SizedBox(height: 10),
              _label('MILES BY STATE (IFTA)'),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6,
                children: stateBreakdown.entries.map((e) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F3FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD0D9F5)),
                  ),
                  child: Text('${e.key}  ${e.value.toStringAsFixed(1)} mi',
                      style: GoogleFonts.inter(fontSize: 10,
                          fontWeight: FontWeight.w700, color: _navy)),
                )).toList(),
              ),
            ],

            // ── FMCSA stops ────────────────────────────────────────────────────
            if (stops.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _red.withOpacity(0.25)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Header row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Row(children: [
                      const Icon(Icons.schedule_rounded, color: _red, size: 15),
                      const SizedBox(width: 5),
                      Expanded(child: Text(needStop ? '🛏  Overnight Stop Required (FMCSA)'
                                    : '☕  Break Required (FMCSA)',
                          style: GoogleFonts.inter(fontSize: 11,
                              fontWeight: FontWeight.w800, color: _red))),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                    child: Text(
                      needStop
                          ? 'Overnight stop required — exceeds 11-hour daily driving limit (FMCSA).'
                          : 'A 30-minute break is required after 8 hours of driving (FMCSA).',
                      style: GoogleFonts.inter(fontSize: 10, color: _red.withOpacity(0.75)),
                    ),
                  ),
                  // Stop tiles
                  ...stops.map((s) => _StopTile(stop: s)),
                  const SizedBox(height: 2),
                ]),
              ),
            ],

            // ── Progress bar ───────────────────────────────────────────────────
            if (totalMiles > 0) ...[
              const SizedBox(height: 10),
              _label('ROUTE PROGRESS'),
              const SizedBox(height: 6),
              _ProgressSection(driven: drivenMiles, total: totalMiles),
            ],
          ])),
        ]),
      ),
    );
  }

  // ── Layout helpers ──────────────────────────────────────────────────────────
  Widget _row2(String l1, String v1, String l2, String v2, {bool bold2 = false}) =>
      Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label(l1), const SizedBox(height: 2),
            Text(v1, style: GoogleFonts.inter(fontSize: 12,
                fontWeight: FontWeight.w700, color: _navy)),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label(l2), const SizedBox(height: 2),
            Text(v2, style: GoogleFonts.inter(fontSize: 12,
                fontWeight: bold2 ? FontWeight.w900 : FontWeight.w700,
                color: bold2 ? _blue : _navy)),
          ])),
        ]));

  Widget _label(String t) => Text(t, style: GoogleFonts.inter(
      fontSize: 9, fontWeight: FontWeight.w700,
      color: Colors.grey, letterSpacing: 0.5));

  DateTime _parseOrNow(dynamic d) {
    if (d == null) return DateTime.now();
    try { return DateTime.parse(d.toString()); } catch (_) { return DateTime.now(); }
  }
}

// ── Stop tile ─────────────────────────────────────────────────────────────────
class _StopTile extends StatelessWidget {
  final _FmcsaStop stop;
  const _StopTile({required this.stop});

  @override
  Widget build(BuildContext context) {
    final isOvernight = stop.type == 'overnight';
    final col   = isOvernight ? _red : _orange;
    final icon  = isOvernight ? Icons.hotel_rounded : Icons.free_breakfast_rounded;
    final lines = stop.subtitle.split('\n');

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: col, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(stop.title, style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w800, color: col)),
          const SizedBox(height: 1),
          ...lines.map((l) => Text(l.trim(), style: GoogleFonts.inter(
              fontSize: 10, color: const Color(0xFF475569)))),
        ])),
      ]),
    );
  }
}

// ── Progress bar section ───────────────────────────────────────────────────────
class _ProgressSection extends StatelessWidget {
  final double driven, total;
  const _ProgressSection({required this.driven, required this.total});
  @override
  Widget build(BuildContext context) {
    final pct = (driven / total).clamp(0.0, 1.0);
    return Column(children: [
      Stack(children: [
        Container(height: 10, decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(5))),
        FractionallySizedBox(widthFactor: pct > 0 ? pct : 0.02,
          child: Container(height: 10, decoration: BoxDecoration(
              color: _blue, borderRadius: BorderRadius.circular(5),
              boxShadow: [BoxShadow(color: _blue.withOpacity(0.35),
                  blurRadius: 6, offset: const Offset(0, 2))]))),
      ]),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${driven.toStringAsFixed(0)} mi driven',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
        Text('${(pct * 100).round()}%',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _blue)),
        Text('${(total - driven).toStringAsFixed(0)} mi left',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
      ]),
    ]);
  }
}
