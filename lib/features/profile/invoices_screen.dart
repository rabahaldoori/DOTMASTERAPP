import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/api_client.dart';
import '../../core/font_ext.dart';

const _navy = Color(0xFF031634);
const _blue = Color(0xFF0453CD);

// ─────────────────────────────────────────────────────────────────────────────
// InvoicesScreen  (list)
// ─────────────────────────────────────────────────────────────────────────────
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  static Future<void> push(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InvoicesScreen()),
      );

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool   _loading     = true;
  String _error       = '';
  List<Map<String, dynamic>> _invoices = [];
  bool   _hasMore     = false;
  String? _lastId;
  bool   _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _loadingMore = true);
    } else {
      setState(() { _loading = true; _error = ''; _invoices = []; });
    }
    try {
      final res  = await ApiClient.getInvoices(
          startingAfter: loadMore ? _lastId : null);
      final data = res.data as Map<String, dynamic>;
      final list = (data['invoices'] as List).cast<Map<String, dynamic>>();
      setState(() {
        if (loadMore) _invoices.addAll(list); else _invoices = list;
        _hasMore     = data['has_more'] == true;
        _lastId      = list.isNotEmpty ? list.last['id'] as String? : null;
        _loading     = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error       = 'Could not load invoices. Please try again.';
        _loading     = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F3FA),
        body: RefreshIndicator(
          color: _blue,
          backgroundColor: Colors.white,
          onRefresh: _fetch,
          child: CustomScrollView(slivers: [

          // ── App bar ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Invoices', style: context.af(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF031634), Color(0xFF0A2347), Color(0xFF0453CD)],
                    stops: [0, 0.55, 1],
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Column(mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Billing History', style: context.af(
                          fontSize: 20, fontWeight: FontWeight.w900,
                          color: Colors.white)),
                      const SizedBox(height: 3),
                      Text('View your payment receipts',
                          style: context.af(fontSize: 12, color: Colors.white54)),
                    ]),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _blue)))
          else if (_error.isNotEmpty)
            SliverFillRemaining(child: _buildError())
          else if (_invoices.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  16, 20, 16, 24 + MediaQuery.of(context).padding.bottom),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i < _invoices.length) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InvoiceCard(
                          invoice: _invoices[i],
                          onTap: () async {
                            final paid = await InvoiceDetailScreen.push(
                                context, _invoices[i]);
                            if (paid == true) _fetch();
                          },
                        ),
                      );
                    }
                    if (_hasMore) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator(color: _blue)
                              : TextButton.icon(
                                  onPressed: () => _fetch(loadMore: true),
                                  icon: const Icon(Icons.expand_more_rounded,
                                      color: _blue),
                                  label: Text('Load more',
                                      style: context.af(
                                          color: _blue,
                                          fontWeight: FontWeight.w600)),
                                ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  childCount: _invoices.length + (_hasMore ? 1 : 0),
                ),
              ),
            ),
        ]),
        ),      // ← closes CustomScrollView (child of RefreshIndicator)
      ),        // ← closes RefreshIndicator (body of Scaffold)
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, color: Color(0xFF94A3B8), size: 52),
        const SizedBox(height: 12),
        Text(_error,
            style: context.af(color: const Color(0xFF64748B), fontSize: 14),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _fetch,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _blue, foregroundColor: Colors.white),
        ),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _blue.withValues(alpha: 0.09), shape: BoxShape.circle),
        child: const Icon(Icons.receipt_long_rounded, color: _blue, size: 48),
      ),
      const SizedBox(height: 16),
      Text('No Invoices Yet', style: context.af(
          fontSize: 17, fontWeight: FontWeight.w700,
          color: const Color(0xFF1E293B))),
      const SizedBox(height: 6),
      Text('Your billing history will appear here\nafter your first payment.',
          style: context.af(fontSize: 13, color: const Color(0xFF94A3B8)),
          textAlign: TextAlign.center),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoice list card
