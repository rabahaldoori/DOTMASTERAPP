import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/font_ext.dart';

const _navy = Color(0xFF031634);
const _blue = Color(0xFF3B82F6);
const _cyan = Color(0xFF0891B2);
const _grey = Color(0xFF64748B);

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List _trips = [];
  List _filtered = [];
  bool _loading = true;
  // Internal filter key — always compare against these constants, not translated labels
  String _filter = 'All';
  String _search = '';
  double _totalMiles = 0;
  int _stateCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.getTrips();
      final trips = List.from(res.data['results'] ?? res.data ?? []);
      double miles = 0;
      final states = <String>{};
      for (final t in trips) {
        miles += double.tryParse((t['total_miles'] ?? t['miles_driven'] ?? 0).toString()) ?? 0;
        final s = t['states_traveled']?.toString() ?? '';
        if (s.isNotEmpty) {
          states.addAll(s.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty));
        }
      }
      setState(() {
        _trips = trips;
        _totalMiles = miles;
        _stateCount = states.length;
        _loading = false;
      });
      _applyFilter();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    var list = List.from(_trips);
    if (_filter == 'Active') {
      list = list.where((t) {
        final s = (t['status'] ?? '').toString().toLowerCase();
        return s == 'active' || s == 'in_progress';
      }).toList();
    } else if (_filter == 'Completed') {
      list = list.where((t) {
        final s = (t['status'] ?? '').toString().toLowerCase();
        return s == 'completed' || s == 'complete';
      }).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((t) {
        return (t['truck']?.toString().toLowerCase().contains(q) ?? false) ||
               (t['driver_name']?.toString().toLowerCase().contains(q) ?? false) ||
               (t['states_traveled']?.toString().toLowerCase().contains(q) ?? false) ||
               (t['trip_number']?.toString().toLowerCase().contains(q) ?? false);
      }).toList();
    }
    setState(() => _filtered = list);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    final bottom = MediaQuery.of(context).padding.bottom;

    // Filter tabs: keys are fixed English strings, labels are localized
    final filters = [
      ('All',       s.filterAll),
      ('Active',    s.active),
      ('Completed', s.completed),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _blue,
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 170,
              pinned: true,
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              title: Text(s.navTrips, style: context.af(
                  fontWeight: FontWeight.w800, color: Colors.white, fontSize: 17)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                  onPressed: () {},
                  tooltip: s.newTrip,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF031634), Color(0xFF0D2952)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 8, 20, 16),
                      child: _loading
                          ? const Center(child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2))
                          : Row(children: [
                              _HeaderStat(
                                value: '${_trips.length}',
                                label: s.totalTrips,
                                icon: Icons.route_rounded,
                              ),
                              _headerDiv(),
                              _HeaderStat(
                                value: _totalMiles > 0
                                    ? '${(_totalMiles / 1000).toStringAsFixed(1)}K'
                                    : '0',
                                label: s.totalMiles,
                                icon: Icons.speed_rounded,
                              ),
                              _headerDiv(),
                              _HeaderStat(
                                value: '$_stateCount',
                                label: s.states,
                                icon: Icons.map_outlined,
                              ),
                              _headerDiv(),
                              _HeaderStat(
                                value: '${_trips.where((t) {
                                  final st = (t['status'] ?? '').toString().toLowerCase();
                                  return st == 'active' || st == 'in_progress';
                                }).length}',
                                label: s.active,
                                icon: Icons.local_shipping_rounded,
                                color: const Color(0xFF22C55E),
                              ),
                            ]),
                    ),
                  ),
                ),
              ),
            ),

            // ── Search + Filter ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(children: [
                  // Search bar
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                          blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: TextField(
                      onChanged: (v) { _search = v; _applyFilter(); },
                      style: context.af(fontSize: 13, color: _navy),
                      decoration: InputDecoration(
                        hintText: s.searchByTruckDriverState,
                        hintStyle: context.af(fontSize: 13, color: _grey),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18,
                            color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filters.map((f) =>
                        GestureDetector(
                          onTap: () { setState(() => _filter = f.$1); _applyFilter(); },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: _filter == f.$1 ? _navy : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _filter == f.$1
                                      ? _navy : const Color(0xFFE2E8F0)),
                              boxShadow: _filter == f.$1 ? [BoxShadow(
                                  color: _navy.withOpacity(0.18),
                                  blurRadius: 8, offset: const Offset(0, 3))] : [],
                            ),
                            child: Text(f.$2, style: context.af(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: _filter == f.$1 ? Colors.white : _grey)),
                          ),
                        )
                      ).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),

            // ── Trip list ──────────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _blue)))
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.route_outlined, size: 52,
                        color: _grey.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text(s.noTripsFound, style: context.af(
                        color: _grey, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(s.adjustFilterSearch,
                        style: context.af(color: _grey, fontSize: 13)),
                  ]),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _TripCard(trip: _filtered[i] as Map),
                    childCount: _filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _headerDiv() => Container(
      width: 1, height: 32, color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 2));
}

