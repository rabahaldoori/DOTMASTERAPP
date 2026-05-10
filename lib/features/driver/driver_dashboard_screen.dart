import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'trip_detail_sheet.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});
  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _userName    = '';
  String _companyName = 'IFTATrack';
  String? _userPhoto;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Load cached user name first for instant display
    final user = await ApiClient.getUser();
    setState(() => _userName = user['name'] ?? 'Driver');

    setState(() { _loading = true; });
    try {
      final res = await ApiClient.getDriverData();
      final d = res.data as Map<String, dynamic>;
      final profile = d['profile'] as Map<String, dynamic>?;
      final trips   = List<Map>.from(d['trips'] ?? []);
      final fuel    = List<Map>.from(d['fuel_logs'] ?? []);
      final docs    = List<Map>.from(d['documents'] ?? []);

      // Find active trip
      final activeTrip = trips.cast<Map?>().firstWhere(
        (t) => t!['status'] == 'active' || t['status'] == 'in_progress',
        orElse: () => null,
      );

      // Stats
      double totalMiles = 0, totalFuel = 0;
      for (final t in trips) totalMiles += (t['total_miles'] as num?)?.toDouble() ?? 0;
      for (final f in fuel)  totalFuel  += (f['total_cost'] as num?)?.toDouble() ?? 0;

      // CDL expiry days
      int cdlDaysLeft = 999;
      final cdlStr = profile?['cdl_expiry'] as String?;
      if (cdlStr != null) {
        try { cdlDaysLeft = DateTime.parse(cdlStr).difference(DateTime.now()).inDays; } catch (_) {}
      }

      // Fetch HOS/duty alerts (non-blocking — fail silently)
      List hosAlerts = [];
      bool breakNeeded = false;
      try {
        final dutyRes = await ApiClient.getDutyStatus();
        final hos = dutyRes.data?['hos'] as Map<String, dynamic>?;
        if (hos != null) {
          hosAlerts   = (hos['alerts'] as List?) ?? [];
          breakNeeded = hos['break_needed'] as bool? ?? false;
        }
      } catch (_) {}

      setState(() {
        _userName    = '${profile?['full_name'] ?? user['name'] ?? 'Driver'}';
        _companyName = profile?['company_name'] as String?
            ?? _data?['company']?['name'] as String?
            ?? 'IFTATrack';
        _userPhoto   = profile?['photo'] as String?;
        _data = {
          'profile':    profile,
          'trips':      trips,
          'fuel':       fuel,
          'docs':       docs,
          'activeTrip': activeTrip,
          'totalMiles': totalMiles,
          'totalFuel':  totalFuel,
          'cdlDaysLeft': cdlDaysLeft,
          'tripCount':  trips.length,
          'hosAlerts':  hosAlerts,
          'breakNeeded': breakNeeded,
        };
      });
    } catch (_) {} finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3FF),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        child: CustomScrollView(
          slivers: [
            // ── Pinned SliverAppBar ──────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 272,
              pinned: true,
              backgroundColor: const Color(0xFF031634),
              systemOverlayStyle: SystemUiOverlayStyle.light,
              automaticallyImplyLeading: false,
              titleSpacing: 16,
              elevation: 0,
              // ── Collapsed bar: logo + company + bell + avatar ──────────
              title: Row(children: [
                Image.asset('assets/images/logo.png',
                    width: 50, height: 50, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0453CD).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: Color(0xFF0453CD), size: 20))),
                const SizedBox(width: 8),
                Text('DOT Master', style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                const Spacer(),
                // Notification bell
                GestureDetector(
                  onTap: () => context.push('/driver-notifications'),
                  child: Stack(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.12))),
                      child: const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 18)),
                    Positioned(top: 7, right: 7,
                      child: Container(width: 7, height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF031634), width: 1.5)))),
                  ]),
                ),
                const SizedBox(width: 10),
                // Avatar pill — same as admin
                Builder(builder: (ctx) {
                  final initials = _userName.split(' ')
                      .where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
                  return Stack(children: [
                    CircleAvatar(
                      radius: 17, backgroundColor: const Color(0xFF0453CD),
                      backgroundImage: _userPhoto != null ? NetworkImage(_userPhoto!) : null,
                      child: _userPhoto == null
                          ? Text(initials, style: GoogleFonts.inter(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))
                          : null,
                    ),
                    Positioned(bottom: 0, right: 0,
                      child: Container(width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E), shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF031634), width: 1.5)))),
                  ]);
                }),
              ]),
              // ── Expanded hero ─────────────────────────────────────────────
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Builder(builder: (ctx) {
                  final hasTrip   = _data?['activeTrip'] != null;
                  final cdlDays   = _data?['cdlDaysLeft'] as int? ?? 999;
                  final compliant = cdlDays > 90;
                  final initials  = _userName.split(' ')
                      .where((w) => w.isNotEmpty)
                      .map((w) => w[0])
                      .take(2).join().toUpperCase();
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF031634), Color(0xFF0A2347), Color(0xFF0453CD)],
                        stops: [0.0, 0.55, 1.0],
                      ),
                    ),
                    child: Stack(children: [
                      // Decorative circles
                      Positioned(right: -40, top: -40, child: Container(
                        width: 180, height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04)))),
                      Positioned(right: 60, top: 80, child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0453CD).withOpacity(0.20)))),
                      Positioned(left: -20, bottom: 40, child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.03)))),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 4, 20, 0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Greeting row (matches admin layout) ─────
                              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Good ${_greeting()}', style: GoogleFonts.inter(
                                        fontSize: 11, fontWeight: FontWeight.w500,
                                        color: Colors.white54, letterSpacing: 0.3)),
                                    const SizedBox(height: 2),
                                    Text(_userName.isNotEmpty ? _userName.toUpperCase() : 'DRIVER',
                                        style: GoogleFonts.inter(
                                            fontSize: 18, fontWeight: FontWeight.w800,
                                            color: Colors.white, letterSpacing: -0.3)),
                                    const SizedBox(height: 2),
                                    Text(_companyName, style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF06B6D4).withOpacity(0.9),
                                        fontWeight: FontWeight.w600)),
                                  ],
                                )),
                                // Date badge — same as admin
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withOpacity(0.15))),
                                  child: Text(
                                    _dateLabel(),
                                    style: GoogleFonts.inter(
                                        fontSize: 11, fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              // ── Glassy stats strip ───────────────────────
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                                ),
                                child: IntrinsicHeight(
                                  child: Row(children: [
                                    _HeroStat(
                                        value: '${_data?["tripCount"] ?? 0}',
                                        label: 'Trips',
                                        icon: Icons.route_rounded,
                                        color: const Color(0xFF06B6D4)),
                                    VerticalDivider(width: 1,
                                        color: Colors.white.withOpacity(0.12)),
                                    _HeroStat(
                                        value: compliant ? 'OK' : '⚠',
                                        label: 'CDL Status',
                                        icon: Icons.verified_rounded,
                                        color: compliant
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFFF97316)),
                                    VerticalDivider(width: 1,
                                        color: Colors.white.withOpacity(0.12)),
                                    _HeroStat(
                                        value: '${(_data?["totalMiles"] as double? ?? 0).toStringAsFixed(0)}',
                                        label: 'Miles',
                                        icon: Icons.speed_rounded,
                                        color: const Color(0xFFF97316)),
                                  ]),
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  );
                }),
              ),
            ),

            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  // ── Row: Compliance gauge + Vehicle card ───────────────
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _ComplianceGaugeCard(data: _data)),
                      const SizedBox(width: 12),
                      Expanded(child: _VehicleCard(activeTrip: _data?['activeTrip'])),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Route Status card ──────────────────────────────────
                  GestureDetector(
                    onTap: _data?['activeTrip'] != null
                        ? () => showTripDetail(context, _data!['activeTrip'] as Map)
                        : null,
                    child: _RouteStatusCard(
                      activeTrip:  _data?['activeTrip'],
                      hosAlerts:   (_data?['hosAlerts'] as List?) ?? [],
                      breakNeeded: _data?['breakNeeded'] as bool? ?? false,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Quick Actions ─────────────────────────────────────
                  Text('QUICK ACTIONS',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant, letterSpacing: 0.8)),

                  const SizedBox(height: 12),
                  _QuickActions(
                      onTripsTap: () => context.go('/driver-trips'),
                      onFuelTap: () => context.go('/driver-fuel'),
                      onProfileTap: () => context.go('/driver-profile'),
                      onInspectTap: () => context.push('/driver-inspection'),
                      onHistoryTap: () => context.push('/driver-inspection/history')),
                  const SizedBox(height: 24),



                  // ── Recent Trips ──────────────────────────────────────
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Recent Trips',
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700,
                            color: AppColors.onSurface)),
                    TextButton(
                      onPressed: () => context.go('/driver-trips'),
                      child: Text('See All', style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _RecentTrips(
                    trips: ((_data?['trips'] as List?) ?? []).take(3).toList(),
                    onTap: (t) => showTripDetail(context, t),
                  ),
                  const SizedBox(height: 24),

                  // ── Recent Fuel Logs ──────────────────────────────────
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Recent Fuel Logs',
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700,
                            color: AppColors.onSurface)),
                    TextButton(
                      onPressed: () => context.go('/driver-fuel'),
                      child: Text('See All', style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _RecentFuel(fuel: ((_data?['fuel'] as List?) ?? []).take(2).toList()),
                  const SizedBox(height: 100),
                ])),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  String _firstName() => _userName.split(' ').first;

  String _dateLabel() {
    final now = DateTime.now();
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['','Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[now.weekday - 1]}, ${months[now.month]} ${now.day}';
  }

  String _subGreeting() {
    final activeTrip = _data?['activeTrip'] as Map?;
    if (activeTrip != null) {
      final dest = [activeTrip['destination_city'], activeTrip['destination_state']]
          .where((s) => s != null && (s as String).isNotEmpty)
          .join(', ');
      if (dest.isNotEmpty) return 'Stay safe on your way to $dest.';
    }
    return 'Stay safe on the road today.';
  }
}

