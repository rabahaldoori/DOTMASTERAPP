import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _navy    = Color(0xFF031634);
const _blue    = Color(0xFF0453CD);
const _cyan    = Color(0xFF06B6D4);
const _surface = Color(0xFFF0F4FA);
const _white   = Colors.white;
const _grey    = Color(0xFF64748B);
const _border  = Color(0xFFDCE2F3);
const _green   = Color(0xFF15803D);
const _red     = Color(0xFFB91C1C);

class InspectionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> insp;
  const InspectionDetailScreen({super.key, required this.insp});

  @override
  Widget build(BuildContext context) {
    final passed    = (insp['passed_items'] ?? 0) as int;
    final failed    = (insp['failed_items'] ?? 0) as int;
    final total     = (insp['total_items'] ?? passed + failed) as int;
    final allPassed = failed == 0;
    final score     = total > 0 ? ((passed / total) * 100).round() : 100;
    final inspNum   = insp['inspection_number'] ?? '#${insp['id']}';

    // Parse checklist_data → group by category
    final rawChecklist = insp['checklist_data'];
    final List<Map<String, dynamic>> items = rawChecklist is List
        ? rawChecklist.cast<Map<String, dynamic>>()
        : [];
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final cat = item['category']?.toString() ?? 'General';
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    // Parse issues
    final rawIssues = insp['issues'];
    final List<Map<String, dynamic>> issues = rawIssues is List
        ? rawIssues.cast<Map<String, dynamic>>()
        : [];

    return Scaffold(
      backgroundColor: _surface,
      body: CustomScrollView(
        slivers: [
          // ── App bar ─────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: _white, size: 16)),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF020D1F), Color(0xFF0A2550), Color(0xFF0453CD)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Stack(children: [
                  Positioned(right: -20, top: -20,
                    child: Container(width: 150, height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _cyan.withOpacity(0.07)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cyan.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _cyan.withOpacity(0.35))),
                        child: Text('INSPECTION REPORT', style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: _cyan, letterSpacing: 0.8)),
                      ),
                      const SizedBox(height: 6),
                      Text('$inspNum', style: GoogleFonts.inter(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: _white, letterSpacing: -0.3)),
                      const SizedBox(height: 4),
                      Text(
                        allPassed ? '✅  All Clear — Vehicle Passed' : '⚠️  $failed Item${failed == 1 ? '' : 's'} Need Attention',
                        style: GoogleFonts.inter(fontSize: 13,
                            color: allPassed ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                            fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            sliver: SliverList(delegate: SliverChildListDelegate([
              // ── Score card ─────────────────────────────────────────────────
              _Card(child: Column(children: [
                Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: allPassed
                            ? [const Color(0xFF14532D), _green]
                            : [const Color(0xFF7F1D1D), _red],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(15)),
                    child: Icon(
                      allPassed ? Icons.verified_rounded : Icons.warning_rounded,
                      color: _white, size: 28)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Compliance Score', style: GoogleFonts.inter(
                        fontSize: 12, color: _grey, fontWeight: FontWeight.w500)),
                    Text('$score%', style: GoogleFonts.inter(
                        fontSize: 32, fontWeight: FontWeight.w900,
                        color: allPassed ? _green : _red, height: 1.1)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _SmallBadge('$passed Passed', _green),
                    const SizedBox(height: 4),
                    _SmallBadge('$failed Failed', _red),
                  ]),
                ]),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: score / 100, minHeight: 10,
                    backgroundColor: _border,
                    valueColor: AlwaysStoppedAnimation(allPassed ? _green : _red))),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _StatBox(Icons.check_circle_rounded, '$passed', 'Passed', _green),
                  _Divider(),
                  _StatBox(Icons.cancel_rounded, '$failed', 'Failed', _red),
                  _Divider(),
                  _StatBox(Icons.checklist_rounded, '$total', 'Total', _grey),
                ]),
              ])),
              const SizedBox(height: 12),

              // ── Meta card ──────────────────────────────────────────────────
              _Card(child: Column(children: [
                if (insp['driver_name'] != null)
                  _Row('Driver', insp['driver_name'].toString(), _blue),
                if (insp['truck_number'] != null && insp['truck_number'] != '—')
                  _Row('Truck', insp['truck_number'].toString(), _navy),
                if (insp['inspection_type'] != null)
                  _Row('Type', (insp['type_display'] ?? insp['inspection_type']).toString().replaceAll('_', ' '), _grey),
                _Row('Status', (insp['status_display'] ?? insp['status'] ?? 'Submitted').toString(), _blue),
                if (insp['submitted_at'] != null)
                  _Row('Submitted', _fmtFull(insp['submitted_at'].toString()), _grey),
                if (insp['reviewed_by'] != null && insp['reviewed_by'].toString().isNotEmpty)
                  _Row('Reviewed by', insp['reviewed_by'].toString(), _grey),
                if (insp['notes'] != null && insp['notes'].toString().isNotEmpty)
                  _Row('Notes', insp['notes'].toString(), _grey),
              ])),
              const SizedBox(height: 16),

              // ── Issues ─────────────────────────────────────────────────────
              if (issues.isNotEmpty) ...[
                _SectionHeader('⚠️  Issues Reported', issues.length, _red),
                const SizedBox(height: 8),
                ...issues.map((iss) => _IssueRow(iss)),
                const SizedBox(height: 16),
              ],

              // ── Checklist items ────────────────────────────────────────────
              if (grouped.isNotEmpty) ...[
                _SectionHeader('📋  Checklist Items', items.length, _blue),
                const SizedBox(height: 10),
                ...grouped.entries.map((entry) => _CategoryCard(
                    category: entry.key, items: entry.value)),
              ],
            ])),
          ),
        ],
      ),
    );
  }

  static String _fmtFull(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    const m = ['','Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month]} ${dt.day}, ${dt.year}  '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}

// ── Card wrapper ───────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
          blurRadius: 10, offset: const Offset(0, 3))]),
    child: child,
  );
}

