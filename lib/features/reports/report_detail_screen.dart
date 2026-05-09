import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api_client.dart';

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

class ReportDetailScreen extends StatefulWidget {
  final int reportId;
  final Map reportSummary; // passed from list to pre-fill while loading
  const ReportDetailScreen({super.key, required this.reportId, required this.reportSummary});
  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  Map?   _detail;
  bool   _loading        = true;
  bool   _downloading    = false;
  bool   _downloadingCsv = false;
  bool   _showAllJuris   = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.getIftaReportDetail(widget.reportId);
      setState(() => _detail = res.data as Map);
    } catch (e) {
      setState(() => _error = 'Could not load report details.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      final res = await ApiClient.downloadIftaReportPdf(widget.reportId);
      final dir  = await getTemporaryDirectory();
      final q    = _detail?['quarter'] ?? widget.reportSummary['quarter'] ?? 1;
      final y    = _detail?['year']    ?? widget.reportSummary['year']    ?? DateTime.now().year;
      final file = File('${dir.path}/IFTA_Q${q}_$y.pdf');
      await file.writeAsBytes(res.data as List<int>);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _PdfViewerScreen(filePath: file.path, title: 'IFTA Q$q $y'),
      ));
    } catch (e) {
      if (mounted) _showError('Failed to download PDF. Please try again.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _downloadCsv() async {
    setState(() => _downloadingCsv = true);
    try {
      final res = await ApiClient.downloadIftaReportCsv(widget.reportId);
      final dir  = await getTemporaryDirectory();
      final q    = _detail?['quarter'] ?? widget.reportSummary['quarter'] ?? 1;
      final y    = _detail?['year']    ?? widget.reportSummary['year']    ?? DateTime.now().year;
      final file = File('${dir.path}/IFTA_Q${q}_$y.csv');
      await file.writeAsBytes(res.data as List<int>);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'IFTA Q$q $y Report',
        text: 'IFTA Q$q $y jurisdiction breakdown CSV',
      );
    } catch (e) {
      if (mounted) _showError('Failed to download CSV. Please try again.');
    } finally {
      if (mounted) setState(() => _downloadingCsv = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Error', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(msg, style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: GoogleFonts.inter(color: _blue, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final data    = _detail ?? widget.reportSummary;
    final quarter = data['quarter'] as int? ?? 1;
    final year    = data['year']    as int? ?? DateTime.now().year;
    final status  = (data['status'] ?? 'draft').toString().toLowerCase();
    final isFiled = status == 'filed';
    final isReady = status.contains('ready') || status == 'validation_complete';
    final statusColor = isFiled ? _green : isReady ? _blue : _amber;
    final statusLabel = isFiled ? 'FILED' : isReady ? 'READY TO FILE' : 'DRAFT';

    final qNames = {1:'Q1 · Jan–Mar', 2:'Q2 · Apr–Jun', 3:'Q3 · Jul–Sep', 4:'Q4 · Oct–Dec'};
    final jurisdictions = (data['lines'] as List?) ?? [];
    final taxDue  = _n(data['net_tax_due']);
    final miles   = _n(data['total_miles']);
    final gallons = _n(data['total_gallons']);
    final mpg     = gallons > 0 ? miles / gallons : 0.0;
    final netTax  = _n(data['net_tax_due']);

    return Scaffold(
      backgroundColor: _surface,
      body: CustomScrollView(slivers: [
        // ── Header ──────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: _navy,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
          title: Text('Report Details', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          actions: [
            // CSV button
            GestureDetector(
              onTap: _downloadingCsv ? null : _downloadCsv,
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.20))),
                child: _downloadingCsv
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.table_chart_outlined, color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text('CSV', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
              ),
            ),
            // PDF button
            GestureDetector(
              onTap: _downloading ? null : _downloadPdf,
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.20))),
                child: _downloading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text('PDF', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, _navy2])),
              child: Stack(children: [
                Positioned(right: -30, top: -30, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),
                SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(qNames[quarter] ?? 'Q$quarter', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('$year Quarterly Report', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: statusColor.withOpacity(0.20), borderRadius: BorderRadius.circular(10), border: Border.all(color: statusColor.withOpacity(0.5))), child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.3))),
                    ]),
                  ]),
                )),
              ]),
            ),
          ),
        ),

        if (_loading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _blue)))
        else if (_error != null)
          SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.inter(color: _grey)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: _navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Retry', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700))),
          ])))
        else ...[
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Key Metrics ─────────────────────────────────────────
              Row(children: [
                Expanded(child: _MetricCard(icon: Icons.route_outlined, color: _blue, label: 'Total Miles', value: '${miles.toStringAsFixed(1)} mi')),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(icon: Icons.water_drop_outlined, color: const Color(0xFF06B6D4), label: 'Gallons', value: gallons.toStringAsFixed(1))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _MetricCard(icon: Icons.speed_rounded, color: const Color(0xFF7C3AED), label: 'Avg MPG', value: mpg.toStringAsFixed(2), warn: mpg > 0 && mpg < 5)),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(icon: Icons.account_balance_outlined, color: _green, label: 'Tax Due', value: '\$${taxDue.toStringAsFixed(2)}')),
              ]),

              const SizedBox(height: 20),

              // ── Jurisdictions table ─────────────────────────────────
              if (jurisdictions.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MILES BY JURISDICTION', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.8)),
                    Text('${jurisdictions.length} states', style: GoogleFonts.inter(fontSize: 10, color: _grey)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                  child: Column(children: [
                    // Header row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(color: Color(0xFFF8FAFF), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                      child: Row(children: [
                        Expanded(flex: 2, child: Text('STATE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.6))),
                        Expanded(child: Text('MILES', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.6))),
                        Expanded(child: Text('GALLONS', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.6))),
                        Expanded(child: Text('TAX', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.6))),
                      ]),
                    ),
                    // ── Animated collapsible rows ────────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      child: Column(
                        children: (_showAllJuris
                            ? jurisdictions
                            : jurisdictions.take(4).toList())
                          .asMap().entries.map((e) {
                            final j         = e.value as Map;
                            final jMiles    = _n(j['total_miles']);
                            final jGal      = _n(j['gallons_purchased']);
                            final jTax      = _n(j['tax_due']);
                            final stateName = j['jurisdiction'] ?? j['state'] ?? '—';
                            final pct       = miles > 0 ? (jMiles / miles).clamp(0.0, 1.0) : 0.0;
                            return Container(
                              decoration: BoxDecoration(border: Border(top: BorderSide(color: _border, width: 0.5))),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(flex: 2, child: Text(stateName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _navy))),
                                  Expanded(child: Text('${jMiles.toStringAsFixed(0)} mi', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, color: _navy))),
                                  Expanded(child: Text(jGal > 0 ? jGal.toStringAsFixed(1) : '—', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, color: _grey))),
                                  Expanded(child: Text('\$${jTax.toStringAsFixed(2)}', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: jTax > 0 ? _blue : _grey))),
                                ]),
                                const SizedBox(height: 5),
                                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: _border, valueColor: AlwaysStoppedAnimation(_navy))),
                              ]),
                            );
                          }).toList(),
                      ),
                    ),
                    // ── Show All / Hide button ───────────────────────
                    if (jurisdictions.length > 4)
                      GestureDetector(
                        onTap: () => setState(() => _showAllJuris = !_showAllJuris),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                            border: Border(top: BorderSide(color: _border, width: 0.5)),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(
                              _showAllJuris ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 16, color: _blue,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _showAllJuris ? 'Hide' : 'Show All ${jurisdictions.length} States',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _blue),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 20),
              ],


              // ── Summary row ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _SumItem(label: 'Jurisdictions', value: '${jurisdictions.length}'),
                  Container(width: 1, height: 32, color: _border),
                  _SumItem(label: 'Net Tax', value: '\$${netTax.toStringAsFixed(2)}', highlight: netTax > 0),
                  Container(width: 1, height: 32, color: _border),
                  _SumItem(label: 'Ref #', value: 'IFT-${data['id'] ?? '—'}'),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Download buttons ────────────────────────────────────
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: _downloading ? null : _downloadPdf,
                style: ElevatedButton.styleFrom(backgroundColor: _navy, disabledBackgroundColor: _navy.withOpacity(0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 15), elevation: 0),
                icon: _downloading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                label: Text(_downloading ? 'Downloading…' : 'View & Download PDF', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              )),

              const SizedBox(height: 10),

              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _downloadingCsv ? null : _downloadCsv,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _downloadingCsv ? _border : _navy, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                icon: _downloadingCsv
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _navy, strokeWidth: 2))
                    : const Icon(Icons.table_chart_outlined, color: _navy, size: 20),
                label: Text(_downloadingCsv ? 'Downloading…' : 'Download & Share CSV', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
              )),

              const SizedBox(height: 80),
            ]),
          )),
        ],
      ]),
    );
  }
}