// ── Hero stat widget ───────────────────────────────────────────────────────────
class _HeroStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _HeroStat({
    required this.value,
    required this.label,
    required this.icon,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(height: 5),
      Text(value, style: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
      const SizedBox(height: 1),
      Text(label, style: GoogleFonts.inter(
          fontSize: 9, color: Colors.white38, letterSpacing: 0.2)),
    ]),
  );
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: Colors.white12,
  );
}


// ── Compliance Gauge Card ─────────────────────────────────────────────────────
class _ComplianceGaugeCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _ComplianceGaugeCard({this.data});

  @override
  Widget build(BuildContext context) {
    final cdlDays = data?['cdlDaysLeft'] as int? ?? 999;
    final pct     = (cdlDays >= 365) ? 0.94 : math.max(0.0, cdlDays / 365.0);
    final label   = cdlDays > 90 ? 'Compliant' : cdlDays > 0 ? 'Expiring' : 'Expired';
    final arcColor = cdlDays > 90 ? const Color(0xFF0453CD) : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Compliance', style: GoogleFonts.inter(fontSize: 14,
              fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          const SizedBox(height: 16),
          // Custom arc — text is never inside the painter so no overlap
          SizedBox(
            width: 88, height: 88,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                size: const Size(88, 88),
                painter: _ArcPainter(pct, arcColor),
              ),
              Text('${(pct * 100).round()}%',
                  style: GoogleFonts.inter(fontSize: 16,
                      fontWeight: FontWeight.w700, color: AppColors.primary)),
            ]),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: arcColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: arcColor.withOpacity(0.15)),
            ),
            child: Text(label, style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w500, color: arcColor)),
          ),
        ],
      ),
    );
  }
}

