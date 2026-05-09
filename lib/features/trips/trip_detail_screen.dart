import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';

const _navy = Color(0xFF031634);
const _blue = Color(0xFF3B82F6);
const _cyan = Color(0xFF0891B2);
const _green = Color(0xFF059669);
const _orange = Color(0xFFF97316);
const _purple = Color(0xFF7C3AED);
const _grey = Color(0xFF64748B);

// ── Helper: resolve value from multiple possible key names ─────────────────────
String _val(Map? data, List<String> keys, {String fallback = '—'}) {
  if (data == null) return fallback;
  for (final k in keys) {
    final v = data[k];
    if (v != null && v.toString().isNotEmpty && v.toString() != 'null') {
      return v.toString();
    }
  }
  return fallback;
}

class TripDetailScreen extends StatefulWidget {
  final int tripId;
  final Map? initialData;
  const TripDetailScreen({super.key, required this.tripId, this.initialData});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Map? _trip;
  List _fuelLogs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _trip = widget.initialData;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final tripRes = await ApiClient.getTripById(widget.tripId);
      Map? tripData = tripRes.data as Map?;

      // Merge initialData fields that may be missing from the detail response
      if (widget.initialData != null && tripData != null) {
        widget.initialData!.forEach((k, v) {
          if (tripData![k] == null) tripData[k] = v;
        });
      }
      setState(() => _trip = tripData ?? _trip);

