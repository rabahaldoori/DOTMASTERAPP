import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';

const _navy  = Color(0xFF031634);
const _navy2 = Color(0xFF0A2347);
const _blue  = Color(0xFF0453CD);
const _cyan  = Color(0xFF06B6D4);
const _surf  = Color(0xFFF0F3FA);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _userName    = '';
  String _companyName = 'IFTATrack';
  String _avatarUrl   = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = await ApiClient.getUser();
    if (!mounted) return;
    setState(() {
      _userName    = user['name']    ?? 'Admin';
      _companyName = user['company'] ?? 'IFTATrack';
      _avatarUrl   = user['avatar_url'] ?? '';
    });
    // Also fetch fresh avatar from API
    try {
      final profileRes = await ApiClient.getProfile();
      final pd = profileRes.data as Map<String, dynamic>;
      final url = (pd['avatar_url'] ?? pd['avatar'] ?? '').toString().trim();
      if (url.isNotEmpty && mounted) {
        setState(() => _avatarUrl = url);
      }
    } catch (_) {}
    try {
      final results = await Future.wait([
        ApiClient.getTrips(), ApiClient.getFuelLogs(), ApiClient.getIftaReports(),
      ]);
      if (!mounted) return;
      final tripList   = (results[0].data['results'] ?? results[0].data ?? []) as List;
      final fuelList   = (results[1].data['results'] ?? results[1].data ?? []) as List;
      final reports    = results[2].data['results'] ?? results[2].data ?? [];
      final activeTrip = tripList.cast<Map?>().firstWhere(
          (t) => t?['status'] == 'in_progress' || t?['status'] == 'active',
          orElse: () => null);
      double totalMiles = 0, totalGallons = 0, totalCost = 0;
      for (final f in fuelList) {
        totalGallons += double.tryParse(f['gallons'].toString()) ?? 0;
        totalCost    += double.tryParse(f['total_cost'].toString()) ?? 0;
      }
      for (final t in tripList) {
        // Backend stores miles in 'total_miles'; fall back to odometer diff
        final raw = t['total_miles']
            ?? t['miles_driven']
            ?? t['distance'];
        if (raw != null) {
          totalMiles += double.tryParse(raw.toString()) ?? 0;
        } else {
          final end   = double.tryParse((t['odometer_end']   ?? 0).toString()) ?? 0;
          final start = double.tryParse((t['odometer_start'] ?? 0).toString()) ?? 0;
          if (end > start) totalMiles += end - start;
        }
      }
      if (!mounted) return;
      setState(() {
        _data = {
          'activeTrip': activeTrip, 'recentFuel': fuelList.take(3).toList(),
          'totalMiles': totalMiles, 'totalGallons': totalGallons,
          'totalCost': totalCost,
          'mpg': totalGallons > 0 ? totalMiles / totalGallons : 0.0,
          'reports': reports, 'tripCount': tripList.length,
        };
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _initials {
    final parts = _userName.split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return _userName.isNotEmpty ? _userName[0].toUpperCase() : 'A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surf,
      body: RefreshIndicator(
        color: _blue,
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          // ── Pinned header ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            // ── Collapsed: logo pill + avatar ───────────────────────────
            title: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(children: [
                  const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(_companyName, style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: Colors.white)),
                ]),
              ),
              const Spacer(),
              _avatarUrl.isNotEmpty
                ? CircleAvatar(
                    radius: 17,
                    backgroundColor: _blue,
                    backgroundImage: NetworkImage(_avatarUrl),
                    onBackgroundImageError: (_, __) {},
                  )
                : CircleAvatar(
                    radius: 17,
                    backgroundColor: _blue,
                    child: Text(_initials, style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w800,
                        fontSize: 13)),
                  ),
            ]),
            // ── Expanded: greeting + stats strip ────────────────────────
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [_navy, _navy2]),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 6, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Admin Dashboard', style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: _cyan, letterSpacing: 1.2)),
                        const SizedBox(height: 3),
                        Text('Welcome, $_userName', style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                        const SizedBox(height: 14),
                        // ── Stats strip ──────────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.10)),
                          ),
                          child: IntrinsicHeight(
                            child: Row(children: [
                              _HeaderStat(
                                icon: Icons.route_rounded,
                                value: '${(_data?['totalMiles'] ?? 0.0).toStringAsFixed(0)}',
                                label: 'Miles',
                              ),
                              VerticalDivider(width: 1,
                                  color: Colors.white.withOpacity(0.12)),
                              _HeaderStat(
                                icon: Icons.local_shipping_rounded,
                                value: '${_data?['tripCount'] ?? 0}',
                                label: 'Trips',
                              ),
                              VerticalDivider(width: 1,
                                  color: Colors.white.withOpacity(0.12)),
                              _HeaderStat(
                                icon: Icons.local_gas_station_rounded,
                                value: '\$${(_data?['totalCost'] ?? 0.0).toStringAsFixed(0)}',
                                label: 'Fuel Spend',
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _blue)))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(delegate: SliverChildListDelegate([

                // ── Hero stats row ──────────────────────────────────────────
                IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _HeroCard(
                    label: 'Total Miles',
                    value: '${(_data?['totalMiles'] ?? 0.0).toStringAsFixed(0)}',
                    unit: 'mi',
                    icon: Icons.route_rounded,
                    gradient: const [Color(0xFF0453CD), Color(0xFF031DAA)],
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _HeroCard(
                    label: 'Fuel Spend',
                    value: '\$${(_data?['totalCost'] ?? 0.0).toStringAsFixed(0)}',
                    unit: 'this month',
                    icon: Icons.local_gas_station_rounded,
                    gradient: const [Color(0xFF0891B2), Color(0xFF0369A1)],
                  )),
                ])),
                const SizedBox(height: 12),

                // ── Efficiency + trips row ──────────────────────────────────
                IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _StatCard(
                    label: 'EFFICIENCY',
                    value: '${(_data?['mpg'] ?? 0.0).toStringAsFixed(1)} mpg',
                    icon: Icons.speed_rounded,
                    progress: ((_data?['mpg'] ?? 0.0) / 10.0).clamp(0.0, 1.0),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    label: 'TOTAL TRIPS',
                    value: '${_data?['tripCount'] ?? 0}',
                    icon: Icons.local_shipping_outlined,
                  )),
                ])),
                const SizedBox(height: 16),

                // ── Compliance card ─────────────────────────────────────────
                _ComplianceCard(reports: _data?['reports'] ?? []),
                const SizedBox(height: 16),

                // ── Maintenance card ─────────────────────────────────────────
                _MaintenanceSummaryCard(
                  onTap: () => context.go('/maintenance'),
                ),
                const SizedBox(height: 24),

                // ── Active trip ─────────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Active Trip', style: GoogleFonts.inter(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B))),
                  TextButton(
                    onPressed: () => context.go('/trips'),
                    child: Text('Manage', style: GoogleFonts.inter(
                        fontSize: 13, color: _blue, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 8),
                _ActiveTripCard(trip: _data?['activeTrip']),
                const SizedBox(height: 24),

                // ── Recent fuel logs ────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Recent Fuel Logs', style: GoogleFonts.inter(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B))),
                  TextButton(
                    onPressed: () => context.go('/fuel'),
                    child: Text('See All', style: GoogleFonts.inter(
                        fontSize: 13, color: _blue, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 8),
                ...(_data?['recentFuel'] ?? [])
                    .map<Widget>((f) => _FuelLogRow(fuel: f as Map))
                    .toList(),
                if ((_data?['recentFuel'] ?? []).isEmpty)
                  _EmptyState(icon: Icons.local_gas_station_outlined,
                      label: 'No fuel logs yet.'),
              ])),
            ),
        ]),
      ),
    );
  }
}

