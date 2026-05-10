import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/font_ext.dart';
import 'report_detail_screen.dart';

const _navy    = Color(0xFF031634);
const _navy2   = Color(0xFF0D2952);
const _blue    = Color(0xFF0453CD);
const _green   = Color(0xFF16A34A);
const _amber   = Color(0xFFF59E0B);
const _surface = Color(0xFFF0F3FF);
const _border  = Color(0xFFDCE2F3);
const _grey    = Color(0xFF75777E);

double _n(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List   _reports     = [];
  Map?   _summary;        // /api/dashboard/summary/
  Map?   _iftaCurrent;   // /api/dashboard/ifta-current-quarter/
  bool   _loading     = true;
  bool   _generating  = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final iftaFuture    = ApiClient.getIftaReports();
      final summaryFuture = ApiClient.getDashboardSummary();
      Response? iftaCurrent;
      try { iftaCurrent = await ApiClient.getIftaCurrentQuarter(); } catch (_) {}

      final results = await Future.wait([iftaFuture, summaryFuture]);
      setState(() {
        _reports     = results[0].data['results'] ?? results[0].data ?? [];
        _summary     = results[1].data as Map;
        _iftaCurrent = iftaCurrent?.data as Map?;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }



  Future<void> _showGenerateSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GenerateReportSheet(onGenerated: _load),
    );
  }

  int get _filed  => _reports.where((r) => r['status'] == 'filed').length;
  int get _drafts => _reports.where((r) => (r['status'] ?? '') == 'draft').length;
  double get _totalTax => _reports.fold(0, (s, r) => s + _n(r['net_tax_due']));
  double get _totalMi  => _reports.fold(0, (s, r) => s + _n(r['total_miles']));

  @override
  Widget build(BuildContext context) {
    final s   = context.watch<LocaleProvider>().s;
    final pct = _reports.isEmpty ? 0.0 : _filed / _reports.length;
    return Scaffold(
      backgroundColor: _surface,
      body: RefreshIndicator(
        onRefresh: _load, color: _blue,
        child: CustomScrollView(slivers: [

          // ── Pinned SliverAppBar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: Row(children: [
              Container(padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.15))),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 14)),
              const SizedBox(width: 8),
              Text(s.iftaReports, style: context.af(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              Text('${_reports.length} total', style: context.af(fontSize: 11, color: Colors.white54)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showGenerateSheet,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.20))),
                  child: _generating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
            ]),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, _navy2])),
                  child: Stack(children: [
                   Positioned(right: -30, top: -30, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),
                   Positioned(right: 50, top: 70, child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: _blue.withOpacity(0.15)))),
                   SafeArea(child: Padding(
                     padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                     child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                       Row(children: [
                         Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                           Text(s.compliance, style: context.af(fontSize: 9, letterSpacing: 1.1, color: Colors.white54)),
                           const SizedBox(height: 2),
                           Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                             Container(width: 8, height: 8, decoration: BoxDecoration(color: pct >= 1 ? _green : _amber, shape: BoxShape.circle)),
                             const SizedBox(width: 6),
                             Text(pct >= 1 ? s.fullyCompliant : _reports.isEmpty ? s.noReports : s.inProgress, style: context.af(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                           ]),
                           Text('$_filed ${s.quartersFiledOf} ${_reports.length} Quarters Filed', style: context.af(fontSize: 12, color: Colors.white54)),
                         ]),
                         const Spacer(),
                         Row(children: [
                           _MiniPill(label: s.taxDue, value: '\$${_totalTax.toStringAsFixed(0)}', icon: Icons.account_balance_outlined),
                           const SizedBox(width: 6),
                           _MiniPill(label: s.miles, value: '${(_totalMi / 1000).toStringAsFixed(1)}k', icon: Icons.route_outlined),
                           const SizedBox(width: 6),
                           _MiniPill(label: s.drafts, value: '$_drafts', icon: Icons.pending_actions_outlined),
                         ]),
                       ]),
                     ]),
                   )),
                 ]),
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _blue)))
          else ...[

            // ── QTD Key Metrics ──────────────────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _buildQtdMetrics(),
            )),

            // ── MPG Warning Banner ───────────────────────────────────────
            if (_iftaCurrent != null && _n(_iftaCurrent!['average_mpg']) > 0 && _n(_iftaCurrent!['average_mpg']) < 5)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade500, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.dataQualityWarning, style: context.af(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red.shade700)),
                      const SizedBox(height: 2),
                      Text('${_iftaCurrent!["average_mpg"].toStringAsFixed(2)} ${s.abnormalMpgDetected}', style: context.af(fontSize: 11, color: Colors.red.shade600)),
                    ])),
                  ]),
                ),
              )),

            // ── Compliance Health ─────────────────────────────────────────
            if (_summary != null)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _ComplianceHealthCard(summary: _summary!),
              )),

            // ── Miles by Jurisdiction ─────────────────────────────────────
            if (_iftaCurrent != null && (_iftaCurrent!['jurisdictions'] as List?)?.isNotEmpty == true)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _JurisdictionChart(jurisdictions: List<Map>.from(_iftaCurrent!['jurisdictions'] as List), totalMiles: _n(_iftaCurrent!['total_miles'])),
              )),

            // ── Stat cards row ────────────────────────────────────────────
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                Expanded(child: _StatCard(icon: Icons.verified_outlined, color: _green, label: s.filed, value: '$_filed')),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(icon: Icons.edit_note_rounded, color: _amber, label: s.drafts, value: '$_drafts')),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(icon: Icons.attach_money_rounded, color: _blue, label: s.taxDue, value: '\$${_totalTax.toStringAsFixed(0)}')),
              ]),
            )),

            // ── Generate button if empty ──────────────────────────────
            if (_reports.isEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: EdgeInsets.fromLTRB(0, 8, 0, 24 + MediaQuery.of(context).padding.bottom),
                child: _EmptyState(onGenerate: _showGenerateSheet, generating: false),
              ))

            else ...[

              // ── Report History label ───────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.reportHistory, style: context.af(fontSize: 11, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.8)),
                    Text(s.allQuarterlyFilings, style: context.af(fontSize: 10, color: _grey)),
                  ]),
                  Text('${DateTime.now().year}', style: context.af(fontSize: 11, fontWeight: FontWeight.w600, color: _blue)),
                ]),
              )),

              // ── Report cards ──────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) => _ReportCard(report: _reports[i], onRefresh: _load),
                  childCount: _reports.length,
                )),
              ),
            ],
          ],

        ]),
      ),
    );
  }

  // ── QTD metrics builder ──────────────────────────────────────────────────
  Widget _buildQtdMetrics() {
    final s       = context.read<LocaleProvider>().s;
    final qm      = (_summary?['quarter_metrics'] as Map?) ?? {};
    final est     = (_summary?['ifta_estimate'] as Map?) ?? {};
    final miles   = _iftaCurrent != null ? _n(_iftaCurrent!['total_miles'])   : _n(qm['total_miles']);
    final gallons = _iftaCurrent != null ? _n(_iftaCurrent!['total_gallons']) : _n(qm['total_gallons']);
    final mpg     = _iftaCurrent != null ? _n(_iftaCurrent!['average_mpg'])   : (gallons > 0 ? miles / gallons : 0.0);
    final taxDue  = _iftaCurrent != null ? _n(_iftaCurrent!['net_tax_due'])   : _n(est['net_tax_due']);
    final qLabel  = _summary?['current_quarter'] ?? '';
    final mpgWarn = mpg > 0 && mpg < 5;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${s.qtdMetrics} · $qLabel', style: context.af(fontSize: 10, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.7)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _KpiTile(label: s.totalMiles, value: '${miles.toStringAsFixed(1)}', unit: 'mi', icon: Icons.route_outlined, color: _blue)),
        const SizedBox(width: 10),
        Expanded(child: _KpiTile(label: s.totalGallons, value: gallons.toStringAsFixed(1), unit: 'gal', icon: Icons.local_gas_station_outlined, color: const Color(0xFF06B6D4))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _KpiTile(label: s.avgMpg, value: mpg.toStringAsFixed(2), unit: '', icon: Icons.speed_rounded, color: mpgWarn ? Colors.red : const Color(0xFF7C3AED), warn: mpgWarn)),
        const SizedBox(width: 10),
        Expanded(child: _KpiTile(label: s.estTaxDue, value: '\$${taxDue.toStringAsFixed(2)}', unit: '', icon: Icons.account_balance_outlined, color: _navy, dark: true)),
      ]),
    ]);
  }
}

