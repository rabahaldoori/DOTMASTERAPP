import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/api_client.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/font_ext.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _navy   = Color(0xFF031634);
const _blue   = Color(0xFF0453CD);
const _cyan   = Color(0xFF06B6D4);
const _surface = Color(0xFFF0F4FA);
const _white  = Colors.white;
const _grey   = Color(0xFF64748B);
const _border = Color(0xFFDCE2F3);
const _green  = Color(0xFF15803D);
const _red    = Color(0xFFB91C1C);

class InspectionHistoryScreen extends StatefulWidget {
  final bool isAdmin;
  const InspectionHistoryScreen({super.key, this.isAdmin = false});
  @override
  State<InspectionHistoryScreen> createState() => _State();
}

class _State extends State<InspectionHistoryScreen> {
  List<Map<String, dynamic>> _inspections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = widget.isAdmin
          ? await ApiClient.listAdminInspections()
          : await ApiClient.listInspections();
      final raw = res.data;
      final List list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        list = (raw['results'] ?? raw['data'] ?? []) as List;
      } else {
        list = [];
      }
      if (mounted) {
        setState(() {
          _inspections = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final s = context.read<LocaleProvider>().s;
        setState(() { _error = s.failedToLoadTapRetry; _loading = false; });
      }
    }
  }

  // Group inspections by date string
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final s = context.read<LocaleProvider>().s;
    final map = <String, List<Map<String, dynamic>>>{};
    for (final insp in _inspections) {
      final raw = insp['submitted_at']?.toString() ?? '';
      final dt = DateTime.tryParse(raw)?.toLocal();
      final key = dt != null
          ? _formatDateKey(dt, s)
          : 'Unknown Date';
      map.putIfAbsent(key, () => []).add(insp);
    }
    return map;
  }

  String _formatDateKey(DateTime dt, dynamic s) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);
    if (d == today)                           return s.today;
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${_month(dt.month)} ${dt.day}, ${dt.year}';
  }

  String _month(int m) => const ['','Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'][m];

  String _timeStr(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _blue)))
          else if (_error != null)
            SliverFillRemaining(child: _buildError())
          else if (_inspections.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  _buildGroupedList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedList() {
    final groups = _grouped;
    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      // Date header
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Row(children: [
          Text(entry.key, style: context.af(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _grey, letterSpacing: 0.5)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: _border)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${entry.value.length}',
                style: context.af(fontSize: 11,
                    fontWeight: FontWeight.w700, color: _blue)),
          ),
        ]),
      ));
      // Cards
      for (final insp in entry.value) {
        widgets.add(_InspectionCard(
            insp: insp,
            timeStr: _timeStr(insp['submitted_at']?.toString()),
            showDriver: widget.isAdmin));
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
  }

  // ── computed stats ──────────────────────────────────────────────────────────
  int get _totalCount   => _inspections.length;
  int get _passedCount  => _inspections.where((i) => (i['failed_items'] ?? 0) == 0).length;
  int get _failedCount  => _inspections.where((i) => (i['failed_items'] ?? 0) > 0).length;
  int get _todayCount {
    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);
    return _inspections.where((i) {
      final dt = DateTime.tryParse(i['submitted_at']?.toString() ?? '')?.toLocal();
      if (dt == null) return false;
      return DateTime(dt.year, dt.month, dt.day) == d0;
    }).length;
  }

  Widget _buildAppBar() {
    final s = context.read<LocaleProvider>().s;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 230,
      backgroundColor: _navy,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: _white, size: 16),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.refresh_rounded, color: _white, size: 18),
          ),
          onPressed: _load,
          tooltip: s.retry,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF020D1F), Color(0xFF0A2550), Color(0xFF0453CD)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            // Decorative orbs
            Positioned(right: -30, top: -30,
              child: Container(width: 150, height: 150,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _cyan.withValues(alpha: 0.08)))),
            Positioned(left: -20, bottom: 30,
              child: Container(width: 90, height: 90,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _blue.withValues(alpha: 0.10)))),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Badge + title
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cyan.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _cyan.withValues(alpha: 0.35))),
                        child: Text(widget.isAdmin ? 'ADMIN' : 'DRIVER',
                            style: context.af(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: _cyan, letterSpacing: 0.8)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.fact_check_rounded,
                            color: _white, size: 18)),
                    ]),
                    const SizedBox(height: 6),
                    Text(widget.isAdmin ? s.allInspections : s.inspectionHistory,
                        style: context.af(
                            fontSize: 22, fontWeight: FontWeight.w900,
                            color: _white, letterSpacing: -0.3)),
                    const SizedBox(height: 16),
                    // ── Stats row ─────────────────────────────────────────
                    if (!_loading) Row(children: [
                      _HeaderStat(label: s.totalInspections,  value: '$_totalCount',  color: _white),
                      const SizedBox(width: 8),
                      _HeaderStat(label: s.passed, value: '$_passedCount', color: const Color(0xFF4ADE80)),
                      const SizedBox(width: 8),
                      _HeaderStat(label: s.failed, value: '$_failedCount', color: const Color(0xFFF87171)),
                      const SizedBox(width: 8),
                      _HeaderStat(label: s.today,  value: '$_todayCount',  color: const Color(0xFFFBBF24)),
                    ]),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildError() {
    final s = context.read<LocaleProvider>().s;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(_error!, style: context.af(color: _grey)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(backgroundColor: _blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text(s.retry, style: context.af(color: _white))),
      ]),
    );
  }

  Widget _buildEmpty() {
    final s = context.read<LocaleProvider>().s;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.fact_check_outlined, size: 40, color: _blue)),
        const SizedBox(height: 18),
        Text(s.noInspectionsYet, style: context.af(
            fontSize: 18, fontWeight: FontWeight.w700, color: _navy)),
        const SizedBox(height: 6),
        Text(s.completeFirstInspection,
            textAlign: TextAlign.center,
            style: context.af(fontSize: 13, color: _grey, height: 1.5)),
      ]),
    );
  }
}

