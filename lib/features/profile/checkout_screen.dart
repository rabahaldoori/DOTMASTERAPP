import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../core/api_client.dart';
import '../../core/font_ext.dart';

/// Full-page premium checkout screen.
/// Navigate to it with [CheckoutScreen.push] passing the plan details.
class CheckoutScreen extends StatefulWidget {
  final String planSlug;
  final String planName;
  final String planSubtitle;
  final int    priceUsd;
  final Color  accentColor;
  final List<String> features;

  const CheckoutScreen({
    super.key,
    required this.planSlug,
    required this.planName,
    required this.planSubtitle,
    required this.priceUsd,
    required this.accentColor,
    required this.features,
  });

  /// Convenience push. Returns `true` if payment succeeded.
  static Future<bool> push(
    BuildContext context, {
    required String planSlug,
    required String planName,
    required String planSubtitle,
    required int    priceUsd,
    required Color  accentColor,
    required List<String> features,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CheckoutScreen(
          planSlug:    planSlug,
          planName:    planName,
          planSubtitle: planSubtitle,
          priceUsd:    priceUsd,
          accentColor: accentColor,
          features:    features,
        ),
      ),
    );
    return result == true;
  }

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with SingleTickerProviderStateMixin {

  // ── State ────────────────────────────────────────────────────────────────────
  bool   _loading        = true;
  bool   _paying         = false;
  String _errorMsg       = '';
  String _clientSecret   = '';
  String _publishableKey = '';

  // Card state — store latest details for debug; complete check bypassed
  CardFieldInputDetails? _cardDetails;
  bool get _cardComplete => _cardDetails?.complete ?? false;

  // Billing fields
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _zipCtrl   = TextEditingController();
  bool get _billingReady =>
      _nameCtrl.text.trim().isNotEmpty &&
      _emailCtrl.text.trim().contains('@') &&
      _zipCtrl.text.trim().length >= 4;
  // Gate on billing + secret only; Stripe confirmPayment validates the card
  bool get _readyToPay => _billingReady && !_paying && _clientSecret.isNotEmpty;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  // ── Colours ──────────────────────────────────────────────────────────────────
  static const _navy = Color(0xFF031634);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl,
        curve: Curves.easeOut);
    _nameCtrl.addListener(_rebuild);
    _emailCtrl.addListener(_rebuild);
    _zipCtrl.addListener(_rebuild);
    _initPayment();
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameCtrl.removeListener(_rebuild);
    _emailCtrl.removeListener(_rebuild);
    _zipCtrl.removeListener(_rebuild);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  // ── Fetch client secret ───────────────────────────────────────────────────────
  Future<void> _initPayment() async {
    setState(() { _loading = true; _errorMsg = ''; });
    try {
      final res  = await ApiClient.getPaymentSheetData(widget.planSlug);
      final data = res.data as Map<String, dynamic>;

      _publishableKey = data['publishable_key'] as String;
      _clientSecret   = data['client_secret']   as String;

      Stripe.publishableKey = _publishableKey;
      await Stripe.instance.applySettings();

      setState(() => _loading = false);
      _fadeCtrl.forward();
    } catch (e) {
      debugPrint('[Checkout] _initPayment error: $e');
      setState(() {
        _loading  = false;
        _errorMsg = 'Could not initialise checkout. Please try again.\n\nError: $e';
      });
      _fadeCtrl.forward(); // ← must forward so the error banner is visible
    }
  }

  // ── Confirm payment ──────────────────────────────────────────────────────────
  Future<void> _pay() async {
    if (!_readyToPay) return;
    setState(() { _paying = true; _errorMsg = ''; });
    try {
      final result = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: _clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              name:  _nameCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              address: Address(
                postalCode: _zipCtrl.text.trim(),
                country: 'US',
                city: null,
                line1: null,
                line2: null,
                state: null,
              ),
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (result.status == PaymentIntentsStatus.Succeeded) {
        // Extract payment intent ID from client secret (pi_xxx_secret_yyy → pi_xxx)
        final paymentIntentId = _clientSecret.split('_secret_').first;
        // Activate subscription on our backend immediately (don't wait for webhook)
        try {
          await ApiClient.confirmStripePayment(
            paymentIntentId: paymentIntentId,
            plan: widget.planSlug,
          );
        } catch (e) {
          debugPrint('[Checkout] confirm-payment call failed: $e');
          // Non-fatal: webhook will still activate it eventually
        }
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMsg = 'Payment not completed. Status: ${result.status.name}');
      }
    } on StripeException catch (e) {
      setState(() => _errorMsg = e.error.localizedMessage ?? 'Payment failed.');
    } catch (e) {
      setState(() => _errorMsg = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final bottom = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [

            // ── Hero app bar ────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: _navy,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              title: Text('Checkout',
                  style: context.af(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17)),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: _HeroBanner(
                  planName:    widget.planName,
                  planSubtitle: widget.planSubtitle,
                  priceUsd:    widget.priceUsd,
                  accent:      accent,
                  features:    widget.features,
                ),
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottom),
                child: _loading
                    ? _LoadingCard(accent: accent)
                    : _errorMsg.isNotEmpty && _clientSecret.isEmpty
                        // Init failed — show error + retry prominently
                        ? _ErrorBanner(message: _errorMsg, onRetry: _initPayment)
                        : FadeTransition(
                            opacity: _fadeAnim,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [

                                // Order summary strip
                                _OrderSummary(
                                  planName: widget.planName,
                                  priceUsd: widget.priceUsd,
                              accent:   accent,
                            ),
                            const SizedBox(height: 16),

                            // Billing details
                            _BillingCard(
                              accent:    accent,
                              nameCtrl:  _nameCtrl,
                              emailCtrl: _emailCtrl,
                              zipCtrl:   _zipCtrl,
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 16),

                            // Card form
                            _CardFormCard(
                              accent: accent,
                              onChanged: (details) {
                                debugPrint(
                                  '[Stripe] card changed: '
                                  'complete=${details?.complete} '
                                  'brand=${details?.brand}'
                                );
                                setState(() => _cardDetails = details);
                              },
                            ),
                            const SizedBox(height: 16),

                            // Error banner
                            if (_errorMsg.isNotEmpty) ...[
                              _ErrorBanner(message: _errorMsg,
                                  onRetry: _initPayment),
                              const SizedBox(height: 16),
                            ],

                            // Trust badges
                            const _TrustRow(),
                            const SizedBox(height: 24),

                            // Pay button
                            _PayButton(
                              priceUsd:  widget.priceUsd,
                              accent:    accent,
                              enabled:   _readyToPay,
                              loading:   _paying,
                              onTap:     _pay,
                            ),

                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                'Cancel anytime · Billed monthly · Secure payment',
                                style: context.af(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8)),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero banner ───────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String planName;
  final String planSubtitle;
  final int    priceUsd;
  final Color  accent;
  final List<String> features;

  const _HeroBanner({
    required this.planName,
    required this.planSubtitle,
    required this.priceUsd,
    required this.accent,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            const Color(0xFF031634),
            const Color(0xFF0A2347),
            accent.withValues(alpha: 0.8),
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(planName,
                            style: context.af(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(planSubtitle,
                            style: context.af(
                                fontSize: 13,
                                color: Colors.white60)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(text: '\$',
                              style: context.af(
                                  fontSize: 18,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600)),
                          TextSpan(text: '$priceUsd',
                              style: context.af(
                                  fontSize: 38,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900)),
                        ]),
                      ),
                      Text('/mo',
                          style: context.af(
                              fontSize: 12, color: Colors.white54)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Order summary ─────────────────────────────────────────────────────────────
class _OrderSummary extends StatelessWidget {
  final String planName;
  final int    priceUsd;
  final Color  accent;
  const _OrderSummary({
    required this.planName,
    required this.priceUsd,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long_rounded, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Order Summary',
              style: context.af(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: const Color(0xFF1E293B))),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Text('$planName Plan · Monthly',
              style: context.af(fontSize: 13, color: const Color(0xFF475569)))),
          Text('\$$priceUsd.00',
              style: context.af(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Billed today',
              style: context.af(fontSize: 12, color: const Color(0xFF94A3B8)))),
          Text('\$$priceUsd.00',
              style: context.af(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: accent)),
        ]),
      ]),
    );
  }

}