// ─────────────────────────────────────────────────────────────────────────────
class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onTap;
  const _InvoiceCard({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status   = invoice['status']?.toString() ?? 'unknown';
    final total    = (invoice['total'] as num?)    ?? 0.0;
    final currency = invoice['currency']?.toString() ?? 'USD';
    final number   = invoice['number']?.toString()   ?? 'N/A';
    final created  = invoice['created']?.toString()  ?? '';
    final isPaid   = status == 'paid';

    final statusColor = isPaid
        ? const Color(0xFF10B981)
        : status == 'open'
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            // Icon
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: _blue, size: 22),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Invoice $number', style: context.af(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A))),
              const SizedBox(height: 3),
              Text(created, style: context.af(
                  fontSize: 12, color: const Color(0xFF64748B))),
            ])),
            // Right side
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\$$total $currency', style: context.af(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status.toUpperCase(), style: context.af(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: statusColor)),
              ),
            ]),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1), size: 20),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InvoiceDetailScreen  (fully native, no webview)
// ─────────────────────────────────────────────────────────────────────────────
class InvoiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  const InvoiceDetailScreen({super.key, required this.invoice});

  static Future<bool?> push(
          BuildContext context, Map<String, dynamic> invoice) =>
      Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(invoice: invoice)),
      );

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  bool _pdfLoading = false;
  bool _payLoading = false;

  Color get _statusColor {
    switch (widget.invoice['status']) {
      case 'paid':   return const Color(0xFF10B981);
      case 'open':   return const Color(0xFFF59E0B);
      default:       return const Color(0xFFEF4444);
    }
  }

  // ── Pay open invoice via Stripe PaymentSheet ─────────────────────────────
  Future<void> _payNow() async {
    final invoiceId = widget.invoice['id']?.toString();
    if (invoiceId == null) return;
    setState(() => _payLoading = true);
    try {
      // 1. Fetch payment sheet secrets from our backend
      final res  = await ApiClient.getInvoicePaymentSheet(invoiceId);
      final data = res.data as Map<String, dynamic>;

      final publishableKey    = data['publishable_key']      as String;
      final customerId        = data['customer_id']          as String;
      final ephemeralKeySecret = data['ephemeral_key_secret'] as String;
      final clientSecret      = data['client_secret']        as String;

      // 2. Configure Stripe
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();

      // 3. Initialise PaymentSheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName:        'DOT Master',
          customerId:                 customerId,
          customerEphemeralKeySecret: ephemeralKeySecret,
          paymentIntentClientSecret:  clientSecret,
          style: ThemeMode.light,
        ),
      );

      // 4. Present the sheet
      await Stripe.instance.presentPaymentSheet();

      // 5. Success → pop back so the invoice list refreshes
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Payment successful!'),
          backgroundColor: Color(0xFF10B981),
        ));
        Navigator.pop(context, true); // true = refresh list
      }
    } on StripeException catch (e) {
      if (mounted && e.error.code != FailureCode.Canceled) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Payment failed: ${e.error.localizedMessage ?? e.error.message}'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _payLoading = false);
    }
  }

  Future<void> _openPdf() async {
    final invoiceId = widget.invoice['id']?.toString();
    final number    = widget.invoice['number']?.toString() ?? 'Invoice';
    if (invoiceId == null) return;

    setState(() => _pdfLoading = true);
    try {
      final bytes = await ApiClient.getInvoicePdfBytes(invoiceId);
      if (bytes.isEmpty) throw Exception('Empty PDF response');

      // Save to temp file
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/invoice_${invoiceId.replaceAll(RegExp(r'[^\w]'), '_')}.pdf');
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        await InvoicePdfViewScreen.push(context, file.path, number);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load PDF: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice     = widget.invoice;
    final status      = invoice['status']?.toString()       ?? 'unknown';
    final number      = invoice['number']?.toString()       ?? 'N/A';
    final created     = invoice['created']?.toString()      ?? '';
    final periodStart = invoice['period_start']?.toString() ?? '';
    final periodEnd   = invoice['period_end']?.toString()   ?? '';
    final currency    = invoice['currency']?.toString()     ?? 'USD';
    final subtotal    = (invoice['subtotal'] as num?)       ?? 0.0;
    final tax         = (invoice['tax'] as num?)            ?? 0.0;
    final discount    = (invoice['discount'] as num?)       ?? 0.0;
    final total       = (invoice['total'] as num?)          ?? 0.0;
    final lines       = (invoice['lines'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final isPaid = status == 'paid';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F3FA),
        body: CustomScrollView(slivers: [

          // ── Header ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Invoice $number', style: context.af(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            actions: [
              // PDF button in app bar
              _pdfLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)))
                  : IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.white),
                      tooltip: 'View PDF',
                      onPressed: _openPdf,
                    ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF031634), Color(0xFF0A2347),
                             Color(0xFF0453CD)],
                    stops: [0, 0.55, 1],
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color: _statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            isPaid
                                ? Icons.check_circle_rounded
                                : Icons.schedule_rounded,
                            color: _statusColor, size: 12),
                          const SizedBox(width: 5),
                          Text(status.toUpperCase(), style: context.af(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: _statusColor)),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text('\$$total $currency',
                          style: context.af(
                              fontSize: 32, fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      if (created.isNotEmpty)
                        Text(created, style: context.af(
                            fontSize: 12, color: Colors.white54)),
                    ]),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 20, 16, 32 + MediaQuery.of(context).padding.bottom),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Invoice meta card ─────────────────────────────────
                _SectionCard(children: [
                  _MetaRow(label: 'Invoice #', value: number),
                  if (created.isNotEmpty)
                    _MetaRow(label: 'Date', value: created),
                  if (periodStart.isNotEmpty)
                    _MetaRow(label: 'Period',
                        value: '$periodStart – $periodEnd'),
                  _MetaRow(label: 'Currency', value: currency),
                ]),

                const SizedBox(height: 16),

                // ── Line items ────────────────────────────────────────
                if (lines.isNotEmpty) ...[
                  _SectionLabel('Services'),
                  _SectionCard(children: [
                    for (int i = 0; i < lines.length; i++) ...[
                      _LineItemRow(line: lines[i], currency: currency),
                      if (i < lines.length - 1)
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    ],
                  ]),
                  const SizedBox(height: 16),
                ],

                // ── Totals ────────────────────────────────────────────
                _SectionLabel('Summary'),
                _SectionCard(children: [
                  _TotalRow(label: 'Subtotal',
                      value: '\$$subtotal $currency', bold: false),
                  if (discount > 0)
                    _TotalRow(label: 'Discount',
                        value: '−\$$discount', bold: false,
                        color: const Color(0xFF10B981)),
                  if (tax > 0)
                    _TotalRow(label: 'Tax',
                        value: '\$$tax $currency', bold: false),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                  _TotalRow(label: 'Total',
                      value: '\$$total $currency', bold: true),
                ]),

                const SizedBox(height: 16),

                // ── Payment status notice ─────────────────────────────
                _PaymentNotice(status: status, statusColor: _statusColor),

                const SizedBox(height: 20),

                // ── Pay Now button (open invoices only) ───────────────
                if (status == 'open') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_payLoading || _pdfLoading) ? null : _payNow,
                      icon: _payLoading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.payment_rounded, size: 18),
                      label: Text(
                          _payLoading ? 'Processing…' : 'Pay Now',
                          style: context.af(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFFF59E0B).withValues(alpha: 0.5),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── View PDF button ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _pdfLoading ? null : _openPdf,
                    icon: _pdfLoading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: Text(
                        _pdfLoading ? 'Loading PDF…' : 'View PDF',
                        style: context.af(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _navy.withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InvoicePdfViewScreen  — in-app PDF viewer
// ─────────────────────────────────────────────────────────────────────────────
class InvoicePdfViewScreen extends StatefulWidget {
  final String filePath;
  final String title;
  const InvoicePdfViewScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  static Future<void> push(
          BuildContext context, String filePath, String title) =>
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => InvoicePdfViewScreen(
                filePath: filePath, title: title)),
      );

  @override
  State<InvoicePdfViewScreen> createState() => _InvoicePdfViewScreenState();
}

class _InvoicePdfViewScreenState extends State<InvoicePdfViewScreen> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  PDFViewController? _controller;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: _navy,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.title,
              style: context.af(
                  color: Colors.white, fontWeight: FontWeight.w700,
                  fontSize: 15)),
          bottom: _totalPages > 0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(24),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Page ${_currentPage + 1} of $_totalPages',
                      style: context.af(
                          fontSize: 11, color: Colors.white60),
                    ),
                  ),
                )
              : null,
        ),
        body: Stack(children: [
          PDFView(
            filePath: widget.filePath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            defaultPage: 0,
            fitPolicy: FitPolicy.BOTH,
            onRender: (pages) => setState(() {
              _totalPages = pages ?? 0;
              _isReady = true;
            }),
            onViewCreated: (ctrl) => _controller = ctrl,
            onPageChanged: (page, total) => setState(() {
              _currentPage = page ?? 0;
              _totalPages  = total ?? 0;
            }),
            onError: (e) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('PDF error: $e'))),
          ),
          if (!_isReady)
            const Center(
                child: CircularProgressIndicator(color: Colors.white)),
        ]),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text.toUpperCase(), style: context.af(
        fontSize: 10, fontWeight: FontWeight.w800,
        letterSpacing: 0.8, color: const Color(0xFF64748B))),
  );
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10, offset: const Offset(0, 3))],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: children),
  );
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(label, style: context.af(
          fontSize: 13, color: const Color(0xFF64748B))),
      const Spacer(),
      Text(value, style: context.af(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A))),
    ]),
  );
}