// ── KPI tile ─────────────────────────────────────────────────────────────────
class _KpiTile extends StatelessWidget {
  final String label, value, unit; final IconData icon; final Color color; final bool warn, dark;
  const _KpiTile({required this.label, required this.value, required this.unit, required this.icon, required this.color, this.warn = false, this.dark = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: dark ? _navy : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: dark ? _navy : _border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: dark ? Colors.white54 : color),
        const SizedBox(width: 5),
        Text(label, style: context.af(fontSize: 10, color: dark ? Colors.white60 : _grey)),
        if (warn) ...[const Spacer(), const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red)],
      ]),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(child: Text(value, style: context.af(fontSize: 20, fontWeight: FontWeight.w800, color: warn ? Colors.red : dark ? Colors.white : _navy), overflow: TextOverflow.ellipsis)),
        if (unit.isNotEmpty) ...[const SizedBox(width: 3), Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(unit, style: context.af(fontSize: 11, color: dark ? Colors.white54 : _grey)))],
      ]),
    ]),
  );
}

// ── Compliance Health card ────────────────────────────────────────────────────
class _ComplianceHealthCard extends StatelessWidget {
  final Map summary;
  const _ComplianceHealthCard({required this.summary});
  @override
  Widget build(BuildContext context) {
    final s  = context.watch<LocaleProvider>().s;
    final qm = (summary['quarter_metrics'] as Map?) ?? {};
    final missingReceipts  = (qm['missing_receipts']  as int?) ?? 0;
    final needsReview      = (qm['trips_needing_review'] as int?) ?? 0;
    final missingMileage   = (qm['trips_missing_mileage'] as int?) ?? 0;
    int issues = 0;
    if (missingReceipts > 0) issues++;
    if (needsReview > 0)     issues++;
    if (missingMileage > 0)  issues++;
    final pct = ((3 - issues) / 3 * 100).round();
    final checks = [
      (missingReceipts == 0, '$missingReceipts ${s.missingFuelReceipts}'),
      (needsReview == 0,     '$needsReview ${s.tripsNeedingReview}'),
      (missingMileage == 0,  '$missingMileage ${s.tripsMissingMileage}'),
      (true,                 s.odometerVerified),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(s.complianceHealth, style: context.af(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
          const Spacer(),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: pct >= 80 ? _green : _amber, width: 3)),
            child: Center(child: Text('$pct%', style: context.af(fontSize: 11, fontWeight: FontWeight.w800, color: pct >= 80 ? _green : _amber))),
          ),
        ]),
        const SizedBox(height: 12),
        ...checks.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(c.$1 ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded, size: 15, color: c.$1 ? _green : _amber),
            const SizedBox(width: 8),
            Text(c.$2, style: context.af(fontSize: 12, color: c.$1 ? _grey : _amber)),
          ]),
        )),
        const SizedBox(height: 10),
        Row(children: [
          _SumChip(label: s.missingReceipts, value: '$missingReceipts', warn: missingReceipts > 0),
          const SizedBox(width: 12),
          _SumChip(label: s.tripsForReview, value: '$needsReview', warn: needsReview > 0),
        ]),
      ]),
    );
  }
}

