import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import 'inspection_session.dart';

const _navy  = Color(0xFF031634);
const _blue  = Color(0xFF0453CD);
const _white = Colors.white;

class ReviewSubmitScreen extends StatefulWidget {
  const ReviewSubmitScreen({super.key});
  @override
  State<ReviewSubmitScreen> createState() => _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends State<ReviewSubmitScreen> {
  // Each sub-list is one continuous stroke
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];
  bool get _hasSig => _strokes.any((s) => s.isNotEmpty);
  bool _submitting = false;

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _current = [d.localPosition];
      _strokes.add(_current);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _current.add(d.localPosition));
  }

  void _clearSig() => setState(() { _strokes.clear(); _current = []; });

  Future<void> _submit() async {
    if (!_hasSig || _submitting) return;
    setState(() => _submitting = true);
    try {
      final session = InspectionSession.instance;

      // Build checklist payload — convert bool? status to true/false/null
      final checklist = session.checklistItems.map((item) => {
        'category': item['category'] ?? '',
        'label':    item['label']    ?? '',
        'status':   item['status'],   // true / false / null
        'note':     item['note']     ?? '',
      }).toList();

      // Auto-detect issues: any failed item becomes an issue
      final autoIssues = session.checklistItems
          .where((i) => i['status'] == false)
          .map((i) => {
            'label':    i['label'] ?? '',
            'severity': 'minor',
            'note':     i['note'] ?? '',
          }).toList();

      // Merge auto-issues + any manually added issues
      final allIssues = [...autoIssues, ...session.issues];

      final payload = <String, dynamic>{
        'inspection_type': session.inspectionType,
        'total_items':     session.totalItems,
        'passed_items':    session.passedItems,
        'failed_items':    session.failedItems,
        'photos_count':    0,
        'checklist_data':  checklist,
        'issues':          allIssues,
        'signature_data':  'signed',
        'notes':           '',
      };
      // Attach truck only if known
      if (session.truckId != null) payload['truck'] = session.truckId;

      final res = await ApiClient.submitInspection(payload);
      if (!mounted) return;
      if (res.statusCode == 201) {
        final id = res.data['inspection_number'] ?? '';
        session.clear(); // reset for next inspection
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Inspection $id submitted!',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
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
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3FF),
      appBar: AppBar(
        backgroundColor: _white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _navy),
          onPressed: () => context.pop(),
        ),
        title: Text('Pre-Trip Inspection',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _navy)),
        actions: [IconButton(icon: const Icon(Icons.more_vert, color: _navy), onPressed: () {})],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFDCE2F3)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Summary header card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE2F3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Ready for Review', style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _white)),
                ),
                const Spacer(),
                Text('ID: #INSP-8821', style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF75777E))),
              ]),
              const SizedBox(height: 12),
              Text('Truck 402 Summary', style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.w700, color: _navy)),
              const SizedBox(height: 4),
              Text('Completed on Oct 24, 2023 at 08:45 AM',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF75777E))),
            ]),
          ),

          const SizedBox(height: 12),

          // Stats row
          Row(children: [
            Expanded(child: _StatCard(icon: Icons.checklist_rounded,
                value: '18', label: 'Items Checked', iconColor: _navy)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(icon: Icons.photo_camera_outlined,
                value: '4', label: 'Photos Captured', iconColor: _blue)),
          ]),

          const SizedBox(height: 12),

          // Issue alert
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_rounded, color: _white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('1 Minor Issue', style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.red.shade700)),
                const SizedBox(height: 2),
                Text('Low wiper fluid – Service required soon',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade600)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.red.shade400),
                  const SizedBox(width: 4),
                  Text('Non-critical compliance check', style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.red.shade400)),
                ]),
              ])),
            ]),
          ),

          const SizedBox(height: 24),

          // Signature section
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('DRIVER SIGNATURE', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700, color: _navy,
                letterSpacing: 0.5)),
            TextButton(
              onPressed: _clearSig,
              child: Text('Clear Canvas', style: GoogleFonts.inter(
                  fontSize: 13, color: _blue, fontWeight: FontWeight.w600)),
            ),
          ]),
          // Signature canvas
          GestureDetector(
            onPanStart:  _onPanStart,
            onPanUpdate: _onPanUpdate,
            child: Container(
              height: 130,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasSig ? _blue.withOpacity(0.5) : const Color(0xFFDCE2F3),
                  width: _hasSig ? 2 : 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _strokes.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.draw_outlined, size: 28, color: Colors.grey.shade300),
                        const SizedBox(height: 4),
                        Text('Sign here', style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey.shade400)),
                      ]))
                    : CustomPaint(
                        painter: _SignaturePainter(_strokes),
                        child: const SizedBox.expand(),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'I certify that this inspection was performed in accordance with safety standards.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF75777E),
                fontStyle: FontStyle.italic),
          ),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton.icon(
              onPressed: (_hasSig && !_submitting) ? _submit : null,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, color: _white),
              label: Text(_submitting ? 'Submitting…' : 'Submit Inspection',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  const _StatCard({required this.icon, required this.value,
    required this.label, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF1FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE2F3)),
      ),
      child: Column(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFDCE2F3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(height: 10),
        Text(value, style: GoogleFonts.inter(
            fontSize: 28, fontWeight: FontWeight.w800, color: iconColor)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(
            fontSize: 12, color: const Color(0xFF75777E))),
      ]),
    );
  }
}

// ── Signature painter ─────────────────────────────────────────────────────────
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF031634)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        if (i < stroke.length - 1) {
          // Smooth curve through midpoints
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
