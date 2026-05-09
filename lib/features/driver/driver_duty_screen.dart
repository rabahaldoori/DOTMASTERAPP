import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_client.dart';

// FMCSA limits (seconds)
const _kDrivingLimit  = 11 * 3600;
const _kOnDutyWindow  = 14 * 3600;
const _kBreakAfter    = 8  * 3600;
const _kOffReset      = 10 * 3600;
const _kWeeklyLimit   = 60 * 3600;

const _navy   = Color(0xFF031634);
const _navy2  = Color(0xFF0A2347);
const _blue   = Color(0xFF0453CD);
const _green  = Color(0xFF22C55E);
const _orange = Color(0xFFF97316);
const _red    = Color(0xFFDC2626);
const _purple = Color(0xFF8B5CF6);
const _surface = Color(0xFFF0F3FF);

class DriverDutyScreen extends StatefulWidget {
  const DriverDutyScreen({super.key});
  @override
  State<DriverDutyScreen> createState() => _DriverDutyScreenState();
}

class _DriverDutyScreenState extends State<DriverDutyScreen> {
  bool   _loading     = true;
  bool   _actionBusy  = false;
  bool   _isActive    = false;
  String _status      = 'off_duty';
  int    _elapsedSecs = 0;

  // HOS data from backend
  int  _drivingSecs       = 0;
  int  _onDutySecs        = 0;
  int  _consecutiveDrive  = 0;
  int  _breakRemaining    = _kBreakAfter;
  bool _breakNeeded       = false;
  int  _shiftElapsed      = 0;
  int  _weeklyOn          = 0;
  int  _offSince          = 0;
  List _alerts            = [];
  List<Map> _history      = [];

  Timer? _ticker;

  @override void initState() { super.initState(); _load(); }
  @override void dispose()   { _ticker?.cancel(); super.dispose(); }

  // ── data ─────────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res  = await ApiClient.getDutyStatus();
      final data = res.data as Map<String, dynamic>;
      final sess = data['active_session'];
      final hos  = data['hos'] as Map<String, dynamic>;

      _drivingSecs      = (hos['driving_seconds']        as num).toInt();
      _onDutySecs       = (hos['on_duty_seconds']         as num).toInt();
      _consecutiveDrive = (hos['consecutive_drive_secs']  as num).toInt();
      _breakRemaining   = (hos['break_remaining_secs']    as num).toInt();
      _breakNeeded      = hos['break_needed']             as bool? ?? false;
      _shiftElapsed     = (hos['shift_elapsed_secs']      as num).toInt();
      _weeklyOn         = (hos['weekly_on_duty_secs']     as num).toInt();
      _offSince         = (hos['off_since_secs']          as num? ?? 0).toInt();
      _alerts           = (hos['alerts']                  as List?) ?? [];

      if (sess != null && (sess['is_active'] as bool? ?? false)) {
        _isActive    = true;
        _status      = sess['status'] as String? ?? 'on_duty';
        _elapsedSecs = (sess['duration_seconds'] as num).toInt();
        _startTicker();
      } else {
        _isActive = false; _elapsedSecs = 0; _ticker?.cancel();
      }

