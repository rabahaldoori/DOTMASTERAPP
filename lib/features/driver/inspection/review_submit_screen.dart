import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import 'inspection_session.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _navy   = Color(0xFF031634);
const _blue   = Color(0xFF0453CD);
const _cyan   = Color(0xFF06B6D4);
const _white  = Colors.white;
const _grey   = Color(0xFF75777E);
const _border = Color(0xFFDCE2F3);
const _bg     = Color(0xFFF0F4FA);

class ReviewSubmitScreen extends StatefulWidget {
  const ReviewSubmitScreen({super.key});
  @override
  State<ReviewSubmitScreen> createState() => _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends State<ReviewSubmitScreen>
    with SingleTickerProviderStateMixin {
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];
  bool get _hasSig => _strokes.any((s) => s.isNotEmpty);
  bool _submitting = false;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  void _onPanStart(DragStartDetails d) {
    HapticFeedback.selectionClick();
    setState(() { _current = [d.localPosition]; _strokes.add(_current); });
  }
  void _onPanUpdate(DragUpdateDetails d) => setState(() => _current.add(d.localPosition));
  void _clearSig() { HapticFeedback.lightImpact(); setState(() { _strokes.clear(); _current = []; }); }

  Future<void> _submit() async {
    if (!_hasSig || _submitting) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      final session = InspectionSession.instance;
      final checklist = session.checklistItems.map((item) => {
        'category': item['category'] ?? '',
        'label':    item['label']    ?? '',
        'status':   item['status'],
        'note':     item['note']     ?? '',
        if (item['photo'] != null) 'photo': item['photo'],
      }).toList();
      final photosCount = session.checklistItems
          .where((i) => i['photo'] != null).length;
      final autoIssues = session.checklistItems
          .where((i) => i['status'] == false)
          .map((i) => {
            'label':    i['label'] ?? '',
            'severity': 'minor',
            'note':     i['note'] ?? '',
          }).toList();
      final allIssues = [...autoIssues, ...session.issues];
      final payload = <String, dynamic>{
        'inspection_type': session.inspectionType,
        'total_items':     session.totalItems,
        'passed_items':    session.passedItems,
        'failed_items':    session.failedItems,
        'photos_count':    photosCount,
        'checklist_data':  checklist,
        'issues':          allIssues,
        'signature_data':  'signed',
        'notes':           '',
      };
      if (session.truckId != null) payload['truck'] = session.truckId;
      final res = await ApiClient.submitInspection(payload);
      if (!mounted) return;
      if (res.statusCode == 201) {
        final id = res.data['inspection_number'] ?? '';
        session.clear();
        _showSuccess('Inspection $id submitted!');
        context.go('/driver-dashboard');
      } else {
        _showError('Submission failed (${res.statusCode}). Please try again.');
      }
    } catch (e) {
      _showError('Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: _white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: const Color(0xFFB91C1C),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: _white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: const Color(0xFF15803D),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final session = InspectionSession.instance;
    final total   = session.totalItems;
    final passed  = session.passedItems;
    final failed  = session.failedItems;
    final issues  = session.checklistItems.where((i) => i['status'] == false).toList();
    final now     = DateTime.now();
    final dateStr = '${_month(now.month)} ${now.day}, ${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: _navy,
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: _white, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient background
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF020D1F), Color(0xFF0A2550), Color(0xFF0453CD)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Decorative circle
                  Positioned(
                    top: -40, right: -40,
                    child: Container(
                      width: 180, height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _cyan.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20, left: -20,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  // Content
                  Positioned(
                    bottom: 24, left: 20, right: 20,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _cyan.withValues(alpha: 0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 6, height: 6,
                            decoration: const BoxDecoration(color: _cyan, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('PRE-TRIP INSPECTION', style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: _cyan, letterSpacing: 0.8)),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text('Review & Sign', style: GoogleFonts.inter(
                          fontSize: 26, fontWeight: FontWeight.w900,
                          color: _white, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text('$dateStr  ·  $timeStr', style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.white60, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // ── Body content ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(children: [

                // ── Stats row ─────────────────────────────────────────────────
                Row(children: [
                  _StatTile(value: '$total', label: 'Checked', icon: Icons.checklist_rounded,
                      color: _navy),
                  const SizedBox(width: 10),
                  _StatTile(value: '$passed', label: 'Passed', icon: Icons.check_circle_rounded,
                      color: const Color(0xFF15803D)),
                  const SizedBox(width: 10),
                  _StatTile(value: '$failed', label: 'Failed', icon: Icons.cancel_rounded,
                      color: const Color(0xFFB91C1C)),
                ]),

                const SizedBox(height: 16),

                // ── Pass rate bar ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _white, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('Compliance Score', style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
                      const Spacer(),
                      Text(total > 0 ? '${((passed / total) * 100).round()}%' : '–',
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800,
                              color: failed == 0 ? const Color(0xFF15803D) : _blue)),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: total > 0 ? passed / total : 0,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFDCE2F3),
                        valueColor: AlwaysStoppedAnimation(
                            failed == 0 ? const Color(0xFF15803D) : _blue),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Issues ────────────────────────────────────────────────────
                if (issues.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB91C1C),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.warning_amber_rounded,
                                color: _white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Text('${issues.length} Issue${issues.length > 1 ? 's' : ''} Detected',
                              style: GoogleFonts.inter(fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF991B1B))),
                        ]),
                      ),
                      const Divider(height: 1, color: Color(0xFFFECACA)),
                      ...issues.asMap().entries.map((e) {
                        final item = e.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(children: [
                            Container(width: 8, height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFB91C1C), shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item['label'] ?? '',
                                style: GoogleFonts.inter(fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF7F1D1D)))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFECACA),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('FAIL', style: GoogleFonts.inter(
                                  fontSize: 10, fontWeight: FontWeight.w800,
                                  color: const Color(0xFF991B1B))),
                            ),
                          ]),
                        );
                      }),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Certification text ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _blue.withValues(alpha: 0.15)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.verified_user_outlined, size: 20,
                        color: _blue.withValues(alpha: 0.7)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'I certify that this pre-trip inspection was performed in accordance '
                      'with applicable safety regulations and all defects have been reported.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: _blue,
                          fontWeight: FontWeight.w500, height: 1.5),
                    )),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── Signature section ─────────────────────────────────────────
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_navy, _blue]),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.draw_rounded, color: _white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('Driver Signature', style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _navy)),
                  const Spacer(),
                  if (_hasSig)
                    GestureDetector(
                      onTap: _clearSig,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.refresh_rounded, size: 14, color: Colors.red.shade600),
                          const SizedBox(width: 4),
                          Text('Clear', style: GoogleFonts.inter(fontSize: 12,
                              fontWeight: FontWeight.w700, color: Colors.red.shade600)),
                        ]),
                      ),
                    ),
                ]),

                const SizedBox(height: 12),

                // Signature canvas
                GestureDetector(
                  onPanStart:  _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _hasSig
                              ? _blue.withValues(alpha: 0.5)
                              : _border.withValues(alpha: 0.5 + _pulse.value * 0.3),
                          width: _hasSig ? 2 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _hasSig
                                ? _blue.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(children: [
                          // Lined paper background
                          Positioned.fill(child: CustomPaint(painter: _LinedPaper())),
                          _strokes.isEmpty
                              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.gesture_rounded, size: 36,
                                      color: _grey.withValues(alpha: 0.3)),
                                  const SizedBox(height: 6),
                                  Text('Sign here',
                                      style: GoogleFonts.inter(fontSize: 13,
                                          color: _grey.withValues(alpha: 0.4),
                                          fontWeight: FontWeight.w500)),
                                ]))
                              : CustomPaint(
                                  painter: _SignaturePainter(_strokes),
                                  child: const SizedBox.expand(),
                                ),
                        ]),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.lock_outline_rounded, size: 13,
                      color: _grey.withValues(alpha: 0.5)),
                  const SizedBox(width: 5),
                  Text('Signature is securely encrypted',
                      style: GoogleFonts.inter(fontSize: 11,
                          color: _grey.withValues(alpha: 0.5))),
                ]),

                const SizedBox(height: 28),

                // ── Submit button ─────────────────────────────────────────────
                GestureDetector(
                  onTap: (_hasSig && !_submitting) ? _submit : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity, height: 58,
                    decoration: BoxDecoration(
                      gradient: (_hasSig && !_submitting)
                          ? const LinearGradient(
                              colors: [Color(0xFF0341A8), Color(0xFF0453CD)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight)
                          : null,
                      color: (!_hasSig || _submitting)
                          ? const Color(0xFFDCE2F3) : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: (_hasSig && !_submitting) ? [
                        BoxShadow(color: _blue.withValues(alpha: 0.35),
                            blurRadius: 16, offset: const Offset(0, 6)),
                      ] : [],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (_submitting)
                        const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _white))
                      else
                        const Icon(Icons.check_circle_rounded, color: _white, size: 22),
                      const SizedBox(width: 10),
                      Text(_submitting ? 'Submitting…' : 'Submit Inspection',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800,
                              color: (_hasSig && !_submitting) ? _white : _grey)),
                    ]),
                  ),
                ),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _month(int m) => const ['', 'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'][m];
}

// ── Stat tile ──────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatTile({required this.value, required this.label,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE2F3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.inter(fontSize: 22,
            fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11,
            color: const Color(0xFF75777E), fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

// ── Lined paper background for signature ──────────────────────────────────────
class _LinedPaper extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFDCE2F3).withValues(alpha: 0.5)
      ..strokeWidth = 0.8;
    for (double y = 32; y < size.height - 16; y += 28) {
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), p);
    }
    // Left margin line
    final mp = Paint()..color = const Color(0xFFFFB3B3).withValues(alpha: 0.5)..strokeWidth = 1;
    canvas.drawLine(const Offset(44, 10), Offset(44, size.height - 10), mp);
  }
  @override
  bool shouldRepaint(_LinedPaper _) => false;
}

// ── Signature painter ─────────────────────────────────────────────────────────
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF031634)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        if (i < stroke.length - 1) {
          final mid = Offset(
            (stroke[i].dx + stroke[i + 1].dx) / 2,
            (stroke[i].dy + stroke[i + 1].dy) / 2,
          );
          path.quadraticBezierTo(stroke[i].dx, stroke[i].dy, mid.dx, mid.dy);
        } else {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