// ── Hero gradient card ─────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final List<Color> gradient;
  const _HeroCard({required this.label, required this.value,
      required this.unit, required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: gradient,
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.35),
          blurRadius: 14, offset: const Offset(0, 6))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
      const SizedBox(height: 12),
      Text(label, style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: Colors.white60, letterSpacing: 0.5)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
      Text(unit, style: GoogleFonts.inter(
          fontSize: 10, color: Colors.white60)),
    ]),
  );
}

// ── Stat card ──────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final double? progress;
  const _StatCard({required this.label, required this.value,
      required this.icon, this.progress});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8EDF5)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: _blue),
        ),
      ]),
      const SizedBox(height: 10),
      Text(label, style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8), letterSpacing: 0.4)),
      const SizedBox(height: 3),
      Text(value, style: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w800,
          color: const Color(0xFF1E293B))),
      if (progress != null) ...[
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: const Color(0xFFE8EDF5),
            valueColor: const AlwaysStoppedAnimation(_blue)),
        ),
      ],
    ]),
  );
}

// ── Compliance card ────────────────────────────────────────────────────────────
class _ComplianceCard extends StatelessWidget {
  final List reports;
  const _ComplianceCard({required this.reports});

  @override
  Widget build(BuildContext context) {
    final filed = reports.where((r) => r['status'] == 'filed').length;
    final total = reports.length;
    final pct   = (total > 0 ? filed / total : 0.75).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF031634), Color(0xFF0A2347)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: _navy.withOpacity(0.5),
            blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        SizedBox(width: 68, height: 68,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation(_cyan),
              strokeWidth: 5,
            ),
            Text('${(pct * 100).round()}%', style: GoogleFonts.inter(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(width: 18),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Compliance Status', style: GoogleFonts.inter(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('Q3 Filing Deadline: Oct 31st', style: GoogleFonts.inter(
              color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 10),
          Row(children: [
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: Color(0xFF22C55E),
                    shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('Ready for Audit', style: GoogleFonts.inter(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _cyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _cyan.withOpacity(0.35)),
              ),
              child: Text('COMPLIANT', style: GoogleFonts.inter(
                  color: _cyan, fontSize: 9, fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
            ),
          ]),
        ])),
      ]),
    );
  }
}