      final hist = await ApiClient.getDutyHistory(days: 7);
      _history = List<Map>.from(hist.data ?? []);
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
        if (_status == 'driving') {
          _drivingSecs++;
          _consecutiveDrive++;
          if (_breakRemaining > 0) _breakRemaining--;
          if (_consecutiveDrive >= _kBreakAfter) _breakNeeded = true;
        }
        if (_status == 'driving' || _status == 'on_duty') {
          _onDutySecs++;
          _shiftElapsed++;
          _weeklyOn++;
        }
        if (_status == 'off_duty' || _status == 'sleeper') {
          _offSince++;
        }
      });
    });
  }

  Future<void> _setStatus(String s) async {
    setState(() => _actionBusy = true);
    try {
      if (_isActive) {
        await ApiClient.updateDutyStatus(s);
      } else {
        await ApiClient.startDuty(s);
      }
      await _load();
    } catch (_) {} finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _endDuty() async {
    setState(() => _actionBusy = true);
    try { await ApiClient.endDuty(); _ticker?.cancel(); await _load(); }
    catch (_) {} finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────────
  String _fmt(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60; final sec = s % 60;
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';
  }
  String _hm(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  Color get _statusColor => switch (_status) {
    'driving' => _green, 'on_duty' => _blue,
    'sleeper' => _purple, _ => Colors.grey };


  String get _statusLabel => switch (_status) {
    'driving' => 'Driving', 'on_duty' => 'On Duty',
    'sleeper' => 'Sleeper Berth', _ => 'Off Duty' };

  // ── build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: RefreshIndicator(
        onRefresh: _load, color: _blue,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _header()),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
              sliver: SliverList(delegate: SliverChildListDelegate([
                if (_alerts.isNotEmpty) ...[
                  ..._alerts.map((a) => _AlertBanner(alert: a)),
                  const SizedBox(height: 12),
                ],
                _statusButtons(),
                const SizedBox(height: 14),
                _hosCard(),
                const SizedBox(height: 14),
                _breakCard(),
                const SizedBox(height: 14),
                _weeklyCard(),
                const SizedBox(height: 14),
                _historyCard(),
              ])),
            ),
        ]),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _header() => Container(
    decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_navy, _navy2])),
    child: SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24)),
              child: const Icon(Icons.timer_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Duty Time', style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('FMCSA Hours of Service', style: GoogleFonts.inter(
                fontSize: 10, color: Colors.white38)),
          ]),
          const Spacer(),
          _StatusBadge(label: _isActive ? _statusLabel : 'Off Duty',
              color: _isActive ? _statusColor : Colors.white38),
        ]),
        const SizedBox(height: 18),
        Center(child: Text(_fmt(_elapsedSecs),
            style: GoogleFonts.inter(fontSize: 50, fontWeight: FontWeight.w900,
                color: _isActive ? _statusColor : Colors.white24, letterSpacing: -2))),
        Center(child: Text(_isActive ? 'Current session' : 'No active session',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38))),
        if (!_isActive && _offSince > 0) ...[
          const SizedBox(height: 6),
          Center(child: Text('Off duty: ${_hm(_offSince)}',
              style: GoogleFonts.inter(fontSize: 11,
                  color: _offSince >= _kOffReset ? _green : Colors.white38))),
        ],
      ]),
    )),
  );

  // ── Status Buttons ────────────────────────────────────────────────────────────
  Widget _statusButtons() => _Card(
    title: 'Change Status',
    icon: Icons.swap_horiz_rounded,
    child: Column(children: [
      // Row 1 — active statuses
      Row(children: [
        _StatusBtn('Driving',     'driving',  Icons.directions_car_rounded, _green),
        const SizedBox(width: 8),
        _StatusBtn('On Duty',     'on_duty',  Icons.work_rounded,           _blue),
      ]),
      const SizedBox(height: 8),
      // Row 2 — rest statuses
      Row(children: [
        _StatusBtn('30-Min Break','off_duty', Icons.free_breakfast_rounded,  _orange,
            subtitle: 'Required at 8h drive'),
        const SizedBox(width: 8),
        _StatusBtn('Sleeper Rest','sleeper',  Icons.hotel_rounded,           _purple,
            subtitle: '10h for full reset'),
      ]),
      if (_isActive) ...[
        const SizedBox(height: 10),
        SizedBox(width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _actionBusy ? null : _endDuty,
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: Text('End Duty Session',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _red, side: const BorderSide(color: _red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12)),
          )),
      ],
    ]),
  );

  Widget _StatusBtn(String label, String val, IconData icon, Color col,
      {String? subtitle}) {
    final sel  = _status == val && _isActive;
    final busy = _actionBusy;
    return Expanded(child: GestureDetector(
      onTap: busy ? null : () => _setStatus(val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: sel ? col.withOpacity(0.10) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? col : const Color(0xFFE2E8F0),
              width: sel ? 1.5 : 1),
        ),
        child: Column(children: [
          Icon(icon, size: 22, color: sel ? col : const Color(0xFF94A3B8)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 11,
              fontWeight: FontWeight.w700,
              color: sel ? col : const Color(0xFF64748B))),
          if (subtitle != null)
            Text(subtitle, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey),
                textAlign: TextAlign.center),
        ]),
      ),
    ));
  }

  // ── HOS Card ──────────────────────────────────────────────────────────────────
  Widget _hosCard() => _Card(
    title: 'Daily HOS',
    icon: Icons.access_time_rounded,
    child: Column(children: [
      _HosBar('Driving', _drivingSecs, _kDrivingLimit, _green, '11h FMCSA limit'),
      const SizedBox(height: 12),
      _HosBar('On-Duty Window', _shiftElapsed, _kOnDutyWindow, _blue, '14h window'),
    ]),
  );

  // ── Break Card ────────────────────────────────────────────────────────────────
  Widget _breakCard() {
    final pct = (_consecutiveDrive / _kBreakAfter).clamp(0.0, 1.0);
    final col = _breakNeeded ? _red : (_consecutiveDrive >= _kBreakAfter - 1800 ? _orange : _green);
    return _Card(
      title: '30-Min Break Tracker',
      icon: Icons.coffee_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Consecutive driving', style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
          Text(_breakNeeded ? '⛔ STOP NOW' : '${_hm(_breakRemaining)} until break',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: col)),
        ]),
        const SizedBox(height: 8),
        Stack(children: [
          Container(height: 12, decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6))),
          FractionallySizedBox(widthFactor: pct, child: Container(height: 12,
              decoration: BoxDecoration(color: col,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(color: col.withOpacity(0.30),
                      blurRadius: 4, offset: const Offset(0,2))]))),
        ]),
        const SizedBox(height: 6),
        Text('${_hm(_consecutiveDrive)} driven / 8h limit  •  FMCSA 49 CFR §395.3(a)(3)(ii)',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
        if (_breakNeeded) ...[
          const SizedBox(height: 10),
          Container(width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _red.withOpacity(0.3))),
            child: Text('Take a 30-minute off-duty or sleeper berth break now.',
                style: GoogleFonts.inter(fontSize: 12, color: _red, fontWeight: FontWeight.w600))),
        ],
      ]),
    );
  }

  // ── Weekly Card ───────────────────────────────────────────────────────────────
  Widget _weeklyCard() {
    final offReady = _offSince >= _kOffReset;
    return _Card(
      title: 'Weekly & Reset',
      icon: Icons.calendar_today_rounded,
      child: Column(children: [
        _HosBar('60-Hr/7-Day', _weeklyOn, _kWeeklyLimit, _orange, 'FMCSA weekly limit'),
        const SizedBox(height: 14),
        Row(children: [
          _MiniStat('10h Reset', offReady ? '✅ Ready' : _hm(_offSince),
              offReady ? _green : Colors.grey, 'Off-duty clock'),
          _MiniStat('34h Restart', _offSince >= 34 * 3600 ? '✅ Done' : _hm(_offSince),
              _offSince >= 34 * 3600 ? _green : Colors.grey, 'Weekly restart'),
        ]),
      ]),
    );
  }

  Widget _MiniStat(String title, String val, Color col, String sub) =>
      Expanded(child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: col.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: col.withOpacity(0.2))),
        child: Column(children: [
          Text(val, style: GoogleFonts.inter(fontSize: 14,
              fontWeight: FontWeight.w800, color: col)),
          Text(title, style: GoogleFonts.inter(fontSize: 10,
              fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
          Text(sub, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
        ]),
      ));

  // ── History Card ──────────────────────────────────────────────────────────────
  Widget _historyCard() => _Card(
    title: 'Session History (7 days)',
    icon: Icons.history_rounded,
    child: _history.isEmpty
        ? Center(child: Padding(padding: const EdgeInsets.all(16),
            child: Text('No sessions yet', style: GoogleFonts.inter(color: Colors.grey))))
        : Column(children: _history.take(12).map((l) => _HistoryRow(log: l)).toList()),
  );

  // ── Bottom Bar ────────────────────────────────────────────────────────────────
  Widget _bottomBar() => SafeArea(child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
    child: _isActive ? null : Row(children: [
      Expanded(child: _BigBtn('Start Driving', Icons.directions_car_rounded,
          _green, () => _setStatus('driving'))),
      const SizedBox(width: 10),
      Expanded(child: _BigBtn('On Duty', Icons.work_rounded,
          _blue, () => _setStatus('on_duty'))),
    ]),
  ));

  Widget _BigBtn(String label, IconData icon, Color col, VoidCallback onTap) =>
      SizedBox(height: 52, child: ElevatedButton.icon(
        onPressed: _actionBusy ? null : onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(backgroundColor: col, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ));
}

