import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';

// ── Design tokens (matches driver design) ─────────────────────────────────────
const _navy    = Color(0xFF031634);
const _navy2   = Color(0xFF0D2952);
const _blue    = Color(0xFF0453CD);
const _cyan    = Color(0xFF06B6D4);
const _green   = Color(0xFF16A34A);
const _surface = Color(0xFFF0F3FF);
const _border  = Color(0xFFDCE2F3);
const _grey    = Color(0xFF75777E);

double _n(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class FuelLogsScreen extends StatefulWidget {
  const FuelLogsScreen({super.key});
  @override
  State<FuelLogsScreen> createState() => _FuelLogsScreenState();
}

class _FuelLogsScreenState extends State<FuelLogsScreen> {
  List _logs = [];
  bool _loading = true;
  String _companyName = 'IFTATrack';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUser();
    _load();
  }

  Future<void> _loadUser() async {
    final user = await ApiClient.getUser();
    if (mounted) {
      setState(() => _companyName = user['company'] ?? 'IFTATrack');
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.getFuelLogs(
          search: _searchCtrl.text.trim().isEmpty
              ? null
              : _searchCtrl.text.trim());
      setState(() => _logs = res.data['results'] ?? res.data ?? []);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _totalCost    => _logs.fold(0, (s, f) => s + _n(f['total_cost']));
  double get _totalGallons => _logs.fold(0, (s, f) => s + _n(f['gallons']));
  int    get _pending      => _logs.where((f) => f['receipt_image'] == null).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: RefreshIndicator(
        onRefresh: _load, color: _blue,
        child: CustomScrollView(slivers: [
          // ── Pinned SliverAppBar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: const Icon(Icons.local_gas_station_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text('Fuel Logs', style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: Colors.white)),
              const Spacer(),
              Text('${_logs.length} logs', style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.white54)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.go('/fuel/add'),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.20)),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
            ]),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [_navy, _navy2],
                  ),
                ),
                child: Stack(children: [
                  Positioned(right: -30, top: -30, child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04)))),
                  Positioned(right: 40, top: 60, child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _blue.withOpacity(0.18)))),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('TOTAL SPENT', style: GoogleFonts.inter(
                                  fontSize: 9, letterSpacing: 1.1,
                                  color: Colors.white54)),
                              const SizedBox(height: 2),
                              Text('\$${_totalCost.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white, height: 1)),
                            ]),
                            const Spacer(),
                            Row(children: [
                              _MiniPill(label: 'Gallons',
                                  value: _totalGallons.toStringAsFixed(1),
                                  icon: Icons.water_drop_outlined),
                              const SizedBox(width: 6),
                              _MiniPill(label: 'Stops',
                                  value: '${_logs.length}',
                                  icon: Icons.pin_drop_outlined),
                              const SizedBox(width: 6),
                              _MiniPill(label: 'Pending',
                                  value: '$_pending',
                                  icon: Icons.receipt_long_outlined),
                            ]),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _blue)))
          else ...[
            // ── Stat cards ─────────────────────────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(children: [
                Expanded(child: _StatCard(icon: Icons.attach_money_rounded,
                    color: _green, label: 'Total Spend',
                    value: '\$${_totalCost.toStringAsFixed(2)}')),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(icon: Icons.water_drop_outlined,
                    color: _blue, label: 'Gallons',
                    value: _totalGallons.toStringAsFixed(1))),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(icon: Icons.pending_actions_outlined,
                    color: const Color(0xFF7C3AED), label: 'Pending',
                    value: '$_pending')),
              ]),
            )),

            // ── Search bar ─────────────────────────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border)),
                    child: TextField(
                      controller: _searchCtrl,
                      onSubmitted: (_) => _load(),
                      style: GoogleFonts.inter(fontSize: 13, color: _navy),
                      decoration: InputDecoration(
                        hintText: 'Search by Truck ID…',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 13, color: _grey.withOpacity(0.6)),
                        prefixIcon: const Icon(Icons.search,
                            size: 18, color: _grey),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border)),
                  child: const Icon(Icons.tune, size: 18, color: _grey),
                ),
              ]),
            )),

            // ── Section label ──────────────────────────────────────────────
            if (_logs.isNotEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text('RECENT PURCHASES', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _grey, letterSpacing: 0.8)),
              )),

            // ── List or empty ──────────────────────────────────────────────
            _logs.isEmpty
                ? SliverFillRemaining(child: _EmptyState(
                    onAdd: () => context.go('/fuel/add')))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate(
                      (_, i) => _FuelCard(fuel: _logs[i]),
                      childCount: _logs.length,
                    )),
                  ),
          ],
        ]),
      ),
    );
  }
}

