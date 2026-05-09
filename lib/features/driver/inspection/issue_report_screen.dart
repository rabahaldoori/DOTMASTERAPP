import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

const _navy  = Color(0xFF031634);
const _blue  = Color(0xFF0453CD);
const _white = Colors.white;
const _grey  = Color(0xFF75777E);

class IssueReportScreen extends StatefulWidget {
  const IssueReportScreen({super.key});
  @override
  State<IssueReportScreen> createState() => _State();
}

class _State extends State<IssueReportScreen> {
  int _severity = 1; // 0=Minor, 1=Major, 2=OOS
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Badge + Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text('Flagged Item', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: Colors.orange.shade800)),
          ),
          const SizedBox(height: 12),
          Text('Brake Line Leak', style: GoogleFonts.inter(
              fontSize: 24, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 4),
          Text('Provide details for the discovered technical failure.',
              style: GoogleFonts.inter(fontSize: 14, color: _grey)),

          const SizedBox(height: 24),

          // Evidence Photo
          Text('Evidence Photo', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
          const SizedBox(height: 8),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(children: [
              Center(child: Opacity(
                opacity: 0.15,
                child: Icon(Icons.local_shipping, size: 120, color: _white),
              )),
              Positioned(
                right: 0, bottom: 0,
                child: GestureDetector(
                  onTap: () => context.push('/driver-inspection/camera'),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_camera_outlined, size: 16, color: _white),
                      const SizedBox(width: 6),
                      Text('Re-take Photo', style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: _white)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // Description
          Text('Issue Description', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            style: GoogleFonts.inter(fontSize: 14, color: _navy),
            decoration: InputDecoration(
              hintText: 'Describe the leak location and severity...',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: _grey),
              filled: true,
              fillColor: _white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDCE2F3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDCE2F3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _blue, width: 2),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),

          const SizedBox(height: 24),

          // Severity
          Text('Severity Level', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
          const SizedBox(height: 8),
          Row(children: [
            _SeverityBtn(label: 'Minor', icon: Icons.info_outline,
                selected: _severity == 0, color: _grey,
                onTap: () => setState(() { _severity = 0; HapticFeedback.selectionClick(); })),
            const SizedBox(width: 8),
            _SeverityBtn(label: 'Major', icon: Icons.warning_amber_outlined,
                selected: _severity == 1, color: _blue,
                onTap: () => setState(() { _severity = 1; HapticFeedback.selectionClick(); })),
            const SizedBox(width: 8),
            _SeverityBtn(label: 'OOS', icon: Icons.error_outline,
                selected: _severity == 2, color: Colors.red.shade600,
                onTap: () => setState(() { _severity = 2; HapticFeedback.selectionClick(); })),
          ]),

          const SizedBox(height: 28),

          // Save button
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: () { HapticFeedback.mediumImpact(); context.pop(); },
              icon: const Icon(Icons.save_outlined, color: _white),
              label: Text('Save Issue', style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Center(child: TextButton(
            onPressed: () => context.pop(),
            child: Text('Discard Draft', style: GoogleFonts.inter(
                fontSize: 14, color: _grey, fontWeight: FontWeight.w500)),
          )),

          const SizedBox(height: 16),

          // Asset footer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDCE2F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart, color: _navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Asset #4402 – Volvo VNL', style: GoogleFonts.inter(
                    fontSize: 12, color: _grey)),
                Text('Compliance System Active', style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
              ])),
              const Icon(Icons.chevron_right, color: _grey),
            ]),
          ),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }
}

class _SeverityBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _SeverityBtn({required this.label, required this.icon,
    required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 72,
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.10) : _white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : const Color(0xFFDCE2F3),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 22, color: selected ? color : _grey),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: selected ? color : _grey)),
          ]),
        ),
      ),
    );
  }
}