// ── Single inspection card ─────────────────────────────────────────────────────
class _InspectionCard extends StatelessWidget {
  final Map<String, dynamic> insp;
  final String timeStr;
  final bool showDriver;
  const _InspectionCard({required this.insp, required this.timeStr, this.showDriver = false});

  @override
  Widget build(BuildContext context) {
    final s        = context.read<LocaleProvider>().s;
    final passed   = (insp['passed_items'] ?? 0) as int;
    final failed   = (insp['failed_items'] ?? 0) as int;
    final total    = (insp['total_items'] ?? passed + failed) as int;
    final typeRaw  = (insp['type_display'] ?? insp['inspection_type'] ?? '').toString();
    final typeLabel = typeRaw.replaceAll('_', ' ').toUpperCase();
    final inspNum  = insp['inspection_number'] ?? '#${insp['id']}';
    final allPassed = failed == 0;
    final score    = total > 0 ? ((passed / total) * 100).round() : 100;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/inspection-detail', extra: insp);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: allPassed
              ? const Color(0xFF86EFAC).withValues(alpha: 0.6)
              : const Color(0xFFFCA5A5).withValues(alpha: 0.6)),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Top row: type badge + time + status dot
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(typeLabel, style: context.af(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: _blue, letterSpacing: 0.6)),
              ),
              const Spacer(),
              if (timeStr.isNotEmpty) ...[
                const Icon(Icons.schedule_rounded, size: 13, color: _grey),
                const SizedBox(width: 4),
                Text(timeStr, style: context.af(
                    fontSize: 12, color: _grey, fontWeight: FontWeight.w500)),
                const SizedBox(width: 10),
              ],
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: allPassed ? _green : _red)),
            ]),
            const SizedBox(height: 12),

            // Inspection number + truck
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: allPassed
                        ? [const Color(0xFF14532D), _green]
                        : [const Color(0xFF7F1D1D), _red],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(13)),
                child: Icon(
                  allPassed ? Icons.verified_rounded : Icons.warning_rounded,
                  color: _white, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$inspNum', style: context.af(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
                if (showDriver && insp['driver_name'] != null)
                  Text(insp['driver_name'].toString(), style: context.af(
                      fontSize: 12, color: _blue, fontWeight: FontWeight.w600))
                else if (insp['truck'] != null)
                  Text('${s.truck} #${insp['truck']}', style: context.af(
                      fontSize: 12, color: _grey, fontWeight: FontWeight.w500)),
                if (showDriver && insp['truck'] != null)
                  Text('${s.truck} #${insp['truck']}', style: context.af(
                      fontSize: 11, color: _grey, fontWeight: FontWeight.w400)),
              ])),
              // Score badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: allPassed
                      ? _green.withValues(alpha: 0.10)
                      : _red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12)),
                child: Text('$score%', style: context.af(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: allPassed ? _green : _red)),
              ),
            ]),

            const SizedBox(height: 14),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100, minHeight: 6,
                backgroundColor: const Color(0xFFDCE2F3),
                valueColor: AlwaysStoppedAnimation(
                    allPassed ? _green : _red)),
            ),

            const SizedBox(height: 10),
            // Stats row
            Row(children: [
              _Stat(Icons.check_circle_rounded, '$passed ${s.passed}', _green),
              const SizedBox(width: 16),
              _Stat(Icons.cancel_rounded, '$failed ${s.failed}', _red),
              const SizedBox(width: 16),
              _Stat(Icons.checklist_rounded, '$total ${s.totalInspections}', _grey),
            ]),
          ]),
        ),
      ),
    );
  }

}


// ── Tiny stat chip ─────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Stat(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 4),
    Text(label, style: context.af(
        fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  ]);
}

// ── Header stat bubble ─────────────────────────────────────────────────────────
class _HeaderStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _HeaderStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(children: [
        Text(value, style: context.af(
            fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: context.af(
            fontSize: 10, fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.60))),
      ]),
    ),
  );
}