// \u2500\u2500 Billing details card \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
class _BillingCard extends StatelessWidget {
  final Color  accent;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController zipCtrl;
  final VoidCallback onChanged;

  const _BillingCard({
    required this.accent,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.zipCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.person_outline_rounded, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Billing Details',
              style: context.af(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: const Color(0xFF1E293B))),
        ]),
        const SizedBox(height: 16),
        _BillingField(
          controller: nameCtrl,
          label: 'Full Name',
          hint: 'John Smith',
          icon: Icons.badge_outlined,
          type: TextInputType.name,
          accent: accent,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 12),
        _BillingField(
          controller: emailCtrl,
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
          type: TextInputType.emailAddress,
          accent: accent,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 12),
        _BillingField(
          controller: zipCtrl,
          label: 'ZIP / Postal Code',
          hint: '10001',
          icon: Icons.location_on_outlined,
          type: TextInputType.number,
          accent: accent,
          onChanged: (_) => onChanged(),
          maxLength: 10,
        ),
      ]),
    );
  }
}

class _BillingField extends StatelessWidget {
  final TextEditingController controller;
  final String  label;
  final String  hint;
  final IconData icon;
  final TextInputType type;
  final Color   accent;
  final void Function(String) onChanged;
  final int?    maxLength;

  const _BillingField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.type,
    required this.accent,
    required this.onChanged,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: context.af(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B))),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: type,
        maxLength: maxLength,
        onChanged: onChanged,
        style: context.af(fontSize: 14, color: const Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: context.af(fontSize: 14, color: const Color(0xFFCBD5E1)),
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accent, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}

