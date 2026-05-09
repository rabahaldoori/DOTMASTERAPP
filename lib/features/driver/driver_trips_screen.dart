import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/api_client.dart';
import 'trip_detail_sheet.dart';
import 'route_picker_sheet.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _navy    = Color(0xFF031634);
const _navyMid = Color(0xFF0A2550);
const _blue    = Color(0xFF1A56DB);
const _cyan    = Color(0xFF06B6D4);
const _white   = Colors.white;
const _surface = Color(0xFFF4F6FB);
const _card    = Color(0xFFFFFFFF);
const _grey    = Color(0xFF6B7280);

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key});
  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen>
    with SingleTickerProviderStateMixin {
  List<Map> _trips    = [];
  List<Map> _filtered = [];
  bool _loading  = true;
  String _filter = 'All';
  String _search = '';
  double _totalMiles = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final _filters = ['All', 'Active', 'Completed', 'Pending'];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.getDriverData();
      final list = List<Map>.from(res.data['trips'] ?? []);
      double miles = 0;
      for (final t in list) {
        miles += (t['total_miles'] as num?)?.toDouble() ?? 0;
      }
      if (mounted) {
        setState(() {
          _trips      = list;
          _totalMiles = miles;
          _loading    = false;
        });
        _applyFilter();
        _fadeCtrl.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _trips.where((t) {
        final status = (t['status'] as String? ?? '').toLowerCase();
        final matchFilter = _filter == 'All'
            || (_filter == 'Active'    && (status == 'active' || status == 'in_progress'))
            || (_filter == 'Completed' && (status == 'completed' || status == 'complete'))
            || (_filter == 'Pending'   && status == 'pending');
        final q = _search.toLowerCase();
        final matchSearch = q.isEmpty
            || (t['reference_number']    as String? ?? '').toLowerCase().contains(q)
            || (t['origin_address']      as String? ?? '').toLowerCase().contains(q)
            || (t['destination_address'] as String? ?? '').toLowerCase().contains(q);
        return matchFilter && matchSearch;
      }).toList();
    });
  }

  int get _activeCount => _trips.where((t) {
    final s = (t['status'] as String? ?? '').toLowerCase();
    return s == 'active' || s == 'in_progress';
  }).length;

  int get _completedCount => _trips.where((t) {
    final s = (t['status'] as String? ?? '').toLowerCase();
    return s == 'completed' || s == 'complete';
  }).length;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surface,
        body: RefreshIndicator(
          color: _blue,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              _buildSliverHeader(),
              SliverToBoxAdapter(child: _buildSearchAndFilter()),
              _buildTripList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverHeader() => SliverAppBar(
    expandedHeight: 115,
    pinned: true,
    backgroundColor: _navy,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    // ── Collapsed title (shows when scrolled) ──────────────────────────────
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.route_rounded, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 8),
        Text('My Trips',
          style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        const Spacer(),
        Text('${_trips.length} total',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
      ],
    ),
    titleSpacing: 16,
    automaticallyImplyLeading: false,
    flexibleSpace: FlexibleSpaceBar(
      collapseMode: CollapseMode.parallax,
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_navy, _navyMid, Color(0xFF0D3A6B)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -40, right: -40,
              child: Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _blue.withOpacity(0.07),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Distance + pills in one row (title is in SliverAppBar.title)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TOTAL DISTANCE',
                              style: GoogleFonts.inter(fontSize: 9, letterSpacing: 1.1,
                                  color: _white.withOpacity(0.5))),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                 Text(_totalMiles.toStringAsFixed(1),
                                   style: GoogleFonts.inter(fontSize: 22,
                                       fontWeight: FontWeight.w800, color: _white, height: 1)),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text('mi',
                                    style: GoogleFonts.inter(fontSize: 14,
                                        color: _white.withOpacity(0.6))),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Stat pills — compact inline
                        Row(children: [
                          _StatPill(label: 'Total', value: '${_trips.length}',
                              icon: Icons.list_alt_rounded),
                          const SizedBox(width: 6),
                          _StatPill(label: 'Active', value: '$_activeCount',
                              icon: Icons.local_shipping_rounded, accent: _cyan),
                          const SizedBox(width: 6),
                          _StatPill(label: 'Done', value: '$_completedCount',
                              icon: Icons.check_circle_rounded,
                              accent: const Color(0xFF22C55E)),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildSearchAndFilter() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
              color: _navy.withOpacity(0.06),
              blurRadius: 10, offset: const Offset(0, 3),
            )],
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) { _search = v; _applyFilter(); },
            style: GoogleFonts.inter(fontSize: 14, color: _navy),
            decoration: InputDecoration(
              hintText: 'Search trips, routes…',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: _grey),
              prefixIcon: Icon(Icons.search_rounded, color: _grey, size: 20),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: _grey, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _search = '';
                        _applyFilter();
                      })
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) {
              final sel = _filter == f;
              return GestureDetector(
                onTap: () { setState(() => _filter = f); _applyFilter(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: sel ? const LinearGradient(
                        colors: [_blue, Color(0xFF1E40AF)]) : null,
                    color: sel ? null : _card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: sel ? Colors.transparent : _grey.withOpacity(0.2)),
                    boxShadow: sel ? [BoxShadow(
                        color: _blue.withOpacity(0.3),
                        blurRadius: 8, offset: const Offset(0, 3))] : [],
                  ),
                  child: Text(f,
                    style: GoogleFonts.inter(fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? _white : _grey)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text('TRIP HISTORY',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                  color: _grey, letterSpacing: 1.2)),
            const Spacer(),
            Text('${_filtered.length} result${_filtered.length == 1 ? '' : 's'}',
              style: GoogleFonts.inter(fontSize: 12, color: _grey)),
          ],
        ),
        const SizedBox(height: 10),
      ],
    ),
  );

  Widget _buildTripList() {
    if (_loading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 40, height: 40,
                  child: CircularProgressIndicator(color: _blue, strokeWidth: 3)),
              const SizedBox(height: 12),
              Text('Loading trips…',
                  style: GoogleFonts.inter(fontSize: 13, color: _grey)),
            ],
          ),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                    color: _blue.withOpacity(0.08), shape: BoxShape.circle),
                child: Icon(Icons.route_outlined, size: 36,
                    color: _blue.withOpacity(0.5)),
              ),
              const SizedBox(height: 16),
              Text('No trips found',
                  style: GoogleFonts.inter(fontSize: 16,
                      fontWeight: FontWeight.w600, color: _navy)),
              const SizedBox(height: 6),
              Text(_filter != 'All'
                  ? 'Try selecting a different filter'
                  : 'Your trip history will appear here',
                  style: GoogleFonts.inter(fontSize: 13, color: _grey)),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final t = _filtered[i];
            final st = (t['status'] as String? ?? '').toLowerCase();
            final inRoute = st == 'in_progress';
            return _TripCard(
              trip:            t,
              index:           i,
              onStartTrip:     inRoute ? null : () => _startTrip(t),
              onCancelTrip:    inRoute ? () => _cancelTrip(t) : null,
              onCompleteTrip:  inRoute ? () => _completeTrip(t) : null,
              onUploadBol:     inRoute ? () => _showBolUploadSheet(t['id'] as int) : null,
            );
          },
          childCount: _filtered.length,
        ),
      ),
    );
  }


  /// Shows the route picker, then asks driver to confirm start odometer.
  Future<void> _startTrip(Map trip) async {
    final tripId    = trip['id'] as int?;
    final origin    = trip['origin_address'] as String? ?? '';
    final dest      = trip['destination_address'] as String? ?? '';
    final curStatus = (trip['status'] as String? ?? '').toLowerCase();

    if (tripId == null || origin.isEmpty || dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip has no route data.')),
      );
      return;
    }

    // ── Pull truck odometer from DB ───────────────────────────────────────
    double? truckOdo;
    // 1) Try from trip list payload (already joined by serializer)
    final rawOdo = trip['truck_odometer'];
    debugPrint('🔧 [Odometer] trip truck_odometer from API: $rawOdo  (truck id: ${trip['truck']})');
    if (rawOdo != null) {
      truckOdo = double.tryParse(rawOdo.toString());
      debugPrint('🔧 [Odometer] parsed from trip payload: $truckOdo');
    }
    // 2) Fallback: fetch directly from truck profile
    if (truckOdo == null) {
      final truckId = trip['truck'];
      debugPrint('🔧 [Odometer] payload null, fetching from /api/trucks/$truckId/');
      if (truckId != null) {
        try {
          final resp = await ApiClient.getTruck(
              truckId is int ? truckId : int.parse(truckId.toString()));
          debugPrint('🔧 [Odometer] truck API response: ${resp.data}');
          final odoVal = resp.data['odometer_reading'];
          if (odoVal != null) {
            truckOdo = double.tryParse(odoVal.toString());
            debugPrint('🔧 [Odometer] fetched from truck profile: $truckOdo');
          }
        } catch (e) {
          debugPrint('🔧 [Odometer] truck fetch error: $e');
        }
      }
    }
    debugPrint('🔧 [Odometer] final truckOdo: $truckOdo');

    // Step 1 — Route picker
    final chosen = await showRoutePicker(
      context,
      origin:      origin,
      destination: dest,
    );
    if (chosen == null || !mounted) return;

    // Step 2 — Odometer confirmation (pre-filled from truck profile)
    final odoCtrl = TextEditingController(
      text: truckOdo != null ? truckOdo.toStringAsFixed(0) : '',
    );
    final startOdo = await showDialog<double>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.speed_rounded, color: Color(0xFF1A56DB), size: 22),
                const SizedBox(width: 8),
                Text('Confirm Start Odometer',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Text('Verify the truck odometer reading before departing.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 18),
              TextField(
                controller: odoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Odometer (miles)',
                  hintText: 'e.g. 125,430',
                  prefixIcon: const Icon(Icons.speed_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text('Start Trip',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  final val = double.tryParse(odoCtrl.text.replaceAll(',', ''));
                  Navigator.of(ctx).pop(val);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: Text('Cancel',
                  style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
    if (startOdo == null || !mounted) return;

    try {
      final payload = <String, dynamic>{
        'origin_address':       chosen.originAddress,
        'destination_address':  chosen.destinationAddress,
        'route_polyline':       chosen.routePolyline,
        'total_miles':          chosen.totalMiles,
        'miles_by_state':       chosen.milesPerState,
        'states_traveled':      chosen.statesTraveled,
        'duration_seconds':     chosen.durationSeconds,
        'duration_text':        chosen.durationText,
        'status':               'in_progress',
        'start_odometer':       startOdo,
      };
      await ApiClient.updateTrip(tripId, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Trip started · Start odometer: ${startOdo.toStringAsFixed(0)} mi ✓'),
          backgroundColor: const Color(0xFF1E3A8A),
        ));
        _load();
        // ── Prompt driver to upload BOL ─────────────────────────────────
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) await _showBolUploadSheet(tripId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  /// Shows a bottom sheet for uploading the Bill of Lading.
  /// Driver can take a photo, pick from gallery, pick a file, or skip.
  Future<void> _showBolUploadSheet(int tripId) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: _BolUploadSheet(tripId: tripId),
      ),
    );
  }

  /// Driver enters end odometer → shows live calc (end-start) → saves actual_odometer_miles.
  Future<void> _completeTrip(Map trip) async {
    final tripId   = trip['id'] as int?;
    final startOdo = trip['start_odometer'];
    if (tripId == null) return;

    final start = double.tryParse(startOdo?.toString() ?? '') ?? 0;
    final odoCtrl = TextEditingController();
    double? liveActual;

    final endOdo = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          void onChanged(String v) {
            final val = double.tryParse(v.replaceAll(',', ''));
            setState(() {
              liveActual = (val != null && start > 0) ? val - start : null;
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(children: [
                    const Icon(Icons.flag_rounded, color: Color(0xFF16A34A), size: 22),
                    const SizedBox(width: 8),
                    Text('Complete Trip',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 16),

                  // Start odometer reference chip
                  if (start > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A56DB).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.trip_origin, size: 14, color: Color(0xFF1A56DB)),
                        const SizedBox(width: 8),
                        Text('Start odometer: ',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                        Text('${start.toStringAsFixed(0)} mi',
                          style: GoogleFonts.inter(fontSize: 13,
                              fontWeight: FontWeight.w700, color: const Color(0xFF1A56DB))),
                      ]),
                    ),
                  const SizedBox(height: 12),

                  // End odometer input
                  TextField(
                    controller: odoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    onChanged: onChanged,
                    decoration: InputDecoration(
                      labelText: 'End Odometer (miles)',
                      hintText: 'e.g. 124,600',
                      prefixIcon: const Icon(Icons.speed_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),

                  // Live calculation
                  if (liveActual != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: liveActual! > 0
                            ? const Color(0xFF16A34A).withOpacity(0.08)
                            : Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: liveActual! > 0
                              ? const Color(0xFF16A34A).withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Actual Miles Driven',
                          style: GoogleFonts.inter(fontSize: 11,
                              fontWeight: FontWeight.w600, color: Colors.grey[500])),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text(
                            '${double.tryParse(odoCtrl.text.replaceAll(",",""))?.toStringAsFixed(0) ?? "?"}' +
                            ' − ${start.toStringAsFixed(0)} = ',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                          ),
                          Text(
                            '${liveActual!.toStringAsFixed(0)} mi',
                            style: GoogleFonts.inter(
                              fontSize: 20, fontWeight: FontWeight.w800,
                              color: liveActual! > 0
                                  ? const Color(0xFF16A34A)
                                  : Colors.orange,
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text('Save & Complete',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final val = double.tryParse(odoCtrl.text.replaceAll(',', ''));
                      Navigator.of(ctx).pop(val);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: Text('Keep Going',
                      style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (endOdo == null || !mounted) return;

    // Validate
    if (endOdo <= start && start > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End odometer must be greater than start.'),
          backgroundColor: Colors.orange));
      return;
    }

    final actualMiles = start > 0 ? endOdo - start : null;

    try {
      await ApiClient.updateTrip(tripId, {
        'status':       'complete',
        'end_odometer':  endOdo,
        if (actualMiles != null) 'actual_odometer_miles': actualMiles,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(actualMiles != null
            ? '✓ Trip complete!  ${start.toStringAsFixed(0)} → ${endOdo.toStringAsFixed(0)} = ${actualMiles.toStringAsFixed(0)} mi actual'
            : '✓ Trip complete!  End: ${endOdo.toStringAsFixed(0)} mi'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4),
        ));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  /// Cancels an in-progress trip → reverts status to 'active'
  Future<void> _cancelTrip(Map trip) async {
    final tripId = trip['id'] as int?;
    if (tripId == null) return;

    // Confirm before cancelling
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cancel Trip?',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                'This will stop the trip and reset it to Active status.',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Cancel Trip',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Keep Going',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600])),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiClient.updateTrip(tripId, {'status': 'active'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip cancelled — status reset to Active'),
            backgroundColor: Color(0xFF374151),
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}

// ── Stat Pill ─────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color accent;
  const _StatPill({
    required this.label, required this.value, required this.icon,
    this.accent = Colors.white,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: accent.withOpacity(0.8)),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
          style: GoogleFonts.inter(fontSize: 14,
              fontWeight: FontWeight.w800, color: _white)),
        Text(label,
          style: GoogleFonts.inter(fontSize: 9,
              color: _white.withOpacity(0.5), letterSpacing: 0.3)),
      ]),
    ]),
  );
}

// ── Trip Card ─────────────────────────────────────────────────────────────────
class _TripCard extends StatelessWidget {
  final Map trip;
  final int index;
  final VoidCallback? onStartTrip;    // draft / active
  final VoidCallback? onCancelTrip;   // in_progress → reset to active
  final VoidCallback? onCompleteTrip; // in_progress → complete + end odometer
  final VoidCallback? onUploadBol;    // in_progress → open BOL upload dialog
  const _TripCard({
    required this.trip,
    required this.index,
    this.onStartTrip,
    this.onCancelTrip,
    this.onCompleteTrip,
    this.onUploadBol,
  });

  @override
  Widget build(BuildContext context) {
    final status      = (trip['status'] as String? ?? '').toLowerCase();
    final isInRoute   = status == 'in_progress';
    final isActive    = status == 'active' || isInRoute;
    final isCompleted = status == 'completed' || status == 'complete';
    final isPending   = status == 'pending';

    final Color statusColor = isInRoute
        ? const Color(0xFFF97316)   // orange — actively driving
        : isActive
            ? _cyan
            : isCompleted
                ? const Color(0xFF22C55E)
                : isPending
                    ? const Color(0xFFF59E0B)
                    : _grey;

    final String statusLabel = isInRoute  ? 'IN ROUTE'
        : isActive    ? 'ACTIVE'
        : isCompleted ? 'COMPLETED'
        : isPending   ? 'PENDING'
        : status.toUpperCase().replaceAll('_', ' ');

    final miles  = (trip['total_miles'] as num?)?.toDouble() ?? 0;
    final truck  = trip['truck__unit_number'] as String? ?? '—';
    final refNum = trip['reference_number']   as String? ?? '#—';

    final originCity  = trip['origin_city']        as String? ?? '';
    final originState = trip['origin_state']       as String? ?? '';
    final destCity    = trip['destination_city']   as String? ?? '';
    final destState   = trip['destination_state']  as String? ?? '';
    final originAddr  = trip['origin_address']     as String? ?? '';
    final destAddr    = trip['destination_address'] as String? ?? '';

    final from = [originCity, originState].where((s) => s.isNotEmpty).join(', ');
    final to   = [destCity, destState].where((s) => s.isNotEmpty).join(', ');
    final displayFrom = from.isNotEmpty ? from : originAddr;
    final displayTo   = to.isNotEmpty ? to : destAddr;
    final startDate   = _fmtDate(trip['start_date']);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 50),
      curve: Curves.easeOut,
      builder: (ctx, v, child) => Transform.translate(
        offset: Offset(0, 14 * (1 - v)),
        child: Opacity(opacity: v, child: child),
      ),
      child: GestureDetector(
        onTap: () => showTripDetail(context, trip),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? _cyan.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: [BoxShadow(
              color: _navy.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2),
            )],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                // Active gradient bar
                if (isActive)
                  Container(
                    height: 2.5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [_blue, _cyan]),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Header row
                      Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isActive    ? Icons.local_shipping_rounded
                            : isCompleted ? Icons.check_circle_outline_rounded
                            : Icons.schedule_rounded,
                            color: statusColor, size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(refNum,
                                style: GoogleFonts.inter(fontSize: 13,
                                    fontWeight: FontWeight.w700, color: _navy)),
                              const SizedBox(height: 1),
                              Row(children: [
                                Icon(Icons.local_shipping_outlined,
                                    size: 11, color: _grey),
                                const SizedBox(width: 3),
                                Text(truck,
                                  style: GoogleFonts.inter(
                                      fontSize: 11, color: _grey)),
                              ]),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${miles.toStringAsFixed(1)} mi',
                              style: GoogleFonts.inter(fontSize: 13,
                                  fontWeight: FontWeight.w800, color: _navy)),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(statusLabel,
                                style: GoogleFonts.inter(fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor, letterSpacing: 0.5)),
                            ),
                          ],
                        ),
                      ]),

                      // Route timeline — compact
                      if (displayFrom.isNotEmpty || displayTo.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Column(children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: _blue, shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(child: Container(
                                    width: 1.5,
                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                    color: Colors.grey.shade300,
                                  )),
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? const Color(0xFF22C55E)
                                          : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ]),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        displayFrom.isNotEmpty ? displayFrom : '—',
                                        style: GoogleFonts.inter(fontSize: 12,
                                            fontWeight: FontWeight.w600, color: _navy),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Text(
                                        displayTo.isNotEmpty ? displayTo : '—',
                                        style: GoogleFonts.inter(fontSize: 12,
                                            fontWeight: FontWeight.w600, color: _navy),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                // Date chip inline
                                if (startDate.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(startDate,
                                          style: GoogleFonts.inter(fontSize: 10,
                                              color: _grey, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // ── Action buttons ──────────────────────────────────
                      if (!isCompleted) ...[
                        const SizedBox(height: 8),
                        if (isInRoute) ...[
                          // Show start odometer chip
                          if (trip['start_odometer'] != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A56DB).withOpacity(0.07),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.speed_rounded, size: 13,
                                    color: Color(0xFF1A56DB)),
                                const SizedBox(width: 5),
                                Text(
                                  'Start: ${double.tryParse(trip["start_odometer"].toString())?.toStringAsFixed(0) ?? trip["start_odometer"]} mi',
                                  style: GoogleFonts.inter(fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A56DB)),
                                ),
                              ]),
                            ),
                          // BOL status row
                          Row(children: [
                            trip['bol_file'] != null
                              ? Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF16A34A).withOpacity(0.3)),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.description_rounded, size: 12,
                                        color: Color(0xFF16A34A)),
                                    const SizedBox(width: 5),
                                    Text('BOL uploaded ✓',
                                      style: GoogleFonts.inter(fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF16A34A))),
                                  ]),
                                )
                              : GestureDetector(
                                  onTap: onUploadBol,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF97316).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFF97316).withOpacity(0.3)),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.upload_file_rounded, size: 12,
                                          color: Color(0xFFF97316)),
                                      const SizedBox(width: 5),
                                      Text('Upload BOL',
                                        style: GoogleFonts.inter(fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFF97316))),
                                    ]),
                                  ),
                                ),
                          ]),
                          // Complete + Cancel side by side
                          SizedBox(
                            height: 36,
                            child: Row(children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle_rounded, size: 14),
                                  label: Text('Complete',
                                    style: GoogleFonts.inter(fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  onPressed: onCompleteTrip,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.cancel_rounded, size: 14),
                                  label: Text('Cancel',
                                    style: GoogleFonts.inter(fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  onPressed: onCancelTrip,
                                ),
                              ),
                            ]),
                          ),
                        ] else
                          // Blue Start button for active/draft trips
                          SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow_rounded, size: 15),
                              label: Text('Start the Trip',
                                style: GoogleFonts.inter(fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A56DB),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              onPressed: onStartTrip,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(dynamic d) {
    if (d == null) return '';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(d.toString()));
    } catch (_) {
      return d.toString();
    }
  }
}

