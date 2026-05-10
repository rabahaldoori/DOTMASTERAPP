import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/font_ext.dart';
import 'dashboard_charts_widget.dart';

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

  // Trial banner state
  bool   _isTrialing   = false;
  int    _daysLeft     = 0;
  String _trialEndsAt  = '';


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

    // Fetch subscription / trial info
    try {
      final subRes = await ApiClient.getSubscription();
      final sub = subRes.data as Map<String, dynamic>;
      if (mounted && sub['is_trialing'] == true) {
        setState(() {
          _isTrialing  = true;
          _daysLeft    = (sub['days_left'] ?? 0) as int;
          _trialEndsAt = sub['trial_ends_at']?.toString() ?? '';
        });
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

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    final s = context.read<LocaleProvider>().s;
    if (h < 12) return '${s.goodMorning} \u2600\uFE0F';
    if (h < 17) return '${s.goodAfternoon} \uD83C\uDF24';
    return '${s.goodEvening} \uD83C\uDF19';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    return Scaffold(
      backgroundColor: _surf,
      body: RefreshIndicator(
        color: _blue,
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          // ── Pinned header ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 245,
            pinned: true,
            stretch: true,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            // ── Collapsed bar ───────────────────────────────────────────────────
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Image.asset('assets/images/logo.png', width: 50, height: 50, fit: BoxFit.contain),
                const SizedBox(width: 8),
                Text(_companyName.isNotEmpty ? _companyName : 'DOT Master', style: context.af(
                    fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/notifications'),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      const Icon(Icons.notifications_outlined, color: Colors.white, size: 18),
                      Positioned(top: 7, right: 7,
                        child: Container(width: 6, height: 6,
                          decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle))),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                Stack(children: [
                  CircleAvatar(
                    radius: 17, backgroundColor: _blue,
                    backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                    child: _avatarUrl.isEmpty ? Text(_initials, style: context.af(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)) : null,
                  ),
                  Positioned(bottom: 0, right: 0,
                    child: Container(width: 8, height: 8,
                      decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle,
                        border: Border.all(color: _navy, width: 1.5)))),
                ]),
              ]),
            ),
            // ── Expanded hero ───────────────────────────────────────────────────
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground],
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF031634), Color(0xFF0A2347), Color(0xFF0453CD)],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 4, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_greeting(context), style: context.af(
                                fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white54, letterSpacing: 0.3)),
                            const SizedBox(height: 2),
                            Text(_userName.isNotEmpty ? _userName : 'Admin',
                                style: context.af(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(_companyName, style: context.af(
                                fontSize: 11, color: _cyan.withOpacity(0.9), fontWeight: FontWeight.w600)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.15)),
                            ),
                            child: Text(DateFormat('EEE, MMM d').format(DateTime.now()),
                                style: context.af(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: IntrinsicHeight(
                            child: Row(children: [
                              _HeaderStat(icon: Icons.route_rounded, color: _cyan,
                                value: '${(_data?["totalMiles"] ?? 0.0).toStringAsFixed(0)}', label: s.miles),
                              VerticalDivider(width: 1, color: Colors.white.withOpacity(0.12)),
                              _HeaderStat(icon: Icons.local_shipping_rounded, color: const Color(0xFF22C55E),
                                value: '${_data?["tripCount"] ?? 0}', label: s.navTrips),
                              VerticalDivider(width: 1, color: Colors.white.withOpacity(0.12)),
                              _HeaderStat(icon: Icons.local_gas_station_rounded, color: const Color(0xFFF97316),
                                value: '\$${(_data?["totalCost"] ?? 0.0).toStringAsFixed(0)}', label: s.navFuel),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 14),
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
          else ...[
            // ── Trial banner ──────────────────────────────────────────────
            if (_isTrialing)
              SliverToBoxAdapter(
                child: _TrialBanner(
                  daysLeft:   _daysLeft,
                  expiresAt:  _trialEndsAt,
                ),
              ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(delegate: SliverChildListDelegate([

                // ── Hero stats row ──────────────────────────────────────────
                IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _HeroCard(
                    label: s.miles,
                    value: '${(_data?['totalMiles'] ?? 0.0).toStringAsFixed(0)}',
                    unit: 'mi',
                    icon: Icons.route_rounded,
                    gradient: const [Color(0xFF0453CD), Color(0xFF031DAA)],
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _HeroCard(
                    label: s.fuelLog,
                    value: '\$${(_data?['totalCost'] ?? 0.0).toStringAsFixed(0)}',
                    unit: s.thisMonth,
                    icon: Icons.local_gas_station_rounded,
                    gradient: const [Color(0xFF0891B2), Color(0xFF0369A1)],
                  )),
                ])),
                const SizedBox(height: 12),

                // ── Efficiency + trips row ──────────────────────────────────
                IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _StatCard(
                    label: s.navFuel.toUpperCase(),
                    value: '${(_data?['mpg'] ?? 0.0).toStringAsFixed(1)} mpg',
                    icon: Icons.speed_rounded,
                    progress: ((_data?['mpg'] ?? 0.0) / 10.0).clamp(0.0, 1.0),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    label: s.navTrips.toUpperCase(),
                    value: '${_data?['tripCount'] ?? 0}',
                    icon: Icons.local_shipping_outlined,
                  )),
                ])),
                const SizedBox(height: 16),

                // ── Compliance card ─────────────────────────────────────────
                _ComplianceCard(reports: _data?['reports'] ?? []),
                const SizedBox(height: 16),

                // ── Charts ──────────────────────────────────────────────────
                const DashboardChartsWidget(),
                const SizedBox(height: 16),

                // ── Maintenance card ─────────────────────────────────────────
                _MaintenanceSummaryCard(
                  onTap: () => context.go('/maintenance'),
                ),
                const SizedBox(height: 0),

                // ── Admin Quick Action Grid ──────────────────────────────────
                _AdminGridCards(data: _data, context: context),
                const SizedBox(height: 4),

                // ── Active trip ───────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(s.activeTrips, style: context.af(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B))),
                  TextButton(
                    onPressed: () => context.go('/trips'),
                    child: Text(s.manage, style: context.af(
                        fontSize: 13, color: _blue, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 8),
                _ActiveTripCard(trip: _data?['activeTrip']),
                const SizedBox(height: 24),

                // ── Recent fuel logs ────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(s.recentFuelLogs, style: context.af(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B))),
                  TextButton(
                    onPressed: () => context.go('/fuel'),
                    child: Text(s.seeAll, style: context.af(
                        fontSize: 13, color: _blue, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 8),
                ...(_data?['recentFuel'] ?? [])
                    .map<Widget>((f) => _FuelLogRow(fuel: f as Map))
                    .toList(),
                if ((_data?['recentFuel'] ?? []).isEmpty)
                  _EmptyState(icon: Icons.local_gas_station_outlined,
                      label: s.noFuelLogsYet),
              ])),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Free-trial banner ──────────────────────────────────────────────────────────
class _TrialBanner extends StatelessWidget {
  final int    daysLeft;
  final String expiresAt;
  const _TrialBanner({required this.daysLeft, required this.expiresAt});

  String _fmtDate() {
    if (expiresAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(expiresAt).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return ''; }
  }

  Color get _accentColor {
    if (daysLeft <= 3) return const Color(0xFFEF4444);
    if (daysLeft <= 7) return const Color(0xFFF97316);
    return const Color(0xFF0453CD);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final expiry = _fmtDate();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Left: clock icon + text ──────────────────────────────────
          Expanded(
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.access_time_rounded, color: accent, size: 14),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Free Trial — $daysLeft ${daysLeft == 1 ? "day" : "days"} remaining',
                      style: context.af(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: accent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (expiry.isNotEmpty)
                      Text('Expires $expiry', style: context.af(
                          fontSize: 10, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(width: 10),

          // ── Right: Upgrade button ─────────────────────────────────────
          GestureDetector(
            onTap: () => context.push('/subscription'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 6, offset: const Offset(0, 3))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Upgrade Plan', style: context.af(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.white)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded,
                    size: 12, color: Colors.white),
              ]),
            ),
          ),
        ],
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
      Text(label, style: context.af(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: Colors.white60, letterSpacing: 0.5)),
      const SizedBox(height: 2),
      Text(value, style: context.af(
          fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
      Text(unit, style: context.af(
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
      Text(label, style: context.af(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8), letterSpacing: 0.4)),
      const SizedBox(height: 3),
      Text(value, style: context.af(
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
            Text('${(pct * 100).round()}%', style: context.af(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(width: 18),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${context.watch<LocaleProvider>().s.compliance}', style: context.af(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('Q3 Filing Deadline: Oct 31st', style: context.af(
              color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 10),
          Row(children: [
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: Color(0xFF22C55E),
                    shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(context.watch<LocaleProvider>().s.active, style: context.af(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _cyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _cyan.withOpacity(0.35)),
              ),
              child: Text(context.watch<LocaleProvider>().s.compliance.toUpperCase(),
                  style: context.af(
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
          Text('No active trip', style: context.af(
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
                  style: context.af(fontSize: 14,
                      fontWeight: FontWeight.w800, color: _navy)),
              if (tripNum.isNotEmpty)
                Text('Trip #$tripNum', style: context.af(
                    fontSize: 11, color: const Color(0xFF94A3B8))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(status.replaceAll('_', ' '), style: context.af(
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
              Expanded(child: Text(states, style: context.af(
                  fontSize: 11, color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500), maxLines: 2)),
            ]),
          ),

        // ── Progress bar ───────────────────────────────────────────────
        if (progress != null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Trip Progress', style: context.af(
                    fontSize: 10, color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600)),
                Text('${(progress * 100).toStringAsFixed(0)}%',
                    style: context.af(fontSize: 10,
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
                Text('View Trip Details', style: context.af(
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
      Text(label, style: context.af(
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
        Text(label, style: context.af(
            fontSize: 8, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 0.4)),
      ]),
      const SizedBox(height: 3),
      Text(value, style: context.af(
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
          Text(station, style: context.af(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B))),
          Text('${gallons.toStringAsFixed(1)} Gal${state.isNotEmpty ? ' • $state' : ''}',
              style: context.af(
                  fontSize: 11, color: const Color(0xFF94A3B8))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${cost.toStringAsFixed(2)}', style: context.af(
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
    child: Center(child: Text(label, style: context.af(
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
      child: Center(child: Text(label, style: context.af(
          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
    ),
  );
}

// ── Header Stat pill ───────────────────────────────────────────────────────────
class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _HeaderStat({required this.icon, required this.value, required this.label, this.color = const Color(0xFF06B6D4)});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 28, height: 28,
        decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
        child: Icon(icon, size: 14, color: color)),
      const SizedBox(height: 5),
      Text(value, style: context.af(
          fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
      Text(label, style: context.af(
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
    final s = context.watch<LocaleProvider>().s;
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
              child: Text(s.maintenance,
                  style: context.af(
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
                      style: context.af(
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
            Text(s.noMaintenanceYet,
                style: context.af(
                    fontSize: 13, color: const Color(0xFF94A3B8)))
          else ...[
            Row(children: [
              _MaintStat(label: s.totalInspections, value: '${_records.length}', color: const Color(0xFF06B6D4)),
              _MaintStat(label: s.pending,          value: '$_pending',           color: const Color(0xFFF59E0B)),
              _MaintStat(label: s.active,           value: '$_inProg',            color: const Color(0xFF3B82F6)),
            ]),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            Row(children: [
              const Icon(Icons.access_time_rounded,
                  size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_records.first['title'] ?? '—',
                    overflow: TextOverflow.ellipsis,
                    style: context.af(
                        fontSize: 12,
                        color: const Color(0xFF64748B))),
              ),
              Text(_records.first['truck_unit'] ?? '',
                  style: context.af(
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
              style: context.af(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: context.af(
                  fontSize: 10, color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600)),
        ]),
      );
}



// ── Admin Quick-Action Grid (2-column squares) ─────────────────────────────
class _AdminGridCards extends StatelessWidget {
  final Map<String, dynamic>? data;
  final BuildContext context;
  const _AdminGridCards({this.data, required this.context});

  int _nextIftaDays() {
    final now  = DateTime.now();
    final q    = ((now.month - 1) ~/ 3) + 1;
    final year = q == 4 ? now.year + 1 : now.year;
    final mon  = (q % 4) * 3 + 1;
    return DateTime(year, mon, 31).difference(now).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    final reports = (data?['reports'] as List?) ?? [];
    final pending = reports.where((r) => r['status'] != 'filed').length;
    final days    = _nextIftaDays();

    final cards = [
      _GCard(
        gradient: const LinearGradient(
            colors: [Color(0xFF0453CD), Color(0xFF1D6AF5)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.description_outlined,
        label: s.iftaFiling,
        value: '$days days',
        sub: s.untilDue,
        onTap: () => context.go('/reports'),
      ),
      _GCard(
        gradient: const LinearGradient(
            colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.assignment_late_outlined,
        label: s.pendingReports,
        value: '$pending',
        sub: pending == 0 ? s.reportsFiled : 'report${pending == 1 ? '' : 's'} ${s.reportUnfiled}',
        onTap: () => context.go('/reports'),
      ),
      _GCard(
        gradient: const LinearGradient(
            colors: [Color(0xFF6D28D9), Color(0xFF7C3AED)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.fact_check_rounded,
        label: s.trucks,
        value: s.manage,
        sub: s.checklistBuilder,
        onTap: () => context.push('/inspection-template'),
      ),
      _GCard(
        gradient: const LinearGradient(
            colors: [Color(0xFF065F46), Color(0xFF059669)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.history_rounded,
        label: s.inspectionHistory,
        value: s.history,
        sub: s.allVehicleRecords,
        onTap: () => context.push('/inspection-history'),
      ),
      _GCard(
        gradient: const LinearGradient(
            colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        icon: Icons.people_alt_rounded,
        label: s.drivers,
        value: s.manage,
        sub: s.teamAccounts,
        onTap: () => context.push('/admin/drivers'),
      ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text(s.quickActions,
          style: context.af(fontSize: 17, fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B))),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 2.3,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: cards,
      ),
    ]);
  }
}

class _GCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String label, value, sub;
  final VoidCallback onTap;
  const _GCard({
    required this.gradient, required this.icon,
    required this.label, required this.value,
    required this.sub, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 10, offset: const Offset(0, 4))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(children: [
            // Top gloss shimmer
            Positioned(top: 0, left: 0, right: 0,
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.18),
                             Colors.white.withOpacity(0.00)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              ),
            ),
            // Decorative orb bottom-right
            Positioned(right: -20, bottom: -20,
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.10)))),
            // Content: horizontal layout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Icon badge
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, color: Colors.white, size: 19)),
                const SizedBox(width: 12),
                // Text column
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: context.af(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.72),
                        letterSpacing: 0.2)),
                    const SizedBox(height: 1),
                    Text(value, style: context.af(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        color: Colors.white, height: 1.1),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(sub, style: context.af(
                        fontSize: 10, color: Colors.white.withOpacity(0.62))),
                  ],
                )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