// ── Vehicle / Active Trip Card ────────────────────────────────────────────────
class _VehicleCard extends StatelessWidget {
  final Map? activeTrip;
  const _VehicleCard({this.activeTrip});

  @override
  Widget build(BuildContext context) {
    final truck = activeTrip?['truck__unit_number'] as String?
        ?? activeTrip?['truck'] as String?
        ?? '—';
    final hasTrip = activeTrip != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Current Vehicle',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white54,
                  letterSpacing: 0.2)),
          const SizedBox(height: 8),
          Text(hasTrip ? truck : 'No Vehicle',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: -0.3)),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.local_shipping_outlined, size: 15, color: Colors.white54),
            const SizedBox(width: 6),
            Text(hasTrip ? 'Active' : 'Standby',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white60)),
          ]),
        ],
      ),
    );
  }
}

// ── Route Status Card ─────────────────────────────────────────────────────────
class _RouteStatusCard extends StatelessWidget {
  final Map?  activeTrip;
  final List  hosAlerts;
  final bool  breakNeeded;
  const _RouteStatusCard({
    this.activeTrip,
    this.hosAlerts  = const [],
    this.breakNeeded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (activeTrip == null) return _emptyState();

    String _loc(Map trip, List<String> cityKeys, List<String> stateKeys, String? addressKey) {
      final city  = cityKeys.map((k) => trip[k] as String? ?? '').firstWhere((s) => s.isNotEmpty, orElse: () => '');
      final state = stateKeys.map((k) => trip[k] as String? ?? '').firstWhere((s) => s.isNotEmpty, orElse: () => '');
      final combined = [city, state].where((s) => s.isNotEmpty).join(', ');
      if (combined.isNotEmpty) return combined;
      if (addressKey != null) return trip[addressKey] as String? ?? '';
      return '';
    }

    final from = _loc(activeTrip!, ['origin_city','origin'],
        ['origin_state','origin_st'], 'origin_address');
    final to   = _loc(activeTrip!, ['destination_city','destination'],
        ['destination_state','destination_st'], 'destination_address');

    final totalMi   = (activeTrip!['total_miles']  as num?)?.toDouble() ?? 0;
    final drivenMi  = (activeTrip!['miles_driven'] as num?)?.toDouble() ?? 0;
    final remaining = math.max(0.0, totalMi - drivenMi);
    final progress  = totalMi > 0 ? math.min(1.0, drivenMi / totalMi) : 0.0;
    final pct       = (progress * 100).round();
    final startDate = _fmtTime(activeTrip!['start_date']);
    final endDate   = _fmtTime(activeTrip!['end_date']);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0453CD).withOpacity(0.18),
              blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: [
          // ── Dark gradient top section ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF031634), Color(0xFF0A2347)],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Label + live badge
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6,
                        decoration: const BoxDecoration(
                            color: Color(0xFF22C55E), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('LIVE ROUTE', style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: Colors.white70, letterSpacing: 0.8)),
                  ]),
                ),
                const SizedBox(width: 8),
                Row(children: [
                  const Icon(Icons.touch_app_rounded, size: 10, color: Colors.white30),
                  const SizedBox(width: 3),
                  Text('Tap for details', style: GoogleFonts.inter(
                      fontSize: 9, color: Colors.white30)),
                ]),
                const Spacer(),
                // Miles remaining pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0453CD).withOpacity(0.30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF0453CD).withOpacity(0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(remaining.toStringAsFixed(0),
                        style: GoogleFonts.inter(fontSize: 20,
                            fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(width: 4),
                    Text('mi left', style: GoogleFonts.inter(fontSize: 10,
                        fontWeight: FontWeight.w600, color: Colors.white60)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              // From → To
              Row(children: [
                // Origin
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('FROM', style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: Colors.white38, letterSpacing: 0.8)),
                  const SizedBox(height: 3),
                  Text(from.isNotEmpty ? from : '—',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                          color: Colors.white),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                ])),
                // Arrow connector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(children: [
                    Container(width: 28, height: 1, color: Colors.white24),
                    const SizedBox(height: 3),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 14),
                    const SizedBox(height: 3),
                    Container(width: 28, height: 1, color: Colors.white24),
                  ]),
                ),
                // Destination
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('TO', style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: Colors.white38, letterSpacing: 0.8)),
                  const SizedBox(height: 3),
                  Text(to.isNotEmpty ? to : '—',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                          color: Colors.white),
                      maxLines: 3, overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right),
                ])),
              ]),
              const SizedBox(height: 20),
              // Progress bar with glow
              Stack(children: [
                Container(height: 6,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(3))),
                FractionallySizedBox(
                  widthFactor: progress > 0 ? progress : 0.04,
                  child: Container(height: 6,
                      decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.7),
                              blurRadius: 8, spreadRadius: 1)])),
                ),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('$pct% completed', style: GoogleFonts.inter(
                    fontSize: 10, color: Colors.white38)),
                Text('${drivenMi.toStringAsFixed(0)} / ${totalMi.toStringAsFixed(0)} mi',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white38)),
              ]),
              // ── Break / Rest alert banners ─────────────────────────────
              if (hosAlerts.isNotEmpty) ..._buildAlertBanners(),
            ]),
          ),
          // ── Light stats bottom section ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            color: Colors.white,
            child: Row(children: [
              _StatChip(Icons.play_circle_outline_rounded, 'Started',
                  startDate.isNotEmpty ? startDate : '—'),
              _divider(),
              _StatChip(Icons.flag_rounded, 'ETA',
                  endDate.isNotEmpty ? endDate : '—'),
              _divider(),
              _StatChip(Icons.local_shipping_outlined, 'Miles',
                  totalMi > 0 ? '${totalMi.toStringAsFixed(0)} mi' : '—'),
            ]),
          ),
        ]),
      ),
    );
  }

  /// Build compact alert banners shown inside the dark route card header.
  List<Widget> _buildAlertBanners() {
    // Show at most 2 most-important alerts (danger first)
    final sorted = [...hosAlerts]..sort((a, b) {
      final order = {'danger': 0, 'warning': 1};
      return (order[a['level']] ?? 2).compareTo(order[b['level']] ?? 2);
    });
    return [
      const SizedBox(height: 10),
      ...sorted.take(2).map((a) {
        final isDanger = a['level'] == 'danger';
        final col      = isDanger ? const Color(0xFFDC2626) : const Color(0xFFF97316);
        final icon     = isDanger ? Icons.error_rounded : Icons.warning_amber_rounded;
        final rule     = a['rule']    as String? ?? '';
        final msg      = a['message'] as String? ?? '';
        return Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: col.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: col.withOpacity(0.45)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: col, size: 15),
            const SizedBox(width: 7),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rule, style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w800, color: col)),
              Text(msg, style: GoogleFonts.inter(
                  fontSize: 9, color: col.withOpacity(0.85)), maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ])),
          ]),
        );
      }),
    ];
  }

  Widget _divider() => Container(width: 1, height: 32,
      color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [const Color(0xFFF8FAFF), Colors.white]),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Row(children: [
      Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F3FF),
          borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.route_outlined,
            color: Color(0xFF0453CD), size: 22)),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('No Active Route', style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B))),
        Text('Your trip will appear here', style: GoogleFonts.inter(
            fontSize: 12, color: Colors.grey)),
      ]),
    ]),
  );

  String _fmtTime(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
      final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m  = dt.minute.toString().padLeft(2, '0');
      final ap = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ap';
    } catch (_) { return d.toString(); }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon; final String label, value;
  const _StatChip(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, size: 16, color: const Color(0xFF0453CD)),
    const SizedBox(height: 3),
    Text(value, style: GoogleFonts.inter(fontSize: 12,
        fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
    Text(label, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
  ]));
}


