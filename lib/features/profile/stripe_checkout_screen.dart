import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/font_ext.dart';

/// Opens Stripe Checkout inside an in-app WebView.
///
/// Returns `true` if the payment was completed (Stripe redirected to
/// `dotmaster://stripe-success`), `false` if cancelled or dismissed.
class StripeCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  final String planName;

  const StripeCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.planName,
  });

  /// Push onto the navigator and return whether payment succeeded.
  static Future<bool> open(
    BuildContext context, {
    required String checkoutUrl,
    required String planName,
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StripeCheckoutScreen(
          checkoutUrl: checkoutUrl,
          planName: planName,
        ),
      ),
    );
    return result == true;
  }

  @override
  State<StripeCheckoutScreen> createState() => _StripeCheckoutScreenState();
}

class _StripeCheckoutScreenState extends State<StripeCheckoutScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  int  _progress = 0;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onProgress: (p) => setState(() => _progress = p),
          onPageFinished: (_) => setState(() { _loading = false; _progress = 100; }),
          onWebResourceError: (_) => setState(() => _loading = false),

          // Intercept the deep-link redirect Stripe sends after payment
          onNavigationRequest: (req) {
            final url = req.url;

            // Success — dotmaster://stripe-success?session_id=...
            if (url.startsWith('dotmaster://stripe-success')) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }

            // Cancel — dotmaster://stripe-cancel
            if (url.startsWith('dotmaster://stripe-cancel')) {
              Navigator.pop(context, false);
              return NavigationDecision.prevent;
            }

            // Allow all other URLs (Stripe loads sub-frames, payment method iframes, etc.)
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)),
          onPressed: () => _showCancelDialog(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscribe to ${widget.planName}',
              style: context.af(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A)),
            ),
            Text(
              'Secured by Stripe',
              style: context.af(
                  fontSize: 11,
                  color: const Color(0xFF64748B)),
            ),
          ],
        ),
        // Stripe lock icon + progress bar
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress < 100 ? _progress / 100 : null,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: const Color(0xFF6366F1),
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Payment?',
            style: context.af(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
          'Your payment is not complete. Are you sure you want to leave?',
          style: context.af(fontSize: 13, color: const Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Going',
                style: context.af(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6366F1))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);          // close dialog
              Navigator.pop(context, false); // close checkout
            },
            child: Text('Leave',
                style: context.af(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }
}
