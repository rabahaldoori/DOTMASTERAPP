import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_client.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _navy    = Color(0xFF031634);
const _navy2   = Color(0xFF0A2550);
const _cyan    = Color(0xFF06B6D4);
const _surface = Color(0xFFF0F3FF);

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

// ── Screen ────────────────────────────────────────────────────────────────────
class DriverMaintenanceScreen extends StatefulWidget {
  const DriverMaintenanceScreen({super.key});
  @override
  State<DriverMaintenanceScreen> createState() =>
      _DriverMaintenanceScreenState();
}

class _DriverMaintenanceScreenState extends State<DriverMaintenanceScreen> {
  List    _records = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  // ── Computed stats ────────────────────────────────────────────────────────
  int get _pending   => _records.where((r) => r['status'] == 'pending').length;
  int get _completed => _records.where((r) => r['status'] == 'completed').length;
  int get _critical  => _records.where((r) => r['priority'] == 'critical').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _cyan,
        child: CustomScrollView(slivers: [
          // ── Pinned header ──────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 80,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: Row(children: [
              const Icon(Icons.build_rounded, color: _cyan, size: 18),
              const SizedBox(width: 8),
              Text('Maintenance',
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const Spacer(),
              _HeaderBtn(
                icon: Icons.add_rounded,
                label: 'Add',
                onTap: () async {
                  await context.push('/driver-maintenance/add');
                  _load();
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white70, size: 20),
                onPressed: _load,
              ),
            ]),
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

          // ── Stats row ──────────────────────────────────────────────────────
          if (!_loading && _records.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  _StatChip(label: 'Total',     value: '${_records.length}', color: _cyan),
                  const SizedBox(width: 8),
                  _StatChip(label: 'Pending',   value: '$_pending',   color: const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  _StatChip(label: 'Done',      value: '$_completed', color: const Color(0xFF22C55E)),
                  if (_critical > 0) ...[
                    const SizedBox(width: 8),
                    _StatChip(label: 'Critical', value: '$_critical', color: const Color(0xFFEF4444)),
                  ],
                ]),
              ),
            ),

          // ── Body ──────────────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: _cyan)),
            )
          else if (_error != null)
            SliverFillRemaining(child: _buildError())
          else if (_records.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _RecordCard(
                    record: _records[i],
                    onEdit: () async {
                      await context.push(
                          '/driver-maintenance/edit',
                          extra: _records[i]);
                      _load();
                    },
                  ),
                  childCount: _records.length,
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text('Failed to load',
              style: GoogleFonts.inter(fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: _navy),
              child: const Text('Retry')),
        ]),
      );

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: _navy.withValues(alpha: 0.08),
                      blurRadius: 20)
                ]),
            child: const Icon(Icons.build_outlined,
                size: 48, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 20),
          Text('No maintenance records yet',
              style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          Text('Tap "Add" to report an issue',
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFFCBD5E1))),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              await context.push('/driver-maintenance/add');
              _load();
            },
            style: FilledButton.styleFrom(
                backgroundColor: _navy,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14)),
            icon: const Icon(Icons.add, size: 18),
            label: Text('Report Maintenance',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

// ── Header add button ─────────────────────────────────────────────────────────
class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: _cyan.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _cyan.withValues(alpha: 0.4), width: 1)),
          child: Row(children: [
            Icon(icon, size: 15, color: _cyan),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _cyan)),
          ]),
        ),
      );
}

// ── Stat chip ─────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: _navy.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]),
          child: Column(children: [
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8))),
          ]),
        ),
      );
}

// ── Record Card ───────────────────────────────────────────────────────────────
class _RecordCard extends StatelessWidget {
  final Map          record;
  final VoidCallback onEdit;
  const _RecordCard({required this.record, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final pri = _priColor(record['priority']);
    final sts = _stsColor(record['status']);

    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onEdit(); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: _navy.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4))
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
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: Color(0xFFCBD5E1)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.directions_car_outlined,
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
                  if (record['date_performed'] != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 11, color: Color(0xFFCBD5E1)),
                      const SizedBox(width: 4),
                      Text(record['date_performed'],
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFFCBD5E1))),
                    ]),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
