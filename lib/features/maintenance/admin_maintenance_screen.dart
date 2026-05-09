import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_client.dart';

const _navy  = Color(0xFF031634);
const _navy2 = Color(0xFF0A2347);
const _cyan  = Color(0xFF06B6D4);
const _blue  = Color(0xFF0453CD);
const _surf  = Color(0xFFF0F3FA);

// ── Helpers ───────────────────────────────────────────────────────────────────
Color _priColor(String? p) => switch (p) {
      'critical' => const Color(0xFFEF4444),
      'high'     => const Color(0xFFF97316),
      'medium'   => const Color(0xFFF59E0B),
      _          => const Color(0xFF22C55E),
    };

Color _stsColor(String? s) => switch (s) {
      'completed'   => const Color(0xFF22C55E),
      'in_progress' => const Color(0xFF3B82F6),
      'cancelled'   => const Color(0xFF9CA3AF),
      _             => const Color(0xFF94A3B8),
    };

String _stsLabel(String? s) => switch (s) {
      'pending'     => 'Pending',
      'in_progress' => 'In Progress',
      'completed'   => 'Completed',
      'cancelled'   => 'Cancelled',
      _             => s ?? '—',
    };

double _n(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class AdminMaintenanceScreen extends StatefulWidget {
  const AdminMaintenanceScreen({super.key});
  @override
  State<AdminMaintenanceScreen> createState() => _AdminMaintenanceScreenState();
}

class _AdminMaintenanceScreenState extends State<AdminMaintenanceScreen> {
  List    _records = [];
  bool    _loading = true;
  String? _error;
  String  _filterStatus   = 'all';
  String  _filterPriority = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.dio.get('/api/maintenance/mobile/');
      final d   = res.data;
      setState(() => _records = d is List ? d : (d['results'] ?? []));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List get _filtered => _records.where((r) {
    final okSts = _filterStatus   == 'all' || r['status']   == _filterStatus;
    final okPri = _filterPriority == 'all' || r['priority'] == _filterPriority;
    return okSts && okPri;
  }).toList();

  // stats
  int    get _total     => _records.length;
  int    get _pending   => _records.where((r) => r['status'] == 'pending').length;
  int    get _inProg    => _records.where((r) => r['status'] == 'in_progress').length;
  int    get _completed => _records.where((r) => r['status'] == 'completed').length;
  int    get _critical  => _records.where((r) => r['priority'] == 'critical').length;
  double get _totalCost => _records.fold(0, (s, r) => s + _n(r['cost']));

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: _surf,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _cyan,
        child: CustomScrollView(slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 80,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => context.go('/dashboard'),
            ),
            title: Row(children: [
              const Icon(Icons.build_rounded, color: _cyan, size: 18),
              const SizedBox(width: 8),
              Text('Maintenance',
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ]),
            actions: [
              // Add button
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () async {
                    await context.push('/maintenance/add');
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: _cyan.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _cyan.withValues(alpha: 0.4))),
                    child: Row(children: [
                      const Icon(Icons.add_rounded, size: 15, color: _cyan),
                      const SizedBox(width: 4),
                      Text('Add',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _cyan)),
                    ]),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white70, size: 20),
                onPressed: _load,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_navy2, _navy, Color(0xFF0D3A6B)],
                  ),
                ),
              ),
            ),
          ),

          // ── Stats cards ──────────────────────────────────────────────────────
          if (!_loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  _StatCard(label: 'Total',   value: '$_total',     color: _cyan),
                  const SizedBox(width: 8),
                  _StatCard(label: 'Pending', value: '$_pending',   color: const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _StatCard(label: 'Active',  value: '$_inProg',    color: const Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  _StatCard(label: 'Done',    value: '$_completed', color: const Color(0xFF22C55E)),
                ]),
              ),
            ),

          // ── Total cost banner ─────────────────────────────────────────────
          if (!_loading && _totalCost > 0)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0453CD), Color(0xFF031DAA)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: _blue.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Text('Total Maintenance Cost',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('\$${_totalCost.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ]),
              ),
            ),

          // ── Filter chips ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final s in [
                        ('all', 'All'),
                        ('pending', 'Pending'),
                        ('in_progress', 'In Progress'),
                        ('completed', 'Completed'),
                        ('cancelled', 'Cancelled'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: s.$2,
                            selected: _filterStatus == s.$1,
                            onTap: () =>
                                setState(() => _filterStatus = s.$1),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  // Priority filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final p in [
                        ('all', 'All Priority'),
                        ('critical', 'Critical'),
                        ('high', 'High'),
                        ('medium', 'Medium'),
                        ('low', 'Low'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: p.$2,
                            selected: _filterPriority == p.$1,
                            color: p.$1 != 'all'
                                ? _priColor(p.$1)
                                : null,
                            onTap: () =>
                                setState(() => _filterPriority = p.$1),
                          ),
                        ),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // ── List ──────────────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: _cyan)))
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Failed to load',
                      style: GoogleFonts.inter(fontSize: 15)),
                  const SizedBox(height: 8),
                  FilledButton(
                      onPressed: _load,
                      style: FilledButton.styleFrom(
                          backgroundColor: _navy),
                      child: const Text('Retry')),
                ]),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.build_outlined,
                      size: 56, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 16),
                  Text('No records found',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8))),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await context.push('/maintenance/edit',
                          extra: filtered[i]);
                      _load();
                    },
                    child: _AdminRecordCard(record: filtered[i]),
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: _navy.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 0.3)),
          ]),
        ),
      );
}