// ── Active trip card ───────────────────────────────────────────────────────────
class _ActiveTripCard extends StatelessWidget {
  final Map? trip;
  const _ActiveTripCard({this.trip});

  @override
  Widget build(BuildContext context) {
    if (trip == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8EDF5)),
        ),
        child: Column(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.07),
              shape: BoxShape.circle),
            child: const Icon(Icons.local_shipping_outlined,
                color: _blue, size: 26),
          ),
          const SizedBox(height: 10),
          Text('No active trip', style: GoogleFonts.inter(
              color: const Color(0xFF64748B), fontSize: 14)),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity,
            child: _GradBtn(label: 'Start New Trip',
                onTap: () => context.go('/trips'))),
        ]),
      );
    }

    final truckId  = trip!['truck_unit'] ?? trip!['truck'] ?? '—';
    final odoStart = double.tryParse(trip!['odometer_start']?.toString() ?? '0') ?? 0;
    final odoEnd   = double.tryParse(trip!['odometer_end']?.toString() ?? '0') ?? odoStart;
    final miles    = double.tryParse(trip!['total_miles']?.toString() ?? '0') ?? (odoEnd - odoStart).clamp(0, double.infinity);
    final origin   = trip!['origin_state'] ?? '';
    final dest     = trip!['destination_state'] ?? '';
    final driver   = trip!['driver_name'] ?? trip!['driver'] ?? '';
    final states   = trip!['states_traveled'] ?? '';
    final startDate = trip!['start_date'] ?? '';
    final tripNum  = trip!['trip_number']?.toString() ?? trip!['id']?.toString() ?? '';
    final status   = (trip!['status'] ?? 'active').toString().toUpperCase();

    // Status color
    final statusColor = status == 'ACTIVE' || status == 'IN_PROGRESS'
        ? const Color(0xFF0891B2) : _blue;

    // Progress (if we have start + end odo)
    final progress = odoStart > 0 && miles > 0
        ? (miles / (miles + 50)).clamp(0.0, 1.0) : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _blue.withOpacity(0.20)),
        boxShadow: [BoxShadow(color: _blue.withOpacity(0.07),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(children: [

        // ── Header ─────────────────────────────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.local_shipping_rounded, size: 18, color: _blue),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TRUCK-${truckId.toString().toUpperCase()}',
                  style: GoogleFonts.inter(fontSize: 14,
                      fontWeight: FontWeight.w800, color: _navy)),
              if (tripNum.isNotEmpty)
                Text('Trip #$tripNum', style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFF94A3B8))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(status.replaceAll('_', ' '), style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: statusColor, letterSpacing: 0.4)),
            ),
          ]),
        ),

        // ── Route row ──────────────────────────────────────────────────
        if (origin.isNotEmpty || dest.isNotEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _RouteChip(label: origin.isNotEmpty ? origin.toUpperCase() : '—',
                  icon: Icons.trip_origin_rounded),
              Expanded(child: Row(children: [
                Expanded(child: Container(height: 1,
                    color: _blue.withOpacity(0.20))),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: _blue),
                Expanded(child: Container(height: 1,
                    color: _blue.withOpacity(0.20))),
              ])),
              _RouteChip(label: dest.isNotEmpty ? dest.toUpperCase() : '—',
                  icon: Icons.place_rounded, isEnd: true),
            ]),
          ),

        // ── Stats grid ─────────────────────────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            _TripStat(label: 'MILES', value: miles > 0
                ? '${miles.toStringAsFixed(0)} mi' : '—',
                icon: Icons.speed_rounded, color: _blue),
            const SizedBox(width: 10),
            _TripStat(label: 'DRIVER',
                value: driver.isNotEmpty ? driver.split(' ').first : '—',
                icon: Icons.person_rounded, color: const Color(0xFF7C3AED)),
            const SizedBox(width: 10),
            _TripStat(label: 'DATE',
                value: startDate.isNotEmpty
                    ? startDate.toString().substring(0, 10) : '—',
                icon: Icons.calendar_today_rounded, color: const Color(0xFF059669)),
          ]),
        ),

        // ── States traveled ────────────────────────────────────────────
        if (states.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.map_outlined, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(child: Text(states, style: GoogleFonts.inter(
                  fontSize: 11, color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500), maxLines: 2)),
            ]),
          ),

        // ── Progress bar ───────────────────────────────────────────────
        if (progress != null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Trip Progress', style: GoogleFonts.inter(
                    fontSize: 10, color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600)),
                Text('${(progress * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(fontSize: 10,
                        color: _blue, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: _blue.withOpacity(0.10),
                  valueColor: const AlwaysStoppedAnimation<Color>(_blue),
                ),
              ),
            ]),
          ),

        // ── View Trip button ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: GestureDetector(
            onTap: () => context.go('/trips'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _blue.withOpacity(0.35)),
                color: _blue.withOpacity(0.04),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.open_in_new_rounded, size: 15, color: _blue),
                const SizedBox(width: 7),
                Text('View Trip Details', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RouteChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isEnd;
  const _RouteChip({required this.label, required this.icon, this.isEnd = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: isEnd ? _navy.withOpacity(0.06) : _blue.withOpacity(0.07),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11,
          color: isEnd ? _navy : _blue),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: isEnd ? _navy : _blue)),
    ]),
  );
}