// ── Quick Actions ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final VoidCallback onTripsTap, onFuelTap, onProfileTap, onInspectTap, onHistoryTap;
  const _QuickActions({
    required this.onTripsTap, required this.onFuelTap,
    required this.onProfileTap, required this.onInspectTap,
    required this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _ActionBtn(
          icon: Icons.route_outlined, label: 'My Trips',
          primary: true, onTap: onTripsTap,
        )),
        const SizedBox(width: 10),
        Expanded(child: _ActionBtn(
          icon: Icons.local_gas_station_outlined, label: 'Log Fuel',
          primary: false, onTap: onFuelTap,
        )),
        const SizedBox(width: 10),
        Expanded(child: _ActionBtn(
          icon: Icons.person_outline_rounded, label: 'Profile',
          primary: false, onTap: onProfileTap,
        )),
      ]),
      const SizedBox(height: 10),
      // Inspection row: Start + History side by side
      Row(children: [
        Expanded(
          flex: 3,
          child: _ActionBtn(
            icon: Icons.fact_check_outlined, label: 'Start Inspection',
            primary: true, onTap: onInspectTap, fullWidth: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _ActionBtn(
            icon: Icons.history_rounded, label: 'History',
            primary: false, onTap: onHistoryTap, fullWidth: true,
          ),
        ),
      ]),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label;
  final bool primary; final bool fullWidth;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon, required this.label,
    required this.primary, required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        color: primary ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: primary ? null : Border.all(color: AppColors.outline.withOpacity(0.5)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 20, color: primary ? Colors.white : AppColors.onSurface),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: primary ? Colors.white : AppColors.onSurface)),
      ]),
    ),
  );
}