class _SumChip extends StatelessWidget {
  final String label, value; final bool warn;
  const _SumChip({required this.label, required this.value, this.warn = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: context.af(fontSize: 20, fontWeight: FontWeight.w800, color: warn ? _amber : _navy)),
    Text(label, style: context.af(fontSize: 10, color: _grey)),
  ]);
}

// ── Miles by Jurisdiction chart ───────────────────────────────────────────────
class _JurisdictionChart extends StatefulWidget {
  final List<Map> jurisdictions; final double totalMiles;
  const _JurisdictionChart({required this.jurisdictions, required this.totalMiles});
  @override
  State<_JurisdictionChart> createState() => _JurisdictionChartState();
}

class _JurisdictionChartState extends State<_JurisdictionChart> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final s       = context.watch<LocaleProvider>().s;
    final sorted  = [...widget.jurisdictions]..sort((a, b) => _n(b['miles']).compareTo(_n(a['miles'])));
    final visible = _showAll ? sorted : sorted.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(s.milesByJurisdiction, style: context.af(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
          const Spacer(),
          Text(s.currentQuarter, style: context.af(fontSize: 10, color: _grey)),
        ]),
        const SizedBox(height: 14),
        // ── Animated rows ─────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: Column(
            children: visible.map((j) {
              final miles  = _n(j['miles']);
              final tax    = _n(j['tax_due']);
              final pct    = widget.totalMiles > 0 ? (miles / widget.totalMiles).clamp(0.0, 1.0) : 0.0;
              final state  = j['state']?.toString() ?? '??';
              return Padding(padding: const EdgeInsets.only(bottom: 10), child:
                Row(children: [
                  SizedBox(width: 28, child: Text(state, style: context.af(fontSize: 12, fontWeight: FontWeight.w700, color: _navy))),
                  const SizedBox(width: 8),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: _border, valueColor: const AlwaysStoppedAnimation(_navy)))),
                  const SizedBox(width: 8),
                  SizedBox(width: 60, child: Text('${miles.toStringAsFixed(0)} mi', textAlign: TextAlign.right, style: context.af(fontSize: 11, color: _grey))),
                  SizedBox(width: 48, child: Text('\$${tax.toStringAsFixed(2)}', textAlign: TextAlign.right, style: context.af(fontSize: 11, fontWeight: FontWeight.w600, color: tax > 0 ? _blue : _grey))),
                ]),
              );
            }).toList(),
          ),
        ),
        // ── Show All / Hide button ────────────────────────────────────
        if (sorted.length > 4) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _showAll = !_showAll),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  _showAll ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 16, color: _blue,
                ),
                const SizedBox(width: 5),
                Text(
                  _showAll ? s.hide : '${s.showAllStates} ${sorted.length} States',
                  style: context.af(fontSize: 12, fontWeight: FontWeight.w700, color: _blue),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Mini pill ─────────────────────────────────────────────────────────────────
class _MiniPill extends StatelessWidget {
  final String label, value; final IconData icon;
  const _MiniPill({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.12))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.white60),
      const SizedBox(height: 2),
      Text(value, style: context.af(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
      Text(label, style: context.af(fontSize: 8, color: Colors.white54)),
    ]),
  );
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon; final Color color; final String label, value;
  const _StatCard({required this.icon, required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 17, color: color)),
      const SizedBox(height: 8),
      Text(value, style: context.af(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
      Text(label, style: context.af(fontSize: 10, color: _grey)),
    ]),
  );
}