class _TripStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _TripStat({required this.label, required this.value,
      required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(
            fontSize: 8, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 0.4)),
      ]),
      const SizedBox(height: 3),
      Text(value, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w800, color: _navy),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  ));
}



// ── Fuel log row ───────────────────────────────────────────────────────────────
class _FuelLogRow extends StatelessWidget {
  final Map fuel;
  const _FuelLogRow({required this.fuel});

  @override
  Widget build(BuildContext context) {
    final station = fuel['station_name'] ?? 'Fuel Stop';
    final state   = fuel['state'] ?? '';
    final gallons = double.tryParse(fuel['gallons']?.toString() ?? '0') ?? 0;
    final cost    = double.tryParse(fuel['total_cost']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0891B2).withOpacity(0.09),
            borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.local_gas_station_rounded,
              color: Color(0xFF0891B2), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(station, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B))),
          Text('${gallons.toStringAsFixed(1)} Gal${state.isNotEmpty ? ' • $state' : ''}',
              style: GoogleFonts.inter(
                  fontSize: 11, color: const Color(0xFF94A3B8))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${cost.toStringAsFixed(2)}', style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B))),
          const Icon(Icons.chevron_right, size: 16,
              color: Color(0xFFCBD5E1)),
        ]),
      ]),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon; final String label;
  const _EmptyState({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF5))),
    child: Center(child: Text(label, style: GoogleFonts.inter(
        color: const Color(0xFF94A3B8), fontSize: 14))),
  );
}