class _LineItemRow extends StatelessWidget {
  final Map<String, dynamic> line;
  final String currency;
  const _LineItemRow({required this.line, required this.currency});
  @override
  Widget build(BuildContext context) {
    final desc      = line['description']?.toString() ?? 'Service';
    final qty       = line['quantity']?.toString() ?? '1';
    final unitAmt   = (line['unit_amount'] as num?) ?? 0.0;
    final amount    = (line['amount'] as num?)      ?? 0.0;
    final pStart    = line['period_start']?.toString() ?? '';
    final pEnd      = line['period_end']?.toString()   ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(desc, style: context.af(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A)))),
        Text('\$$amount $currency', style: context.af(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A))),
      ]),
      const SizedBox(height: 3),
      Row(children: [
        Text('Qty: $qty · \$$unitAmt each', style: context.af(
            fontSize: 11, color: const Color(0xFF94A3B8))),
        const Spacer(),
      ]),
      if (pStart.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text('$pStart – $pEnd', style: context.af(
            fontSize: 11, color: const Color(0xFF94A3B8))),
      ],
    ]);
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _TotalRow({
    required this.label,
    required this.value,
    required this.bold,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label, style: context.af(
          fontSize: bold ? 15 : 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: bold ? const Color(0xFF0F172A) : const Color(0xFF64748B))),
      const Spacer(),
      Text(value, style: context.af(
          fontSize: bold ? 16 : 13,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          color: color ?? (bold ? _blue : const Color(0xFF0F172A)))),
    ]),
  );
}

class _PaymentNotice extends StatelessWidget {
  final String status;
  final Color statusColor;
  const _PaymentNotice({required this.status, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final isPaid = status == 'paid';
    final isOpen = status == 'open';

    final icon    = isPaid ? Icons.check_circle_rounded
                  : isOpen ? Icons.warning_amber_rounded
                           : Icons.info_outline_rounded;
    final title   = isPaid ? 'Payment Received'
                  : isOpen ? 'Payment Pending'
                           : 'Invoice ${status[0].toUpperCase()}${status.substring(1)}';
    final sub     = isPaid
        ? 'Thank you — this invoice has been paid in full.'
        : isOpen
            ? 'Please complete payment to keep your subscription active.'
            : 'This invoice is no longer active.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: statusColor, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(title, style: context.af(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: statusColor)),
          const SizedBox(height: 3),
          Text(sub, style: context.af(
              fontSize: 12, color: const Color(0xFF64748B))),
        ])),
      ]),
    );
  }
}