// ── Metric card ───────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final IconData icon; final Color color; final String label, value; final bool warn;
  const _MetricCard({required this.icon, required this.color, required this.label, required this.value, this.warn = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 17, color: color)),
        if (warn) ...[const Spacer(), const Icon(Icons.warning_amber_rounded, size: 16, color: _amber)],
      ]),
      const SizedBox(height: 8),
      Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: warn ? _amber : _navy)),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: _grey)),
    ]),
  );
}

class _SumItem extends StatelessWidget {
  final String label, value; final bool highlight;
  const _SumItem({required this.label, required this.value, this.highlight = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: highlight ? _blue : _navy)),
    const SizedBox(height: 2),
    Text(label, style: GoogleFonts.inter(fontSize: 10, color: _grey)),
  ]);
}

// ── In-app PDF Viewer ─────────────────────────────────────────────────────────
class _PdfViewerScreen extends StatefulWidget {
  final String filePath, title;
  const _PdfViewerScreen({required this.filePath, required this.title});
  @override
  State<_PdfViewerScreen> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewerScreen> {
  int _pages = 0;
  int _current = 0;
  bool _ready = false;
  bool _sharing = false;
  PDFViewController? _ctrl;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await Share.shareXFiles(
        [XFile(widget.filePath, mimeType: 'application/pdf')],
        subject: widget.title,
        text: 'IFTA Report: ${widget.title}',
      );
    } catch (_) {} finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black87,
    appBar: AppBar(
      backgroundColor: _navy,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        if (_ready && _pages > 0)
          Text('Page ${_current + 1} of $_pages', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
      ]),
      actions: [
        // Share button
        IconButton(
          tooltip: 'Share PDF',
          onPressed: _sharing ? null : _share,
          icon: _sharing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.ios_share_rounded, color: Colors.white, size: 22),
        ),
        // Page navigation
        if (_pages > 1) ...[
          IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: _current > 0 ? () { _ctrl?.setPage(_current - 1); } : null),
          IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: _current < _pages - 1 ? () { _ctrl?.setPage(_current + 1); } : null),
        ],
      ],
    ),
    body: Stack(children: [
      PDFView(
        filePath: widget.filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        fitPolicy: FitPolicy.BOTH,
        onRender: (pages) => setState(() { _pages = pages ?? 0; _ready = true; }),
        onViewCreated: (ctrl) => _ctrl = ctrl,
        onPageChanged: (page, _) => setState(() => _current = page ?? 0),
        onError: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF error: $e'))),
      ),
      if (!_ready)
        Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
    ]),
  );
}