// ── Filter chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected,
      this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? _navy;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : const Color(0xFFE2E8F0)),
          boxShadow: selected
              ? [BoxShadow(color: c.withValues(alpha: 0.25), blurRadius: 6)]
              : [],
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF64748B))),
      ),
    );
  }
}

// ── Record card ───────────────────────────────────────────────────────────────
class _AdminRecordCard extends StatelessWidget {
  final Map record;
  const _AdminRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final pri = _priColor(record['priority']);
    final sts = _stsColor(record['status']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _navy.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Priority bar
          Container(
            width: 5,
            decoration: BoxDecoration(
                color: pri,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16))),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Title row
                Row(children: [
                  Expanded(
                    child: Text(record['title'] ?? '—',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B))),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                        color: sts.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(_stsLabel(record['status']),
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: sts)),
                  ),
                  // Priority badge
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: pri.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(record['priority'] ?? '—',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: pri)),
                  ),
                ]),
                const SizedBox(height: 6),
                // Truck + type
                Row(children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(record['truck_unit'] ?? '—',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8))),
                  const SizedBox(width: 10),
                  const Icon(Icons.build_outlined,
                      size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                        record['maintenance_type_display'] ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8))),
                  ),
                  if (record['cost'] != null)
                    Text(
                        '\$${double.tryParse(record['cost'].toString())?.toStringAsFixed(2) ?? record['cost']}',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: _navy)),
                ]),
                // Driver + date row
                const SizedBox(height: 4),
                Row(children: [
                  if (record['driver_name'] != null) ...[
                    const Icon(Icons.person_outline_rounded,
                        size: 12, color: Color(0xFFCBD5E1)),
                    const SizedBox(width: 4),
                    Text(record['driver_name'],
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFFCBD5E1))),
                    const SizedBox(width: 10),
                  ],
                  if (record['date_performed'] != null) ...[
                    const Icon(Icons.calendar_today_outlined,
                        size: 11, color: Color(0xFFCBD5E1)),
                    const SizedBox(width: 4),
                    Text(record['date_performed'],
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFFCBD5E1))),
                  ],
                  // Invoice badge
                  if (record['invoice_file'] != null) ...[
                    const Spacer(),
                    const Icon(Icons.receipt_long_rounded,
                        size: 13, color: _cyan),
                    const SizedBox(width: 3),
                    Text('Invoice',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: _cyan,
                            fontWeight: FontWeight.w600)),
                  ],
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
