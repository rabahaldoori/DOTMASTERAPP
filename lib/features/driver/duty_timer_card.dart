import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_client.dart';

/// A live duty time tracking card for the driver dashboard.
/// Shows elapsed time, HOS bars, and Start/End duty controls.
class DutyTimerCard extends StatefulWidget {
  const DutyTimerCard({super.key});

  @override
  State<DutyTimerCard> createState() => _DutyTimerCardState();
}

class _DutyTimerCardState extends State<DutyTimerCard> {
  // ── state ───────────────────────────────────────────────────────────────────
  bool   _loading   = true;
  bool   _actionBusy = false;
  String _status    = 'off_duty'; // current active session status
  bool   _isActive  = false;
  int    _elapsedSecs  = 0;  // seconds since duty start
  int    _drivingSecs  = 0;
  int    _onDutySecs   = 0;
  int    _drivingLimit = 11 * 3600;
  int    _onDutyLimit  = 14 * 3600;

  DateTime? _sessionStart;
  Timer? _ticker;

  // ── lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── data ────────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.getDutyStatus();
      final data = res.data as Map<String, dynamic>;
      final session = data['active_session'];
      final hos = data['hos'] as Map<String, dynamic>;

      _drivingSecs = (hos['driving_seconds'] as num).toInt();
      _onDutySecs  = (hos['on_duty_seconds']  as num).toInt();
      _drivingLimit = (hos['driving_limit']   as num).toInt();
      _onDutyLimit  = (hos['on_duty_limit']   as num).toInt();

      if (session != null) {
        _isActive  = session['is_active'] as bool? ?? false;
        _status    = session['status'] as String? ?? 'on_duty';
        _elapsedSecs = (session['duration_seconds'] as num).toInt();
        _sessionStart = DateTime.now().subtract(Duration(seconds: _elapsedSecs));
        if (_isActive) _startTicker();
      } else {
        _isActive = false;
        _elapsedSecs = 0;
        _ticker?.cancel();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSecs++;
        // also increment HOS counters live
        if (_status == 'driving') _drivingSecs++;
        if (_status == 'driving' || _status == 'on_duty') _onDutySecs++;
      });
    });
  }

  Future<void> _startDuty(String statusChoice) async {
    setState(() => _actionBusy = true);
    try {
      await ApiClient.startDuty(statusChoice);
      await _load();
    } catch (_) {} finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _endDuty() async {
    setState(() => _actionBusy = true);
    try {
      await ApiClient.endDuty();
      _ticker?.cancel();
      await _load();
    } catch (_) {} finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    setState(() => _actionBusy = true);
    try {
      await ApiClient.updateDutyStatus(newStatus);
      setState(() => _status = newStatus);
    } catch (_) {} finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────────
  String _fmt(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _statusColor {
    switch (_status) {
      case 'driving':  return const Color(0xFF22C55E);
      case 'on_duty':  return const Color(0xFF3B82F6);
      case 'sleeper':  return const Color(0xFF8B5CF6);
      default:         return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case 'driving':  return 'Driving';
      case 'on_duty':  return 'On Duty';
      case 'sleeper':  return 'Sleeper';
      default:         return 'Off Duty';
    }
  }

  // ── build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _CardShell(child: Center(
        child: Padding(padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2))));
    }

    return _CardShell(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: (_isActive ? _statusColor : Colors.grey).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.timer_rounded, size: 18,
                color: _isActive ? _statusColor : Colors.grey)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Duty Timer',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A))),
            if (_isActive)
              Row(children: [
                Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(color: _statusColor,
                        shape: BoxShape.circle)),
                Text(_statusLabel,
                    style: GoogleFonts.inter(fontSize: 11, color: _statusColor,
                        fontWeight: FontWeight.w600)),
              ])
            else
              Text('Not on duty',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
          ]),
          const Spacer(),
          // Status chip selector (only when active)
          if (_isActive) _StatusChips(current: _status, onSelect: _changeStatus),
        ]),

        const SizedBox(height: 16),

        // ── Big Timer ────────────────────────────────────────────────────────
        Center(child: Column(children: [
          Text(_fmt(_elapsedSecs),
            style: GoogleFonts.inter(
              fontSize: 38, fontWeight: FontWeight.w800,
              color: _isActive ? _statusColor : const Color(0xFF94A3B8),
              letterSpacing: -1)),
          Text('Elapsed time',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
        ])),

        const SizedBox(height: 16),

        // ── HOS Bars ─────────────────────────────────────────────────────────
        _HosBar(label: 'Driving', used: _drivingSecs, limit: _drivingLimit,
            color: const Color(0xFF22C55E)),
        const SizedBox(height: 8),
        _HosBar(label: 'On Duty', used: _onDutySecs, limit: _onDutyLimit,
            color: const Color(0xFF3B82F6)),

        const SizedBox(height: 16),

        // ── Action Buttons ───────────────────────────────────────────────────
        if (_isActive)
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _actionBusy ? null : _endDuty,
              icon: _actionBusy
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text('End Duty',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ))
        else
          Row(children: [
            Expanded(child: _StartBtn(
              label: 'Start Driving', icon: Icons.directions_car_rounded,
              color: const Color(0xFF22C55E),
              onTap: _actionBusy ? null : () => _startDuty('driving'),
              busy: _actionBusy,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StartBtn(
              label: 'On Duty', icon: Icons.work_rounded,
              color: const Color(0xFF3B82F6),
              onTap: _actionBusy ? null : () => _startDuty('on_duty'),
              busy: _actionBusy,
            )),
          ]),
      ],
    ));
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: child,
  );
}

class _HosBar extends StatelessWidget {
  final String label;
  final int used, limit;
  final Color color;
  const _HosBar({required this.label, required this.used,
      required this.limit, required this.color});

  String _hm(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (used / limit).clamp(0.0, 1.0);
    final remaining = (limit - used).clamp(0, limit);
    final warn = pct > 0.8;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11,
            fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
        Text('${_hm(remaining)} left',
            style: GoogleFonts.inter(fontSize: 11,
                color: warn ? Colors.orange : const Color(0xFF94A3B8))),
      ]),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct, minHeight: 6,
          backgroundColor: const Color(0xFFF1F5F9),
          valueColor: AlwaysStoppedAnimation(warn ? Colors.orange : color),
        )),
    ]);
  }
}

class _StatusChips extends StatelessWidget {
  final String current;
  final void Function(String) onSelect;
  const _StatusChips({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const opts = [
      ('driving', Icons.directions_car_rounded, Color(0xFF22C55E)),
      ('on_duty', Icons.work_rounded,           Color(0xFF3B82F6)),
      ('sleeper', Icons.hotel_rounded,           Color(0xFF8B5CF6)),
    ];
    return Row(mainAxisSize: MainAxisSize.min, children: opts.map((o) {
      final sel = o.$1 == current;
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: GestureDetector(
          onTap: () => onSelect(o.$1),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: sel ? o.$3.withOpacity(0.12) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: sel ? o.$3 : const Color(0xFFE2E8F0)),
            ),
            child: Icon(o.$2, size: 15,
                color: sel ? o.$3 : const Color(0xFF94A3B8)),
          ),
        ),
      );
    }).toList());
  }
}

class _StartBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool busy;
  const _StartBtn({required this.label, required this.icon,
      required this.color, required this.onTap, required this.busy});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: busy
          ? Center(child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color)))
          : Column(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ]),
    ),
  );
}