      // Try fuel logs from embedded list first, then separate call
      final embedded = _trip?['fuel_entries'] ?? _trip?['fuel_logs'];
      if (embedded is List && embedded.isNotEmpty) {
        setState(() => _fuelLogs = embedded);
      } else {
        try {
          final fuelRes = await ApiClient.getFuelLogs(search: widget.tripId.toString());
          final logs = fuelRes.data['results'] ?? fuelRes.data ?? [];
          setState(() => _fuelLogs = List.from(logs));
        } catch (_) {}
      }
    } catch (e) {
      setState(() { _error = 'Could not load full trip details.'; });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Resolve common field aliases ──────────────────────────────────────────
  String get _truckLabel {
    final raw = _val(_trip, ['truck_unit', 'truck__unit_number', 'truck', 'truck_id']);
    return raw == '—' ? '—' : 'TRUCK-${raw.toUpperCase()}';
  }

  // origin_address = "Dallas, TX, USA" — primary; fallback to city+state
  String get _originFull {
    final addr = _val(_trip, ['origin_address'], fallback: '');
    if (addr.isNotEmpty) return addr;
    final city  = _val(_trip, ['origin_city'],  fallback: '');
    final state = _val(_trip, ['origin_state'], fallback: '');
    return [city, state].where((s) => s.isNotEmpty).join(', ');
  }

  // destination_address = "Los Angeles, CA, USA" — primary
  String get _destFull {
    final addr = _val(_trip, ['destination_address'], fallback: '');
    if (addr.isNotEmpty) return addr;
    final city  = _val(_trip, ['destination_city'],  fallback: '');
    final state = _val(_trip, ['destination_state'], fallback: '');
    return [city, state].where((s) => s.isNotEmpty).join(', ');
  }

  // For the header chips — prefer short state code
  String get _originState  => _val(_trip, ['origin_state'],      fallback: '');
  String get _originCity   => _val(_trip, ['origin_city', 'origin_address'], fallback: '');
  String get _destState    => _val(_trip, ['destination_state'], fallback: '');
  String get _destCity     => _val(_trip, ['destination_city', 'destination_address'], fallback: '');

  String get _driverName  => _val(_trip, ['driver_name', 'driver__name', 'driver_full_name']);
  String get _tripNum     => _val(_trip, ['trip_number', 'reference_number', 'id']);
  String get _totalMiles  => _mi(_val(_trip, ['total_miles', 'total_distance'], fallback: '0'));
  String get _drivenMiles => _mi(_val(_trip, ['miles_driven', 'driven_miles'], fallback: '0'));
  // Correct field names from serializer: start_odometer / end_odometer
  String get _odoStart    => _val(_trip, ['start_odometer', 'odometer_start', 'odo_start']);
  String get _odoEnd      => _val(_trip, ['end_odometer',   'odometer_end',   'odo_end']);
  String get _quarter     => _val(_trip, ['quarter', 'tax_quarter', 'ifta_quarter']);
  String get _year        => _val(_trip, ['year',    'tax_year',    'ifta_year']);
  String get _carrier     => _val(_trip, ['carrier_name', 'carrier', 'company_name']);
  String get _dot         => _val(_trip, ['dot_number', 'dot', 'mc_number']);
  String get _states      => _val(_trip, ['states_traveled', 'states'], fallback: '');
  String get _notes       => _val(_trip, ['notes', 'description', 'comments'], fallback: '');
  String get _status      => (_trip?['status'] ?? '').toString().toLowerCase();
  String get _departure   => _val(_trip, ['departure_time'], fallback: '');
  String get _duration    => _val(_trip, ['duration_seconds', 'drive_duration'], fallback: '');
  String get _arrival     => _val(_trip, ['estimated_arrival'], fallback: '');


  @override
  Widget build(BuildContext context) {
    final isActive = _status == 'active' || _status == 'in_progress';
    final isDone   = _status == 'completed' || _status == 'complete';
    final statusColor = isActive ? _cyan : isDone ? _green : _grey;
    final statusLabel = isActive ? 'ACTIVE'
        : isDone ? 'COMPLETE' : _status.toUpperCase().replaceAll('_', ' ');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _blue,
        child: CustomScrollView(
          slivers: [

            // ── Pinned App Bar ─────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 210,
              pinned: true,
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              automaticallyImplyLeading: false,

              // ── Explicit back button ────────────────────────────────
              leading: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  margin: const EdgeInsets.only(left: 12),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.20)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: Colors.white),
                ),
              ),

              title: Text('Trip #$_tripNum',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      color: Colors.white, fontSize: 16)),

              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.50), width: 1.5),
                  ),
                  child: Text(statusLabel, style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w800, color: statusColor,
                      letterSpacing: 0.3)),
                ),
              ],

              // ── Expanded header ─────────────────────────────────────
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF031634), Color(0xFF0D2952)],
                    ),
                  ),
                  child: _trip == null
                      ? const SizedBox()
                      : SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 10, 20, 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Truck row
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.09),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                                    ),
                                    child: const Icon(Icons.local_shipping_rounded,
                                        size: 22, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_truckLabel,
                                          style: GoogleFonts.inter(fontSize: 19,
                                              fontWeight: FontWeight.w900, color: Colors.white)),
                                      Text(_fmtDate(_trip!['start_date']),
                                          style: GoogleFonts.inter(
                                              fontSize: 12, color: Colors.white54)),
                                    ],
                                  )),
                                ]),
                                const SizedBox(height: 16),

                                // Origin → Destination
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                                  ),
                                  child: Row(children: [
                                    // FROM
                                    Expanded(child: _HdrLoc(
                                      label: 'FROM',
                                      city: _originFull,
                                      state: '',
                                    )),
                                    // Arrow
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Column(children: [
                                        Container(width: 20, height: 1, color: Colors.white24),
                                        const SizedBox(height: 2),
                                        const Icon(Icons.arrow_forward_rounded,
                                            size: 14, color: Colors.white54),
                                        const SizedBox(height: 2),
                                        Container(width: 20, height: 1, color: Colors.white24),
                                      ]),
                                    ),
                                    // TO
                                    Expanded(child: _HdrLoc(
                                      label: 'TO',
                                      city: _destFull,
                                      state: '',
                                      align: CrossAxisAlignment.end,
                                    )),
                                  ]),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // ── Loading overlay ────────────────────────────────────────
            if (_loading && _trip == null)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: _blue)))

            else if (_error != null && _trip == null)
              SliverFillRemaining(child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: _grey),
                  const SizedBox(height: 12),
                  Text(_error!, style: GoogleFonts.inter(color: _grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ]),
              ))

            // ── Section content ────────────────────────────────────────
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 20, 16,
                    MediaQuery.of(context).padding.bottom + 100),
                sliver: SliverList(delegate: SliverChildListDelegate([

                  // ── Quick stats strip ─────────────────────────────────
                  _QuickStats(
                    totalMiles: _totalMiles,
                    drivenMiles: _drivenMiles,
                    odoStart: _odoStart,
                    odoEnd: _odoEnd,
                  ),
                  const SizedBox(height: 14),

                  // ── Driver & Truck ────────────────────────────────────
                  _SectionCard(title: '🚚 Driver & Truck', children: [
                    _InfoGrid([
                      _InfoCell('Driver',   _driverName),
                      _InfoCell('Truck',    _truckLabel),
                      _InfoCell('Carrier',  _carrier),
                      _InfoCell('DOT #',    _dot),
                    ]),
                  ]),
                  const SizedBox(height: 14),

                  // ── Route & Dates ─────────────────────────────────────
                  _SectionCard(title: '📅 Route & Dates', children: [
                    _InfoGrid([
                      _InfoCell('Start Date', _fmtDate(_trip!['start_date'])),
                      _InfoCell('End Date',   _fmtDate(_trip!['end_date'])),
                      _InfoCell('From', _originFull.isNotEmpty ? _originFull : '—'),
                      _InfoCell('To',   _destFull.isNotEmpty   ? _destFull   : '—'),
                      if (_departure.isNotEmpty)
                        _InfoCell('Departure', _departure),
                      if (_arrival.isNotEmpty)
                        _InfoCell('Est. Arrival', _fmtDateTime(_arrival)),
                      _InfoCell('Quarter', _quarter),
                      _InfoCell('Year',    _year),
                    ]),
                  ]),
                  const SizedBox(height: 14),

                  // ── States Traveled ───────────────────────────────────
                  if (_states.isNotEmpty) ...[
                    _SectionCard(title: '🗺️ States Traveled', children: [
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _states
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .map<Widget>((s) => _StateChip(state: s))
                            .toList(),
                      ),
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // ── Fuel Entries ──────────────────────────────────────
                  if (_fuelLogs.isNotEmpty) ...[
                    _SectionCard(title: '⛽ Fuel Entries', children: [
                      const SizedBox(height: 4),
                      ..._fuelLogs
                          .map<Widget>((f) => _FuelEntry(fuel: f as Map))
                          .toList(),
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // ── Notes ─────────────────────────────────────────────
                  if (_notes.isNotEmpty && _notes != '—') ...[
                    _SectionCard(title: '📝 Notes', children: [
                      const SizedBox(height: 4),
                      Text(_notes, style: GoogleFonts.inter(
                          fontSize: 13, color: _grey, height: 1.6)),
                    ]),
                    const SizedBox(height: 14),
                  ],

                ])),
              ),
          ],
        ),
      ),
    );
  }

  String _mi(String v) {
    final d = double.tryParse(v) ?? 0;
    return d > 0 ? '${d.toStringAsFixed(0)} mi' : '—';
  }

  String _fmtDate(dynamic d) {
    if (d == null) return '—';
    try {
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(d.toString()));
    } catch (_) { return d.toString(); }
  }

  String _fmtDateTime(dynamic d) {
    if (d == null || d.toString().isEmpty) return '—';
    try {
      return DateFormat('EEE, MMM d · h:mm a').format(DateTime.parse(d.toString()).toLocal());
    } catch (_) { return d.toString(); }
  }
}