// ── Stat box ───────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _StatBox(this.icon, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(height: 4),
    Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
    Text(label, style: GoogleFonts.inter(fontSize: 11, color: _grey)),
  ]);
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 40, color: _border);
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}

// ── Meta row ───────────────────────────────────────────────────────────────────
class _Row extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _Row(this.label, this.value, this.valueColor);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 13, color: _grey, fontWeight: FontWeight.w500)),
      const SizedBox(width: 8),
      Expanded(child: Text(value, textAlign: TextAlign.end, style: GoogleFonts.inter(
          fontSize: 13, color: valueColor, fontWeight: FontWeight.w700))),
    ]),
  );
}

// ── Section header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _SectionHeader(this.title, this.count, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title, style: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
    const Spacer(),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
      child: Text('$count', style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ),
  ]);
}

// ── Issue row ──────────────────────────────────────────────────────────────────
class _IssueRow extends StatelessWidget {
  final Map<String, dynamic> iss;
  const _IssueRow(this.iss);
  @override
  Widget build(BuildContext context) {
    final severity   = (iss['severity'] ?? 'minor').toString();
    final isCritical = severity == 'critical';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCritical
            ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(isCritical ? Icons.error_rounded : Icons.warning_amber_rounded,
            size: 18, color: isCritical ? _red : const Color(0xFFD97706)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(iss['label']?.toString() ?? '—', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: isCritical ? _red : const Color(0xFF92400E))),
          if (iss['note']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(iss['note'].toString(),
                style: GoogleFonts.inter(fontSize: 12, color: _grey)),
          ],
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isCritical ? _red.withOpacity(0.12) : const Color(0xFFFDE68A),
            borderRadius: BorderRadius.circular(8)),
          child: Text(severity.toUpperCase(), style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: isCritical ? _red : const Color(0xFF92400E),
              letterSpacing: 0.5)),
        ),
      ]),
    );
  }
}

// ── Category card with items ───────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final String category;
  final List<Map<String, dynamic>> items;
  const _CategoryCard({required this.category, required this.items});

  @override
  Widget build(BuildContext context) {
    final passedCount = items.where((i) => i['status'] == true).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Category header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _blue.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            const Icon(Icons.category_outlined, size: 16, color: _blue),
            const SizedBox(width: 8),
            Expanded(child: Text(category, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w800, color: _navy))),
            Text('$passedCount / ${items.length}',
                style: GoogleFonts.inter(fontSize: 12, color: _blue, fontWeight: FontWeight.w700)),
          ]),
        ),
        // Items
        ...items.asMap().entries.map((e) {
          final item    = e.value;
          final passed  = item['status'] == true;
          final label   = item['label']?.toString() ?? '—';
          final note    = item['note']?.toString() ?? '';
          final isLast  = e.key == items.length - 1;

          // Photo: try base64 field first, then photo_base64
          final rawPhoto = item['photo']?.toString() ?? item['photo_base64']?.toString() ?? '';
          Uint8List? photoBytes;
          if (rawPhoto.isNotEmpty) {
            try {
              final b64 = rawPhoto.contains(',') ? rawPhoto.split(',').last : rawPhoto;
              photoBytes = base64Decode(b64);
            } catch (_) {}
          }

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: passed ? _green.withOpacity(0.10) : _red.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 12, color: passed ? _green : _red),
                      const SizedBox(width: 4),
                      Text(passed ? 'PASS' : 'FAIL', style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: passed ? _green : _red, letterSpacing: 0.4)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w500, color: _navy))),
                ]),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text('Note: $note', style: GoogleFonts.inter(
                      fontSize: 11, color: _grey, fontStyle: FontStyle.italic)),
                ],
                // Photo
                if (photoBytes != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _showPhotoFull(context, photoBytes!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        photoBytes,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ]),
            ),
            if (!isLast)
              Container(height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: _border),
          ]);
        }),
      ]),
    );
  }

  void _showPhotoFull(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: InteractiveViewer(
          child: Image.memory(bytes, fit: BoxFit.contain),
        )),
      ),
    ));
  }
}