// ── Mini stat pill ─────────────────────────────────────────────────────────────
class _MiniPill extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _MiniPill(
      {required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: Colors.white60),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: GoogleFonts.inter(fontSize: 8, color: Colors.white54)),
        ]),
      );
}

// ── Stat card ──────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _StatCard(
      {required this.icon, required this.color,
       required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 17, color: color)),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: _grey)),
        ]),
      );
}

// ── Fuel log card ──────────────────────────────────────────────────────────────
class _FuelCard extends StatelessWidget {
  final Map fuel;
  const _FuelCard({required this.fuel});

  @override
  Widget build(BuildContext context) {
    final cost     = _n(fuel['total_cost']);
    final gallons  = _n(fuel['gallons']);
    final ppg      = _n(fuel['price_per_gallon']);
    final station  = fuel['station_name'] as String? ??
                     fuel['vendor_name'] as String? ?? 'Fuel Stop';
    final city     = fuel['vendor_city'] as String? ?? '';
    final jur      = fuel['state'] as String? ??
                     fuel['jurisdiction'] as String? ?? '—';
    final truckId  = fuel['truck']?.toString().toUpperCase() ?? '—';
    final hasReceipt = fuel['receipt_image'] != null ||
                       fuel['has_receipt'] == true;
    final rawDate  = fuel['purchase_date'] as String? ?? '';
    final date     = rawDate.length >= 10
        ? DateFormat('MMM dd').format(DateTime.tryParse(rawDate) ?? DateTime.now())
        : rawDate;

    final id = fuel['id']?.toString() ?? '0';

    return GestureDetector(
      onTap: () => context.push(
        '/fuel/$id',
        extra: Map<String, dynamic>.from(fuel),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Container(width: 46, height: 46,
              decoration: BoxDecoration(
                  color: _green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.local_gas_station_rounded,
                  color: _green, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Truck #$truckId', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
              Text(city.isNotEmpty ? '$station • $jur' : '$station, $jur',
                  style: GoogleFonts.inter(fontSize: 12, color: _grey)),
              const SizedBox(height: 6),
              Row(children: [
                _Chip('${gallons.toStringAsFixed(2)} gal',
                    _blue.withOpacity(0.08), _blue),
                if (ppg > 0) ...[
                  const SizedBox(width: 6),
                  _Chip('\$${ppg.toStringAsFixed(3)}/gal',
                      Colors.orange.withOpacity(0.08),
                      Colors.orange.shade700),
                ],
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\$${cost.toStringAsFixed(2)}', style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w800, color: _green)),
              Text(date, style: GoogleFonts.inter(fontSize: 11, color: _grey)),
            ]),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(children: [
            Icon(hasReceipt
                ? Icons.receipt_long_outlined
                : Icons.upload_file_outlined,
                size: 15,
                color: hasReceipt ? _green : _grey),
            const SizedBox(width: 6),
            Text(hasReceipt ? 'Receipt attached' : 'Pending receipt',
                style: GoogleFonts.inter(fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: hasReceipt ? _green : _grey)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: hasReceipt
                    ? _green.withOpacity(0.08)
                    : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                  hasReceipt ? 'COMPLIANT' : 'PENDING',
                  style: GoogleFonts.inter(fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: hasReceipt ? _green : Colors.red.shade600)),
            ),
          ]),
        ]),
      ),      // Padding
    ),       // Container
    );       // GestureDetector
  }
}

Widget _Chip(String l, Color bg, Color text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
  child: Text(l, style: GoogleFonts.inter(
      fontSize: 10, fontWeight: FontWeight.w600, color: text)));

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 72, height: 72,
        decoration: BoxDecoration(color: _border,
            borderRadius: BorderRadius.circular(20)),
        child: Icon(Icons.local_gas_station_outlined,
            size: 34, color: Colors.grey.shade400)),
    const SizedBox(height: 14),
    Text('No fuel logs yet', style: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, color: _grey)),
    const SizedBox(height: 4),
    Text('Tap below to add your first entry',
        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400)),
    const SizedBox(height: 20),
    ElevatedButton.icon(
      onPressed: onAdd,
      style: ElevatedButton.styleFrom(backgroundColor: _navy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      icon: const Icon(Icons.add, color: Colors.white, size: 18),
      label: Text('Add Fuel Log', style: GoogleFonts.inter(
          fontWeight: FontWeight.w700, color: Colors.white)),
    ),
  ]));
}