// ── Reusable sub-widgets ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title; final IconData icon; final Widget child;
  const _Card({required this.title, required this.icon, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 12, offset: const Offset(0,4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: _blue),
        const SizedBox(width: 6),
        Text(title, style: GoogleFonts.inter(fontSize: 13,
            fontWeight: FontWeight.w700, color: _navy)),
      ]),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

class _AlertBanner extends StatelessWidget {
  final dynamic alert;
  const _AlertBanner({required this.alert});
  @override
  Widget build(BuildContext context) {
    final level   = alert['level'] as String? ?? 'info';
    final rule    = alert['rule']  as String? ?? '';
    final message = alert['message'] as String? ?? '';
    final isDanger = level == 'danger';
    final col  = isDanger ? _red : _orange;
    final icon = isDanger ? Icons.error_rounded : Icons.warning_amber_rounded;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: col.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: col.withOpacity(0.35))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: col, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rule, style: GoogleFonts.inter(fontSize: 12,
              fontWeight: FontWeight.w800, color: col)),
          const SizedBox(height: 2),
          Text(message, style: GoogleFonts.inter(fontSize: 11,
              color: col.withOpacity(0.85))),
        ])),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label; final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4))),
    child: Text(label, style: GoogleFonts.inter(fontSize: 11,
        fontWeight: FontWeight.w700, color: color)),
  );
}