// ── Report card ───────────────────────────────────────────────────────────────
class _ReportCard extends StatefulWidget {
  final Map report; final VoidCallback onRefresh;
  const _ReportCard({required this.report, required this.onRefresh});
  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _deleting = false;

  String _qLabel(int q) => const {1: 'Q1 · Jan – Mar', 2: 'Q2 · Apr – Jun', 3: 'Q3 · Jul – Sep', 4: 'Q4 · Oct – Dec'}[q] ?? 'Q$q';

  void _openDetail(BuildContext context) {
    final id = widget.report['id'];
    if (id == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReportDetailScreen(
        reportId: id is int ? id : int.parse(id.toString()),
        reportSummary: widget.report,
      ),
    ));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final s       = context.read<LocaleProvider>().s;
    final isFiled = (widget.report['status'] ?? '').toString().toLowerCase() == 'filed';
    if (isFiled) {
      _showInfoModal(context, s.deleteFailed, s.cannotDeleteFiled, isError: true);
      return;
    }

    final q       = widget.report['quarter'] as int? ?? 1;
    final year    = widget.report['year'] as int? ?? DateTime.now().year;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade500, size: 28)),
          const SizedBox(height: 16),
          Text(s.deleteReport, style: context.af(fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 8),
          Text('Q$q $year ${s.deleteReportConfirm}',
            textAlign: TextAlign.center, style: context.af(fontSize: 13, color: _grey, height: 1.4)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: _border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 13)),
              child: Text(s.cancel, style: context.af(fontWeight: FontWeight.w600, color: _navy)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0),
              child: Text(s.delete, style: context.af(fontWeight: FontWeight.w700, color: Colors.white)),
            )),
          ]),
        ])),
      ),
    );

    if (confirmed != true) return;
    await _doDelete(context);
  }

  Future<void> _doDelete(BuildContext context) async {
    final id = widget.report['id'];
    if (id == null) return;
    setState(() => _deleting = true);
    try {
      await ApiClient.deleteIftaReport(id is int ? id : int.parse(id.toString()));
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        final s = context.read<LocaleProvider>().s;
        _showInfoModal(context, s.deleteFailed, s.couldNotDeleteReport, isError: true);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showInfoModal(BuildContext context, String title, String msg, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 40, color: isError ? Colors.red.shade400 : _green),
          const SizedBox(height: 12),
          Text(title, style: context.af(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 6),
          Text(msg, textAlign: TextAlign.center, style: context.af(fontSize: 13, color: _grey)),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: _navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: Text(context.read<LocaleProvider>().s.ok, style: context.af(fontWeight: FontWeight.w700, color: Colors.white)),
          )),
        ])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s        = context.watch<LocaleProvider>().s;
    final status   = (widget.report['status'] ?? 'draft').toString().toLowerCase();
    final isReady  = status == 'ready' || status == 'ready_to_file' || status == 'validation_complete';
    final isFiled  = status == 'filed';
    final quarter  = widget.report['quarter'] as int? ?? 1;
    final year     = widget.report['year'] as int? ?? DateTime.now().year;
    final taxDue   = _n(widget.report['net_tax_due']);
    final miles    = _n(widget.report['total_miles']);
    final juris    = (widget.report['lines'] as List?)?.length ?? (widget.report['jurisdiction_count'] as int? ?? 0);
    final netTax   = _n(widget.report['net_tax_due']);
    final Color statusColor = isFiled ? _green : isReady ? _blue : _amber;
    final String statusLabel = isFiled ? s.filedLabel : isReady ? s.readyToFileLabel : s.draftLabel;

    return Dismissible(
      key: ValueKey(widget.report['id']),
      direction: isFiled ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmDelete(context);
        return false; // always false — we control deletion manually
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red.shade500, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(context.read<LocaleProvider>().s.delete, style: context.af(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
      child: AnimatedOpacity(
        opacity: _deleting ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
          child: Column(children: [
            // ── Header ────────────────────────────────────────────────
            Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: statusColor.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
                child: Icon(isFiled ? Icons.check_circle_outline : isReady ? Icons.task_alt_outlined : Icons.edit_note_rounded, color: statusColor, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_qLabel(quarter), style: context.af(fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
                Text('$year', style: context.af(fontSize: 12, color: _grey)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                child: Text(statusLabel, style: context.af(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.3)),
              ),
              // Delete icon button
              if (!isFiled) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _deleting ? null : () => _confirmDelete(context),
                  child: Container(width: 32, height: 32,
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: _deleting
                        ? const Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
                        : Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade400)),
                ),
              ],
            ])),

            // ── Stats row ──────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _MiniStat(label: s.totalMiles, value: '${miles.toStringAsFixed(0)} mi'),
                _Divider(),
                _MiniStat(label: s.jurisdictions, value: '$juris'),
                _Divider(),
                _MiniStat(label: s.taxDue, value: '\$${taxDue.toStringAsFixed(2)}', highlight: taxDue > 0),
                _Divider(),
                _MiniStat(label: s.netTax, value: '\$${netTax.toStringAsFixed(2)}', highlight: netTax > 0),
              ]),
            ),

            // ── Action row ─────────────────────────────────────────────
            if (!isFiled)
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => _openDetail(context),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: _border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 11)),
                  child: Text(s.details, style: context.af(fontWeight: FontWeight.w600, color: _navy, fontSize: 13)),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () => _openDetail(context),
                  style: ElevatedButton.styleFrom(backgroundColor: _navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 11), elevation: 0),
                  child: Text(isReady ? s.readyToFile : s.resume, style: context.af(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
                )),
              ]))
            else
              GestureDetector(
                onTap: () => _openDetail(context),
                child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Ref: #IFT-${widget.report['id'] ?? '—'}', style: context.af(fontSize: 12, color: _grey)),
                  Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
                ])),
              ),
          ]),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value; final bool highlight;
  const _MiniStat({required this.label, required this.value, this.highlight = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: context.af(fontSize: 13, fontWeight: FontWeight.w700, color: highlight ? _blue : _navy)),
    const SizedBox(height: 2),
    Text(label, style: context.af(fontSize: 9, color: _grey, letterSpacing: 0.2)),
  ]);
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 28, color: _border);
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onGenerate; final bool generating;
  const _EmptyState({required this.onGenerate, required this.generating});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(20)), child: Icon(Icons.bar_chart_rounded, size: 34, color: Colors.grey.shade400)),
        const SizedBox(height: 14),
        Text(s.noReportsYet, style: context.af(fontSize: 15, fontWeight: FontWeight.w600, color: _grey)),
        const SizedBox(height: 4),
        Text(s.generateFirstReport, textAlign: TextAlign.center, style: context.af(fontSize: 12, color: Colors.grey.shade400)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: generating ? null : onGenerate,
          style: ElevatedButton.styleFrom(backgroundColor: _navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          icon: generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.add, color: Colors.white, size: 18),
          label: Text(s.generateQReport, style: context.af(fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
    );
  }
}