// ── Deadlines ─────────────────────────────────────────────────────────────────
class _DeadlinesList extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _DeadlinesList({this.data});

  @override
  Widget build(BuildContext context) {
    final cdlDays = data?['cdlDaysLeft'] as int? ?? 999;
    final profile = data?['profile'] as Map?;
    final cdlStr  = profile?['cdl_expiry'] as String?;

    final items = <Map<String, dynamic>>[
      if (cdlDays < 180) {
        'icon': Icons.badge_outlined,
        'color': Colors.red.shade50,
        'iconColor': Colors.red,
        'title': 'CDL Renewal',
        'sub': cdlDays > 0 ? 'Due in $cdlDays days' : 'Expired',
      },
      {
        'icon': Icons.description_outlined,
        'color': AppColors.infoBg,
        'iconColor': AppColors.accent,
        'title': 'Next IFTA Filing',
        'sub': _nextIftaDeadline(),
      },
    ];

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline.withOpacity(0.5)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 22),
          const SizedBox(width: 12),
          Text('No upcoming deadlines', style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.onSurfaceVariant)),
        ]),
      );
    }

    return Column(children: items.map((item) => _DeadlineRow(item: item)).toList());
  }

  String _nextIftaDeadline() {
    final now = DateTime.now();
    final q    = ((now.month - 1) ~/ 3) + 1;
    final year = q == 4 ? now.year + 1 : now.year;
    final month = (q % 4) * 3 + 1;
    final d    = DateTime(year, month, 31);
    final days = d.difference(now).inDays;
    return 'Due in $days days';
  }
}