class _HosBar extends StatelessWidget {
  final String label, sub; final int used, limit; final Color color;
  const _HosBar(this.label, this.used, this.limit, this.color, this.sub);
  String _hm(int s) { final h = s ~/ 3600; final m = (s % 3600) ~/ 60; return '${h}h ${m}m'; }
  @override
  Widget build(BuildContext context) {
    final pct  = (used / limit).clamp(0.0, 1.0);
    final rem  = (limit - used).clamp(0, limit);
    final warn = pct > 0.80;
    final col  = warn ? _orange : color;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12,
              fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
          const SizedBox(width: 4),
          Text(sub, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
        ]),
        Text('${_hm(rem)} left', style: GoogleFonts.inter(fontSize: 11,
            fontWeight: FontWeight.w700, color: col)),
      ]),
      const SizedBox(height: 6),
      Stack(children: [
        Container(height: 10, decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(5))),
        FractionallySizedBox(widthFactor: pct, child: Container(height: 10,
            decoration: BoxDecoration(color: col,
                borderRadius: BorderRadius.circular(5),
                boxShadow: [BoxShadow(color: col.withOpacity(0.30),
                    blurRadius: 3, offset: const Offset(0,1))]))),
      ]),
      const SizedBox(height: 3),
      Text('${_hm(used)} used of ${_hm(limit)}',
          style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
    ]);
  }
}

class _HistoryRow extends StatelessWidget {
  final Map log;
  const _HistoryRow({required this.log});
  Color _col(String s) => switch(s) {
    'driving' => _green, 'on_duty' => _blue,
    'sleeper' => _purple, _ => Colors.grey };
  String _lbl(String s) => switch(s) {
    'driving' => 'Driving', 'on_duty' => 'On Duty',
    'sleeper' => 'Sleeper', _ => 'Off Duty' };
  String _dur(int s) { final h = s ~/ 3600; final m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m'; }
  String _date(String? iso) {
    if (iso == null) return '';
    try { final d = DateTime.parse(iso).toLocal();
      return '${d.month}/${d.day} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }
  @override
  Widget build(BuildContext context) {
    final s    = log['status'] as String? ?? 'off_duty';
    final secs = (log['duration_seconds'] as num?)?.toInt() ?? 0;
    final col  = _col(s);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(_lbl(s), style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)))),
        Text(_date(log['start_time'] as String?),
            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
        const SizedBox(width: 10),
        Text(_dur(secs), style: GoogleFonts.inter(fontSize: 13,
            fontWeight: FontWeight.w700, color: col)),
      ]));
  }
}