// ── Gradient button ────────────────────────────────────────────────────────────
class _GradBtn extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _GradBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A5FE8), Color(0xFF031DAA)]),
        boxShadow: [BoxShadow(color: _blue.withOpacity(0.35),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Center(child: Text(label, style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
    ),
  );
}

// ── Header Stat pill ───────────────────────────────────────────────────────────
class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _HeaderStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 13, color: const Color(0xFF06B6D4)),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
      Text(label, style: GoogleFonts.inter(
          fontSize: 9, color: Colors.white54, fontWeight: FontWeight.w500)),
    ]),
  );
}

// ── Maintenance Summary Card ──────────────────────────────────────────────────
class _MaintenanceSummaryCard extends StatefulWidget {
  final VoidCallback onTap;
  const _MaintenanceSummaryCard({required this.onTap});

  @override
  State<_MaintenanceSummaryCard> createState() =>
      _MaintenanceSummaryCardState();
}

class _MaintenanceSummaryCardState extends State<_MaintenanceSummaryCard> {
  List<Map> _records = [];
  bool      _loading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try {
      final res = await ApiClient.dio.get('/api/maintenance/mobile/');
      final d = res.data;
      final list = d is List ? d : (d['results'] ?? []);
      if (mounted) setState(() => _records = List<Map>.from(list));
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _pending  => _records.where((r) => r['status'] == 'pending').length;
  int get _critical => _records.where((r) => r['priority'] == 'critical').length;
  int get _inProg   => _records.where((r) => r['status'] == 'in_progress').length;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); widget.onTap(); },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF031634).withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: const Color(0xFF031634).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.build_rounded,
                  color: Color(0xFF031634), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Maintenance',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B))),
            ),
            if (!_loading && _critical > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.warning_rounded,
                      size: 11, color: Color(0xFFEF4444)),
                  const SizedBox(width: 3),
                  Text('$_critical Critical',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEF4444))),
                ]),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Color(0xFFCBD5E1)),
          ]),

          const SizedBox(height: 14),

          // Loading / empty / stats
          if (_loading)
            const Center(
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF06B6D4))),
            )
          else if (_records.isEmpty)
            Text('No maintenance records yet',
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF94A3B8)))
          else ...[
            Row(children: [
              _MaintStat(label: 'Total',   value: '${_records.length}', color: const Color(0xFF06B6D4)),
              _MaintStat(label: 'Pending', value: '$_pending',           color: const Color(0xFFF59E0B)),
              _MaintStat(label: 'Active',  value: '$_inProg',            color: const Color(0xFF3B82F6)),
            ]),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            Row(children: [
              const Icon(Icons.access_time_rounded,
                  size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_records.first['title'] ?? '—',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B))),
              ),
              Text(_records.first['truck_unit'] ?? '',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w500)),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _MaintStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MaintStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600)),
        ]),
      );
}