class _DeadlineRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _DeadlineRow({required this.item});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.outline.withOpacity(0.5)),
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: item['color'] as Color,
            borderRadius: BorderRadius.circular(10)),
        child: Icon(item['icon'] as IconData, size: 20, color: item['iconColor'] as Color),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['title'] as String,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.onSurface)),
        Text(item['sub'] as String,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
      ])),
      const Icon(Icons.chevron_right, size: 18, color: AppColors.onSurfaceVariant),
    ]),
  );
}

// ── Recent Fuel ───────────────────────────────────────────────────────────────
// ── Recent Trips ─────────────────────────────────────────────────────────────
class _RecentTrips extends StatelessWidget {
  final List trips;
  final void Function(Map) onTap;
  const _RecentTrips({required this.trips, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline.withOpacity(0.5))),
        child: Center(child: Text('No trips yet.',
            style: GoogleFonts.inter(
                color: AppColors.onSurfaceVariant, fontSize: 14))),
      );
    }
    return Column(children: trips
        .map<Widget>((t) => _TripRow(trip: t as Map, onTap: () => onTap(t)))
        .toList());
  }
}

class _TripRow extends StatelessWidget {
  final Map trip;
  final VoidCallback onTap;
  const _TripRow({required this.trip, required this.onTap});

  static const _statusColors = {
    'pending':    Color(0xFFF97316),
    'assigned':   Color(0xFF0453CD),
    'in_transit': Color(0xFF0891B2),
    'completed':  Color(0xFF16A34A),
    'cancelled':  Color(0xFFEF4444),
  };
  static const _statusLabels = {
    'pending':    'Pending',
    'assigned':   'Assigned',
    'in_transit': 'In Transit',
    'completed':  'Completed',
    'cancelled':  'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final status  = (trip['status'] as String? ?? 'pending').toLowerCase();
    final color   = _statusColors[status] ?? AppColors.accent;
    final label   = _statusLabels[status] ?? status;
    final from    = [trip['origin_city'], trip['origin_state']]
        .where((s) => s != null && (s as String).isNotEmpty).join(', ');
    final to      = [trip['destination_city'], trip['destination_state']]
        .where((s) => s != null && (s as String).isNotEmpty).join(', ');
    final miles   = (trip['total_miles'] as num?)?.toDouble() ?? 0;
    final dateStr = trip['scheduled_date'] as String?
        ?? trip['start_date'] as String? ?? '';
    final date    = dateStr.length >= 10
        ? dateStr.substring(5, 10).replaceAll('-', '/') : dateStr;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline.withOpacity(0.5)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.local_shipping_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  from.isNotEmpty && to.isNotEmpty ? '$from → $to' : 'Trip #${trip["id"]}',
                  style: GoogleFonts.inter(fontSize: 13,
                      fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(label, style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.straighten_rounded, size: 11, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 3),
              Text('${miles.toStringAsFixed(0)} mi',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant)),
              if (date.isNotEmpty) ...[
                const SizedBox(width: 10),
                Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 3),
                Text(date, style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ]),
          ])),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
        ]),
      ),
    );
  }
}

