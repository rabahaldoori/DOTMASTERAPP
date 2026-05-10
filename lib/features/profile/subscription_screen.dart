import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/font_ext.dart';
import 'checkout_screen.dart';

// ── Colours ───────────────────────────────────────────────────────────────────
const _navy  = Color(0xFF031634);
const _blue  = Color(0xFF0453CD);
const _cyan  = Color(0xFF06B6D4);
const _surf  = Color(0xFFF0F3FA);

// ── Plan accent palette (index order matches backend sort_order) ──────────────
const _planColors = [
  Color(0xFF06B6D4),  // trial   – cyan
  Color(0xFF0453CD),  // starter – blue
  Color(0xFF7C3AED),  // growth  – purple (popular)
  Color(0xFF0891B2),  // fleet   – teal
];

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loading     = true;
  String _error     = '';
  List<Map<String, dynamic>> _plans = [];

  String _currentPlan   = '';
  bool   _isTrialing    = false;
  int    _daysLeft      = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final results = await Future.wait([
        ApiClient.getPricing(),
        ApiClient.getSubscription(),
      ]);

      final plans = (results[0].data as List).cast<Map<String, dynamic>>();
      final sub   = results[1].data as Map<String, dynamic>;

      setState(() {
        _plans       = plans;
        _currentPlan = sub['plan']?.toString() ?? '';
        _isTrialing  = sub['is_trialing'] == true;
        _daysLeft    = (sub['days_left'] ?? 0) as int;
        _loading     = false;
      });
    } catch (e) {
      setState(() {
        _error   = 'Could not load plans. Please try again.';
        _loading = false;
      });
    }
  }

  Color _colorForIndex(int i) =>
      _planColors[i.clamp(0, _planColors.length - 1)];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surf,
        body: CustomScrollView(slivers: [

          // ── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
            ),
            title: Text('Subscription', style: context.af(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF031634), Color(0xFF0A2347), Color(0xFF0453CD)],
                    stops: [0, 0.55, 1]),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Choose Your Plan', style: context.af(
                            fontSize: 22, fontWeight: FontWeight.w900,
                            color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Manage your subscription & unlock more features',
                            style: context.af(fontSize: 12, color: Colors.white54)),
                        if (_currentPlan.isNotEmpty && !_loading) ...[
                          const SizedBox(height: 10),
                          _CurrentPlanPill(
                            plan:       _currentPlan,
                            isTrialing: _isTrialing,
                            daysLeft:   _daysLeft,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _blue)))
          else if (_error.isNotEmpty)
            SliverFillRemaining(
              child: _ErrorRetry(message: _error, onRetry: _load))
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 20, 16,
                  32 + 80 + MediaQuery.of(context).padding.bottom),
              sliver: SliverList(delegate: SliverChildListDelegate([

                if (_isTrialing && _daysLeft <= 7) ...[
                  _UrgencyBanner(daysLeft: _daysLeft),
                  const SizedBox(height: 16),
                ],

                ..._plans.asMap().entries.map((e) {
                  final i         = e.key;
                  final plan      = e.value;
                  final isCurrent = plan['slug'] == _currentPlan;
                  final isPopular = plan['is_popular'] == true;
                  final color     = _colorForIndex(i);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PlanCard(
                      plan:      plan,
                      color:     color,
                      isCurrent: isCurrent,
                      isPopular: isPopular,
                      onSuccess: _load,
                    ),
                  );
                }),

                const SizedBox(height: 8),
                Center(
                  child: Text('Need a custom plan?  support@dotmaster.app',
                      style: context.af(fontSize: 12,
                          color: const Color(0xFF94A3B8))),
                ),
              ])),
            ),
        ]),
      ),
    );
  }
}