// ── Header stat ──────────────────────────────────────────────────────────────
class _HeaderStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _HeaderStat({required this.value, required this.label,
      required this.icon, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 14, color: color.withOpacity(0.7)),
      const SizedBox(height: 3),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, style: context.af(fontSize: 15,
            fontWeight: FontWeight.w800, color: color)),
      ),
      const SizedBox(height: 1),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: context.af(fontSize: 9,
            color: Colors.white38, letterSpacing: 0.3)),
      ),
    ]),
  );
}

// ── Trip card ────────────────────────────────────────────────────────────────
class _TripCard extends StatelessWidget {
  final Map trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final s      = context.watch<LocaleProvider>().s;
    final status = (trip['status'] ?? '').toString().toLowerCase();
    final isActive = status == 'active' || status == 'in_progress';
    final isDone   = status == 'completed' || status == 'complete';

    final Color statusColor = isActive
        ? const Color(0xFF0891B2)
        : isDone ? const Color(0xFF059669) : _grey;
    final String statusLabel = isActive
        ? s.statusActive
        : isDone ? s.statusComplete
        : status.toUpperCase().replaceAll('_', ' ');

    final truckId  = trip['truck_unit'] ?? trip['truck'] ?? '—';
    final tripNum  = trip['trip_number']?.toString() ?? '';
    final driver   = trip['driver_name'] ?? '';
    final origin   = trip['origin_state'] ?? '';
    final dest     = trip['destination_state'] ?? '';
    final miles    = double.tryParse(
        (trip['total_miles'] ?? trip['miles_driven'] ?? 0).toString()) ?? 0;
    final states   = trip['states_traveled']?.toString() ?? '';
    final startDate = _fmt(trip['start_date']);
    final id = int.tryParse(trip['id']?.toString() ?? '') ?? 0;

    return GestureDetector(
      onTap: () {
        if (id > 0) context.push('/trips/$id', extra: trip);
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? _cyan.withOpacity(0.35) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          // ── Top row ──────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.local_shipping_rounded,
                  size: 20, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TRUCK-${truckId.toString().toUpperCase()}',
                  style: context.af(fontSize: 13,
                      fontWeight: FontWeight.w800, color: _navy)),
              if (tripNum.isNotEmpty)
                Text('Trip #$tripNum',
                    style: context.af(fontSize: 11, color: _grey),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
              Text(startDate,
                  style: context.af(fontSize: 11, color: _grey),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ])),
            // Status + miles
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(statusLabel, style: context.af(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: statusColor, letterSpacing: 0.4)),
              ),
              const SizedBox(height: 4),
              Text(miles > 0 ? '${miles.toStringAsFixed(0)} ${s.miles}' : '—',
                  style: context.af(fontSize: 13,
                      fontWeight: FontWeight.w800, color: _navy)),
            ]),
          ]),

          // ── Route row ─────────────────────────────────────────────────
          if (origin.isNotEmpty || dest.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              child: Row(children: [
                _LocDot(isStart: true),
                const SizedBox(width: 8),
                Text(origin.isNotEmpty ? origin.toUpperCase() : '—',
                    style: context.af(fontSize: 12,
                        fontWeight: FontWeight.w700, color: _navy)),
                Expanded(child: Row(children: [
                  Expanded(child: Container(height: 1,
                      color: _blue.withOpacity(0.15),
                      margin: const EdgeInsets.symmetric(horizontal: 8))),
                  Icon(Icons.arrow_forward_rounded, size: 13, color: _blue.withOpacity(0.5)),
                  Expanded(child: Container(height: 1,
                      color: _blue.withOpacity(0.15),
                      margin: const EdgeInsets.symmetric(horizontal: 8))),
                ])),
                Text(dest.isNotEmpty ? dest.toUpperCase() : '—',
                    style: context.af(fontSize: 12,
                        fontWeight: FontWeight.w700, color: _navy)),
                const SizedBox(width: 8),
                _LocDot(isStart: false),
              ]),
            ),
          ],

          // ── Driver + states ───────────────────────────────────────────
          if (driver.isNotEmpty || states.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (driver.isNotEmpty) ...[
                const Icon(Icons.person_outline_rounded, size: 13,
                    color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(driver, style: context.af(fontSize: 11, color: _grey)),
                if (states.isNotEmpty) const SizedBox(width: 10),
              ],
              if (states.isNotEmpty) ...[
                const Icon(Icons.map_outlined, size: 13,
                    color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Expanded(child: Text(states,
                    style: context.af(fontSize: 11, color: _grey),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ]),
          ],
        ]),
      ),
      ),
    );
  }

  String _fmt(dynamic d) {
    if (d == null) return '';
    try {
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(d.toString()));
    } catch (_) { return d.toString(); }
  }
}

class _LocDot extends StatelessWidget {
  final bool isStart;
  const _LocDot({required this.isStart});
  @override
  Widget build(BuildContext context) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: isStart ? _blue : _navy,
    ),
  );
}