class _RecentFuel extends StatelessWidget {
  final List fuel;
  const _RecentFuel({required this.fuel});

  @override
  Widget build(BuildContext context) {
    if (fuel.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline.withOpacity(0.5))),
        child: Center(child: Text('No fuel logs yet.',
            style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 14))),
      );
    }
    return Column(children: fuel.map<Widget>((f) => _FuelRow(fuel: f as Map)).toList());
  }
}

class _FuelRow extends StatelessWidget {
  final Map fuel;
  const _FuelRow({required this.fuel});

  @override
  Widget build(BuildContext context) {
    final station = fuel['vendor_name'] as String? ?? 'Fuel Stop';
    final state   = fuel['jurisdiction'] as String? ?? fuel['vendor_state'] as String? ?? '';
    final gallons = (fuel['gallons'] as num?)?.toDouble() ?? 0;
    final cost    = (fuel['total_cost'] as num?)?.toDouble() ?? 0;
    final date    = fuel['purchase_date'] as String? ?? '';
    final dateStr = date.length >= 10 ? date.substring(5, 10).replaceAll('-', '/') : date;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withOpacity(0.5)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.local_gas_station, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(station, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
              color: AppColors.primary)),
          Text('$dateStr • ${gallons.toStringAsFixed(1)} Gal • $state',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${cost.toStringAsFixed(2)}',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.onSurfaceVariant),
        ]),
      ]),
    );
  }
}

// ── Arc Painter for Compliance Gauge ─────────────────────────────────────────
// Using CustomPainter keeps the arc and the label text completely separate
// in the widget tree — no z-order conflicts or strokeCap bleed-through.
class _ArcPainter extends CustomPainter {
  final double value;  // 0.0 – 1.0
  final Color color;
  const _ArcPainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius  = (size.shortestSide - strokeWidth) / 2;
    final rect    = Rect.fromCircle(center: center, radius: radius);

    // Background track
    canvas.drawArc(rect, 0, math.pi * 2, false,
      Paint()
        ..color = const Color(0xFFE8EBF5)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc — starts at top (‑π/2), sweeps clockwise
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.value != value || old.color != color;
}