// ── Current plan pill ─────────────────────────────────────────────────────────
class _CurrentPlanPill extends StatelessWidget {
  final String plan;
  final bool   isTrialing;
  final int    daysLeft;
  const _CurrentPlanPill({
    required this.plan,
    required this.isTrialing,
    required this.daysLeft,
  });
  @override
  Widget build(BuildContext context) {
    final label = isTrialing
        ? 'Free Trial · $daysLeft days left'
        : plan[0].toUpperCase() + plan.substring(1);
    final color = isTrialing
        ? (daysLeft <= 3 ? const Color(0xFFEF4444)
           : daysLeft <= 7 ? const Color(0xFFF97316)
           : _cyan)
        : _cyan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isTrialing ? Icons.access_time_rounded
            : Icons.verified_rounded, color: color, size: 13),
        const SizedBox(width: 5),
        Text(label, style: context.af(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }
}

// ── Urgency banner ────────────────────────────────────────────────────────────
class _UrgencyBanner extends StatelessWidget {
  final int daysLeft;
  const _UrgencyBanner({required this.daysLeft});
  @override
  Widget build(BuildContext context) {
    final color = daysLeft <= 3 ? const Color(0xFFEF4444)
                                : const Color(0xFFF97316);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(
          daysLeft <= 3
              ? 'Your trial expires in $daysLeft days! Upgrade now to avoid losing access.'
              : 'Only $daysLeft days left on your free trial. Upgrade to keep all features.',
          style: context.af(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────
class _PlanCard extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Color        color;
  final bool         isCurrent;
  final bool         isPopular;
  final VoidCallback onSuccess;
  const _PlanCard({
    required this.plan,
    required this.color,
    required this.isCurrent,
    required this.isPopular,
    required this.onSuccess,
  });
  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _checkingOut = false;

  Future<void> _startCheckout(
    BuildContext context,
    String slug,
    String name,
    Color color,
    String subtitle,
    int price,
    List<String> features,
  ) async {
    setState(() => _checkingOut = true);
    try {
      final success = await CheckoutScreen.push(
        context,
        planSlug:     slug,
        planName:     name,
        planSubtitle: subtitle,
        priceUsd:     price,
        accentColor:  color,
        features:     features,
      );
      if (!mounted) return;
      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Subscribed to $name!',
                style: context.af(color: Colors.white)),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onSuccess();
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name      = widget.plan['name']?.toString()     ?? '';
    final subtitle  = widget.plan['subtitle']?.toString() ?? '';
    final price     = (widget.plan['price'] as num?)?.toInt() ?? 0;
    final features  = (widget.plan['features'] as List?)?.cast<String>() ?? [];
    final maxTrucks = widget.plan['max_trucks'];
    final color     = widget.color;
    final isCurrent = widget.isCurrent;
    final isPopular = widget.isPopular;
    final slug      = widget.plan['slug']?.toString() ?? '';

    // ── Active card uses deep navy body so all text/icons pop clearly ─────
    const activeBody  = Color(0xFF0D1B2E);
    final bodyColor   = isCurrent ? activeBody : Colors.white;
    final featureText = isCurrent
        ? Colors.white.withValues(alpha: 0.90)
        : const Color(0xFF475569);
    final featureIcon = isCurrent ? Colors.white : color;

    return Stack(clipBehavior: Clip.none, children: [

      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bodyColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isCurrent ? color : const Color(0xFFE8EDF5),
              width: isCurrent ? 2.5 : 1),
          boxShadow: [BoxShadow(
              color: isCurrent
                  ? color.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isCurrent ? 26 : 18,
              spreadRadius: isCurrent ? 1 : 0,
              offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Gradient header ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.78)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.af(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: Colors.white)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: context.af(
                          fontSize: 11, color: Colors.white70)),
                    ],
                    if (maxTrucks != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.local_shipping_outlined,
                            color: Colors.white60, size: 12),
                        const SizedBox(width: 4),
                        Text('Up to $maxTrucks trucks',
                            style: context.af(fontSize: 11, color: Colors.white60)),
                      ]),
                    ],
                  ],
                )),
                // Price
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  price == 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text('Free', style: context.af(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: Colors.white)),
                        )
                      : Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('\$', style: context.af(fontSize: 14,
                                fontWeight: FontWeight.w700, color: Colors.white70)),
                            Text('$price', style: context.af(fontSize: 28,
                                fontWeight: FontWeight.w900, color: Colors.white)),
                          ]),
                          Text('/mo', style: context.af(
                              fontSize: 10, color: Colors.white60)),
                        ]),
                ]),
              ],
            ),
          ),

          // ── Features ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Column(
              children: features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.check_circle_rounded,
                      color: featureIcon, size: 15),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: context.af(
                      fontSize: 12, color: featureText))),
                ]),
              )).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // ── CTA ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: SizedBox(
              width: double.infinity,
              child: isCurrent
                  // Solid gradient button with white text — clearly visible on dark bg
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.72)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                          color: color.withValues(alpha: 0.38),
                          blurRadius: 14, offset: const Offset(0, 4),
                        )],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 17),
                          const SizedBox(width: 8),
                          Text('Current Plan', style: context.af(
                              fontSize: 14, fontWeight: FontWeight.w800,
                              color: Colors.white)),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: _checkingOut ? null : () => _startCheckout(
                          context, slug, name, color, subtitle, price, features),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: _checkingOut
                                  ? [color.withValues(alpha: 0.6),
                                     color.withValues(alpha: 0.5)]
                                  : [color, color.withValues(alpha: 0.80)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _checkingOut ? [] : [BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _checkingOut
                              ? [
                                  const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white)),
                                  const SizedBox(width: 8),
                                  Text('Opening…', style: context.af(
                                      fontSize: 13, fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                                ]
                              : [
                                  Text('Select $name Plan', style: context.af(
                                      fontSize: 13, fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 14, color: Colors.white),
                                ],
                        ),
                      ),
                    ),
            ),
          ),
        ]),
      ),

      // ── Most Popular badge ──────────────────────────────────────────────
      if (isPopular)
        Positioned(
          top: -10, right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded, color: Colors.white, size: 11),
              const SizedBox(width: 4),
              Text('Most Popular', style: context.af(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: Colors.white)),
            ]),
          ),
        ),

      // ── Active badge (floats above top-left corner) ─────────────────────
      if (isCurrent)
        Positioned(
          top: -10, left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.45),
                  blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 11),
              const SizedBox(width: 4),
              Text('Active', style: context.af(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: Colors.white)),
            ]),
          ),
        ),
    ]);
  }
}

// ── Error + retry ─────────────────────────────────────────────────────────────
class _ErrorRetry extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off_rounded, color: Color(0xFF94A3B8), size: 48),
      const SizedBox(height: 12),
      Text(message, style: context.af(color: const Color(0xFF64748B),
          fontSize: 14), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      TextButton.icon(
        icon: const Icon(Icons.refresh_rounded, color: _blue),
        label: Text('Retry', style: context.af(color: _blue,
            fontWeight: FontWeight.w600)),
        onPressed: onRetry,
      ),
    ]),
  );
}