// ── Quick 4-stat strip ────────────────────────────────────────────────────────
class _QuickStats extends StatelessWidget {
  final String totalMiles, drivenMiles, odoStart, odoEnd;
  const _QuickStats({
    required this.totalMiles, required this.drivenMiles,
    required this.odoStart,   required this.odoEnd,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    _QStat(label: 'Total Miles',  value: totalMiles, icon: Icons.route_rounded,           color: _blue),
    const SizedBox(width: 10),
    _QStat(label: 'Driven',       value: drivenMiles, icon: Icons.speed_rounded,           color: _cyan),
    const SizedBox(width: 10),
    _QStat(label: 'Odo Start',    value: odoStart,    icon: Icons.radio_button_unchecked,  color: _orange),
    const SizedBox(width: 10),
    _QStat(label: 'Odo End',      value: odoEnd,      icon: Icons.adjust_rounded,           color: _purple),
  ]);
}

class _QStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _QStat({required this.label, required this.value,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.18)),
      boxShadow: [BoxShadow(color: color.withOpacity(0.06),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(height: 6),
      Text(value, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w800, color: _navy),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(
          fontSize: 9, color: _grey, fontWeight: FontWeight.w600,
          letterSpacing: 0.2)),
    ]),
  ));
}

// ── Header location ───────────────────────────────────────────────────────────
class _HdrLoc extends StatelessWidget {
  final String label, city, state;
  final CrossAxisAlignment align;
  const _HdrLoc({required this.label, required this.city,
      required this.state, this.align = CrossAxisAlignment.start});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: align,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: GoogleFonts.inter(
          fontSize: 9, color: Colors.white38,
          fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      const SizedBox(height: 2),
      if (city.isNotEmpty && city != '—')
        Text(city, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      if (state.isNotEmpty)
        Text(state.toUpperCase(), style: GoogleFonts.inter(
            fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600)),
      if ((city.isEmpty || city == '—') && state.isEmpty)
        Text('—', style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
    ],
  );
}

// ── Section card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
      const SizedBox(height: 14),
      ...children,
    ]),
  );
}