// \u2500\u2500 Card form card \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
class _CardFormCard extends StatelessWidget {
  final Color  accent;
  final void Function(CardFieldInputDetails?) onChanged;

  const _CardFormCard({required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.credit_card_rounded, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Card Details',
              style: context.af(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: const Color(0xFF1E293B))),
          const Spacer(),
          // Card brand icons
          Row(children: [
            _CardIcon(icon: '💳'),
          ]),
        ]),
        const SizedBox(height: 20),

        // ── Embedded card form ─────────────────────────────────────────────
        SizedBox(
          height: 60,
          child: CardField(
            onCardChanged: onChanged,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),
        Row(children: [
          Icon(Icons.lock_outline_rounded,
              size: 13, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 5),
          Expanded(child: Text(
            'Your card info is encrypted and never stored on our servers.',
            style: context.af(fontSize: 11, color: const Color(0xFF94A3B8)),
          )),
        ]),
      ]),
    );
  }
}

class _CardIcon extends StatelessWidget {
  final String icon;
  const _CardIcon({required this.icon});
  @override
  Widget build(BuildContext context) =>
      Text(icon, style: const TextStyle(fontSize: 18));
}

// ── Trust row ─────────────────────────────────────────────────────────────────
class _TrustRow extends StatelessWidget {
  const _TrustRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TrustBadge(
            icon: Icons.verified_user_outlined,
            label: 'SSL Encrypted'),
        const SizedBox(width: 20),
        _TrustBadge(
            icon: Icons.replay_rounded,
            label: 'Cancel Anytime'),
        const SizedBox(width: 20),
        _TrustBadge(
            icon: Icons.support_agent_outlined,
            label: '24/7 Support'),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _TrustBadge({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, size: 20, color: const Color(0xFF64748B)),
      const SizedBox(height: 4),
      Text(label,
          style: context.af(fontSize: 9, color: const Color(0xFF94A3B8))),
    ]);
  }
}

// ── Error banner ─────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String  message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: Color(0xFFEF4444), size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: context.af(
                fontSize: 12, color: const Color(0xFFDC2626)))),
        GestureDetector(
          onTap: onRetry,
          child: Text('Retry',
              style: context.af(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFDC2626))),
        ),
      ]),
    );
  }
}

// ── Loading card ─────────────────────────────────────────────────────────────
class _LoadingCard extends StatelessWidget {
  final Color accent;
  const _LoadingCard({required this.accent});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      child: Column(children: [
        CircularProgressIndicator(color: accent, strokeWidth: 2.5),
        const SizedBox(height: 16),
        Text('Preparing secure checkout…',
            style: context.af(
                fontSize: 13, color: const Color(0xFF64748B))),
      ]),
    );
  }
}

// ── Pay button ───────────────────────────────────────────────────────────────
class _PayButton extends StatelessWidget {
  final int      priceUsd;
  final Color    accent;
  final bool     enabled;
  final bool     loading;
  final VoidCallback onTap;

  const _PayButton({
    required this.priceUsd,
    required this.accent,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: enabled
            ? LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: enabled ? null : const Color(0xFFE2E8F0),
        boxShadow: enabled ? [BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 16, offset: const Offset(0, 6))] : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded,
                          color: enabled ? Colors.white
                              : const Color(0xFFCBD5E1),
                          size: 18),
                      const SizedBox(width: 10),
                      Text(
                        enabled
                            ? 'Pay \$$priceUsd.00 / month'
                            : 'Enter card details to continue',
                        style: context.af(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: enabled ? Colors.white
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