// ── Meta Chip ─────────────────────────────────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({required this.icon, required this.label, this.color = _grey});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color.withOpacity(0.8)),
      const SizedBox(width: 5),
      Text(label,
        style: GoogleFonts.inter(fontSize: 11,
            fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// BOL Upload Bottom Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _BolUploadSheet extends StatefulWidget {
  final int tripId;
  const _BolUploadSheet({required this.tripId});

  @override
  State<_BolUploadSheet> createState() => _BolUploadSheetState();
}

class _BolUploadSheetState extends State<_BolUploadSheet> {
  String?   _filePath;
  bool      _isImage   = false;
  bool      _uploading = false;
  String?   _fileName;

  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (xf == null) return;
    setState(() { _filePath = xf.path; _isImage = true; _fileName = xf.name; });
  }

  Future<void> _pickGallery() async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xf == null) return;
    setState(() { _filePath = xf.path; _isImage = true; _fileName = xf.name; });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final ext  = path.split('.').last.toLowerCase();
    setState(() {
      _filePath = path;
      _isImage  = ['jpg','jpeg','png','heic'].contains(ext);
      _fileName = result.files.single.name;
    });
  }

  Future<void> _upload() async {
    if (_filePath == null) return;
    setState(() => _uploading = true);
    try {
      await ApiClient.uploadTripBol(widget.tripId, _filePath!);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Bill of Lading uploaded successfully!'),
          backgroundColor: Color(0xFF16A34A),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15),
              blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with close button
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A56DB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_rounded,
                  color: Color(0xFF1A56DB), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Upload Bill of Lading',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
              Text('Take a photo or choose a file',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
            ])),
            // Close / Skip
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded, size: 18, color: Colors.grey[600]),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Picker buttons row
          Row(children: [
            Expanded(child: _PickButton(
              icon:  Icons.camera_alt_rounded,
              label: 'Camera',
              color: const Color(0xFF1A56DB),
              onTap: _pickCamera,
            )),
            const SizedBox(width: 10),
            Expanded(child: _PickButton(
              icon:  Icons.photo_library_rounded,
              label: 'Gallery',
              color: const Color(0xFF7C3AED),
              onTap: _pickGallery,
            )),
            const SizedBox(width: 10),
            Expanded(child: _PickButton(
              icon:  Icons.attach_file_rounded,
              label: 'File',
              color: const Color(0xFF059669),
              onTap: _pickFile,
            )),
          ]),
          const SizedBox(height: 16),

          // Preview
          if (_filePath != null) ...[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                color: Colors.grey[50],
              ),
              clipBehavior: Clip.antiAlias,
              child: _isImage
                ? Image.file(File(_filePath!),
                    height: 180, fit: BoxFit.cover)
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.redAccent, size: 36),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_fileName ?? 'File selected',
                          style: GoogleFonts.inter(fontSize: 13,
                              fontWeight: FontWeight.w600))),
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF16A34A), size: 20),
                    ]),
                  ),
            ),
            const SizedBox(height: 16),
          ],

          // Upload button
          ElevatedButton.icon(
            icon: _uploading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white)))
                : const Icon(Icons.cloud_upload_rounded, size: 18),
            label: Text(_uploading ? 'Uploading…' : 'Upload BOL',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _filePath != null
                  ? const Color(0xFF1A56DB)
                  : Colors.grey[300],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: (_filePath != null && !_uploading) ? _upload : null,
          ),
        ],
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  const _PickButton({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}