// ── 2-column info grid ────────────────────────────────────────────────────────
class _InfoGrid extends StatelessWidget {
  final List<_InfoCell> cells;
  const _InfoGrid(this.cells);

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: cells[i]),
        const SizedBox(width: 14),
        Expanded(child: i + 1 < cells.length ? cells[i + 1] : const SizedBox()),
      ]));
      if (i + 2 < cells.length) rows.add(const SizedBox(height: 14));
    }
    return Column(children: rows);
  }
}

class _InfoCell extends StatelessWidget {
  final String label, value;
  const _InfoCell(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.inter(
          fontSize: 10, color: _grey,
          fontWeight: FontWeight.w600, letterSpacing: 0.4)),
      const SizedBox(height: 3),
      Text(value, style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w700, color: _navy),
          maxLines: 2, overflow: TextOverflow.ellipsis),
    ],
  );
}

// ── State chip ────────────────────────────────────────────────────────────────
class _StateChip extends StatelessWidget {
  final String state;
  const _StateChip({required this.state});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: _blue.withOpacity(0.07),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _blue.withOpacity(0.20)),
    ),
    child: Text(state, style: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
  );
}

// ── Fuel entry ────────────────────────────────────────────────────────────────
class _FuelEntry extends StatelessWidget {
  final Map fuel;
  const _FuelEntry({required this.fuel});

  @override
  Widget build(BuildContext context) {
    final station = fuel['station_name'] ?? fuel['vendor'] ?? 'Fuel Stop';
    final state   = fuel['state'] ?? fuel['purchase_state'] ?? '';
    final gal     = double.tryParse((fuel['gallons'] ?? fuel['quantity'] ?? 0).toString()) ?? 0;
    final cost    = double.tryParse((fuel['total_cost'] ?? fuel['amount'] ?? 0).toString()) ?? 0;
    final date    = fuel['purchase_date'] ?? fuel['date'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _cyan.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.local_gas_station_rounded, size: 18, color: _cyan),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(station, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
          Row(children: [
            if (state.isNotEmpty) ...[
              Text(state, style: GoogleFonts.inter(fontSize: 11, color: _grey)),
              const SizedBox(width: 6),
            ],
            if (date.isNotEmpty)
              Text(_fmtDate(date), style: GoogleFonts.inter(fontSize: 11, color: _grey)),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${cost.toStringAsFixed(2)}', style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
          Text('${gal.toStringAsFixed(1)} gal', style: GoogleFonts.inter(
              fontSize: 11, color: _grey)),
        ]),
      ]),
    );
  }

  String _fmtDate(dynamic d) {
    try {
      return DateFormat('MMM d').format(DateTime.parse(d.toString()));
    } catch (_) { return d.toString(); }
  }
}