// ── Generate Report Bottom Sheet ──────────────────────────────────────────────
class _GenerateReportSheet extends StatefulWidget {
  final VoidCallback onGenerated;
  const _GenerateReportSheet({required this.onGenerated});
  @override
  State<_GenerateReportSheet> createState() => _GenerateReportSheetState();
}

class _GenerateReportSheetState extends State<_GenerateReportSheet> {
  List<Map> _quarters   = [];
  bool       _loading   = true;
  bool       _generating = false;
  String?    _error;
  Map?       _selected;     // { year, quarter }

  static const _qNames = {1: 'Q1 · Jan – Mar', 2: 'Q2 · Apr – Jun', 3: 'Q3 · Jul – Sep', 4: 'Q4 · Oct – Dec'};

  @override
  void initState() { super.initState(); _loadQuarters(); }

  Future<void> _loadQuarters() async {
    try {
      final res = await ApiClient.getAvailableQuarters();
      final list = (res.data as List).cast<Map>();
      setState(() {
        _quarters = list;
        _selected = list.isNotEmpty ? list.first : null;
      });
    } catch (_) {
      setState(() => _error = 'Could not load available quarters.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    if (_selected == null) return;
    setState(() { _generating = true; _error = null; });
    try {
      await ApiClient.generateIftaReport({
        'year':    _selected!['year'],
        'quarter': _selected!['quarter'],
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onGenerated();
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']
          ?? e.response?.data?['error']
          ?? e.message
          ?? 'Failed to generate report.';
      if (mounted) setState(() => _error = msg.toString());
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to generate report: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s       = context.watch<LocaleProvider>().s;
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 4), child:
          Row(children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _navy.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add_chart_rounded, color: _navy, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.generateIftaReport, style: context.af(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
              Text(s.selectQuarterFromTrips, style: context.af(fontSize: 12, color: _grey)),
            ])),
            IconButton(icon: const Icon(Icons.close_rounded, color: _grey), onPressed: () => Navigator.pop(context)),
          ]),
        ),

        const Divider(height: 20),

        if (_loading)
          const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _blue))
        else if (_quarters.isEmpty)
          Padding(padding: const EdgeInsets.all(32), child: Column(children: [
            Icon(Icons.route_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(s.noCompletedTrips, style: context.af(fontWeight: FontWeight.w700, color: _navy)),
            const SizedBox(height: 4),
            Text(s.completeTripsFirst, textAlign: TextAlign.center, style: context.af(fontSize: 12, color: _grey)),
          ]))
        else ...[
          // Quarter picker list
          Flexible(child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _quarters.length,
            itemBuilder: (_, i) {
              final q = _quarters[i];
              final qNum  = q['quarter'] as int;
              final year  = q['year'] as int;
              final label = _qNames[qNum] ?? 'Q$qNum';
              final isSelected = _selected == q;
              return GestureDetector(
                onTap: () => setState(() => _selected = q),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? _navy : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? _navy : _border, width: isSelected ? 0 : 1),
                    boxShadow: isSelected ? [BoxShadow(color: _navy.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 3))] : [],
                  ),
                  child: Row(children: [
                    Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.12) : _blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text('Q$qNum', style: context.af(fontSize: 13, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : _blue)))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: context.af(fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : _navy)),
                      Text('$year', style: context.af(fontSize: 12, color: isSelected ? Colors.white60 : _grey)),
                    ])),
                    if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  ]),
                ),
              );
            },
          )),

          // Error
          if (_error != null)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child:
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                child: Row(children: [
                  Icon(Icons.error_outline, size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: context.af(fontSize: 12, color: Colors.red.shade700))),
                ]),
              ),
            ),

          // Generate button
          Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom), child:
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: (_selected == null || _generating) ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                disabledBackgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
              ),
              icon: _generating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              label: Text(
                _generating ? s.generating
                    : _selected != null
                        ? '${s.generateQReport} Q${_selected!["quarter"]} ${_selected!["year"]}'
                        : s.selectQuarter,
                style: context.af(fontSize: 15, fontWeight: FontWeight.w700, color: _generating || _selected == null ? _grey : Colors.white),
              ),
            )),
          ),
        ],
      ]),
    );
  }
}
