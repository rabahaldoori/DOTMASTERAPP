import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/font_ext.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';

// ── Brand colours (mirrors login_screen.dart) ─────────────────────────────────
const _navy  = Color(0xFF020F22);
const _navy2 = Color(0xFF05183A);
const _blue  = Color(0xFF0453CD);
const _cyan  = Color(0xFF06B6D4);
const _white = Colors.white;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ── Step index: 0 = Personal Info, 1 = Company Info, 2 = Security ──────────
  int _step = 0;

  // ── Controllers ──────────────────────────────────────────────────────────────
  final _firstCtrl   = TextEditingController();
  final _lastCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _pass2Ctrl   = TextEditingController();

  bool _obscure1   = true;
  bool _obscure2   = true;
  bool _loading    = false;
  String? _error;

  late final AnimationController _anim;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    for (final c in [_firstCtrl, _lastCtrl, _emailCtrl, _phoneCtrl,
                     _companyCtrl, _passCtrl, _pass2Ctrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validation per step ───────────────────────────────────────────────────────
  String? _validateStep() {
    final s = context.read<LocaleProvider>().s;
    if (_step == 0) {
      if (_firstCtrl.text.trim().isEmpty || _lastCtrl.text.trim().isEmpty ||
          _emailCtrl.text.trim().isEmpty) {
        return s.allFieldsRequired;
      }
      if (!_emailCtrl.text.contains('@')) return s.invalidCredentials;
    } else if (_step == 1) {
      if (_companyCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
        return s.allFieldsRequired;
      }
    } else {
      if (_passCtrl.text.isEmpty || _pass2Ctrl.text.isEmpty) {
        return s.allFieldsRequired;
      }
      if (_passCtrl.text.length < 8) return s.passwordMinLength;
      if (_passCtrl.text != _pass2Ctrl.text) return s.passwordsDoNotMatch;
    }
    return null;
  }

  void _nextStep() {
    final err = _validateStep();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() { _error = null; _step++; });
    _anim
      ..reset()
      ..forward();
  }

  void _prevStep() {
    setState(() { _error = null; _step--; });
    _anim
      ..reset()
      ..forward();
  }

  // ── Submit ────────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final err = _validateStep();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final res = await ApiClient.register(
        email:       _emailCtrl.text.trim(),
        firstName:   _firstCtrl.text.trim(),
        lastName:    _lastCtrl.text.trim(),
        phone:       _phoneCtrl.text.trim(),
        password:    _passCtrl.text,
        password2:   _pass2Ctrl.text,
        companyName: _companyCtrl.text.trim(),
      );

      if (res.statusCode == 201) {
        // Save tokens & user data just like login
        await ApiClient.saveTokens(res.data['access'], res.data['refresh']);
        final userData = res.data['user'] as Map<String, dynamic>? ?? {};
        await ApiClient.saveUser(userData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.read<LocaleProvider>().s.registrationSuccess,
                  style: context.af(color: _white)),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
          // Owner → admin dashboard
          context.go('/dashboard');
        }
      }
    } catch (e) {
      // Try to extract a readable server error message
      String msg = context.read<LocaleProvider>().s.registrationFailed;
      if (e is Exception) {
        final eStr = e.toString();
        if (eStr.contains('email') && eStr.contains('already')) {
          msg = 'This email is already registered.';
        } else if (eStr.contains('400')) {
          msg = 'Please check your details and try again.';
        }
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _navy,
        body: Stack(children: [

          // Animated background orbs (same as login)
          const _BackgroundOrbs(),

          SafeArea(
            child: Column(children: [
              // ── Top bar ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go('/login'),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white70, size: 18),
                    ),
                  ),
                  const Spacer(),
                  // Step indicator dots
                  Row(children: List.generate(3, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _step == i ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _step == i ? _cyan : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ))),
                  const Spacer(),
                  const SizedBox(width: 38), // balance back button
                ]),
              ),

              // ── Content ──────────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: Consumer<LocaleProvider>(builder: (_, lp, __) {
                        final s = lp.strings;
                        return Column(children: [

                          const SizedBox(height: 8),

                          // ── Header ─────────────────────────────────────────
                          _TrialBadge(label: s.trialBadge),
                          const SizedBox(height: 14),
                          Text(s.registerYourCompany, style: context.af(
                              fontSize: 28, fontWeight: FontWeight.w900,
                              color: _white, letterSpacing: -0.5)),
                          const SizedBox(height: 8),
                          Text(s.companyRegistrationSubtitle,
                            textAlign: TextAlign.center,
                            style: context.af(fontSize: 13, color: Colors.white38, height: 1.5)),
                          const SizedBox(height: 24),

                          // ── Step label ─────────────────────────────────────
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            _stepLabel(0, s.step1PersonalInfo),
                            const SizedBox(width: 6),
                            Container(width: 20, height: 1,
                                color: Colors.white.withValues(alpha: 0.15)),
                            const SizedBox(width: 6),
                            _stepLabel(1, s.step2CompanyInfo),
                            const SizedBox(width: 6),
                            Container(width: 20, height: 1,
                                color: Colors.white.withValues(alpha: 0.15)),
                            const SizedBox(width: 6),
                            _stepLabel(2, s.step3Security),
                          ]),
                          const SizedBox(height: 20),

                          // ── Glass form card ─────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10)),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 40, offset: const Offset(0, 16))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Error banner
                                if (_error != null) ...[
                                  _ErrorBanner(message: _error!),
                                  const SizedBox(height: 16),
                                ],

                                // Step fields
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  switchInCurve: Curves.easeOut,
                                  child: _stepFields(s),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Nav buttons ─────────────────────────────────────
                          if (_step < 2)
                            _GradientButton(
                              label: s.next,
                              icon: Icons.arrow_forward_rounded,
                              loading: false,
                              onTap: _nextStep,
                            )
                          else
                            _GradientButton(
                              label: s.startFreeTrial,
                              icon: Icons.rocket_launch_rounded,
                              loading: _loading,
                              onTap: _submit,
                            ),

                          if (_step > 0) ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _prevStep,
                              child: Text(s.previous, style: context.af(
                                  fontSize: 13, color: Colors.white38,
                                  fontWeight: FontWeight.w500)),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // ── Sign in link ────────────────────────────────────
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(s.alreadyHaveAccount, style: context.af(
                                fontSize: 13, color: Colors.white38)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => context.go('/login'),
                              child: Text(s.signInInstead, style: context.af(
                                  fontSize: 13, color: _cyan,
                                  fontWeight: FontWeight.w700)),
                            ),
                          ]),
                          const SizedBox(height: 32),
                        ]);
                      }),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Step field sets ──────────────────────────────────────────────────────────
  Widget _stepFields(AppStrings s) {
    if (_step == 0) {
      return Column(key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        _RegLabel(s.firstName),
        const SizedBox(height: 8),
        _RegField(controller: _firstCtrl, hint: 'John',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words),
        const SizedBox(height: 14),
        _RegLabel(s.lastName),
        const SizedBox(height: 8),
        _RegField(controller: _lastCtrl, hint: 'Smith',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words),
        const SizedBox(height: 14),
        _RegLabel(s.emailAddress),
        const SizedBox(height: 8),
        _RegField(controller: _emailCtrl, hint: 'you@company.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
      ]);
    } else if (_step == 1) {
      return Column(key: const ValueKey(1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        _RegLabel(s.companyName),
        const SizedBox(height: 8),
        _RegField(controller: _companyCtrl, hint: 'Acme Trucking LLC',
            icon: Icons.business_outlined,
            textCapitalization: TextCapitalization.words),
        const SizedBox(height: 14),
        _RegLabel(s.phoneNumber),
        const SizedBox(height: 8),
        _RegField(controller: _phoneCtrl, hint: '+1 (555) 000-0000',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone),
      ]);
    } else {
      return Column(key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        _RegLabel(s.password),
        const SizedBox(height: 8),
        _RegField(
          controller: _passCtrl, hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscure: _obscure1,
          suffix: IconButton(
            icon: Icon(_obscure1
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
                size: 18, color: Colors.white38),
            onPressed: () => setState(() => _obscure1 = !_obscure1),
          ),
        ),
        const SizedBox(height: 14),
        _RegLabel(s.confirmPassword),
        const SizedBox(height: 8),
        _RegField(
          controller: _pass2Ctrl, hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscure: _obscure2,
          onSubmitted: (_) => _submit(),
          suffix: IconButton(
            icon: Icon(_obscure2
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
                size: 18, color: Colors.white38),
            onPressed: () => setState(() => _obscure2 = !_obscure2),
          ),
        ),
        const SizedBox(height: 12),
        // Password strength hint
        Row(children: [
          const Icon(Icons.info_outline_rounded, size: 13,
              color: Colors.white24),
          const SizedBox(width: 6),
          Text(context.read<LocaleProvider>().s.passwordMinLength,
              style: context.af(fontSize: 11, color: Colors.white24)),
        ]),
      ]);
    }
  }

  Widget _stepLabel(int idx, String label) {
    final active = idx == _step;
    final done   = idx < _step;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 20, height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? _cyan : (active ? _blue : Colors.white12),
          border: Border.all(
            color: active ? _cyan : Colors.transparent, width: 1.5),
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check, size: 11, color: Colors.white)
              : Text('${idx + 1}', style: context.af(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: active ? Colors.white : Colors.white38)),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: context.af(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: active ? _white : Colors.white30)),
    ]);
  }
}

// ── Trial badge chip ──────────────────────────────────────────────────────────
class _TrialBadge extends StatelessWidget {
  final String label;
  const _TrialBadge({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_cyan.withValues(alpha: 0.20), _blue.withValues(alpha: 0.20)]),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _cyan.withValues(alpha: 0.45)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.stars_rounded, color: _cyan, size: 14),
      const SizedBox(width: 6),
      Text(label, style: context.af(
          fontSize: 11, fontWeight: FontWeight.w700, color: _cyan)),
    ]),
  );
}

// ── Error banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded,
          color: Color(0xFFEF4444), size: 17),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: context.af(
          fontSize: 12, color: const Color(0xFFFCA5A5)))),
    ]),
  );
}

// ── Field label ───────────────────────────────────────────────────────────────
class _RegLabel extends StatelessWidget {
  final String text;
  const _RegLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: context.af(
      fontSize: 12, fontWeight: FontWeight.w600,
      color: Colors.white60, letterSpacing: 0.4));
}

// ── Glass text field ──────────────────────────────────────────────────────────
class _RegField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Widget? suffix;
  final void Function(String)? onSubmitted;

  const _RegField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    onSubmitted: onSubmitted,
    style: context.af(color: _white, fontSize: 14),
    cursorColor: _cyan,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: context.af(color: Colors.white24, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white38, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _cyan, width: 1.5),
      ),
    ),
  );
}

// ── Gradient CTA button ───────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: loading
              ? [const Color(0xFF334155), const Color(0xFF1E293B)]
              : [const Color(0xFF0A5FE8), const Color(0xFF031DAA)]),
        boxShadow: loading ? [] : [
          BoxShadow(color: _blue.withValues(alpha: 0.45),
              blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Center(
        child: loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label, style: context.af(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _white)),
                const SizedBox(width: 8),
                Icon(icon, color: _white, size: 18),
              ]),
      ),
    ),
  );
}

// ── Animated background orbs (mirrors login_screen.dart) ─────────────────────
class _BackgroundOrbs extends StatefulWidget {
  const _BackgroundOrbs();
  @override
  State<_BackgroundOrbs> createState() => _BackgroundOrbsState();
}

class _BackgroundOrbsState extends State<_BackgroundOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Stack(children: [
        Positioned(
          right: -80 + _c.value * 20,
          top:   -60 + _c.value * 30,
          child: Container(width: 300, height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _blue.withValues(alpha: 0.25), Colors.transparent]))),
        ),
        Positioned(
          left:   -60 + _c.value * 15,
          bottom: size.height * 0.25 - _c.value * 20,
          child: Container(width: 220, height: 220,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _cyan.withValues(alpha: 0.15), Colors.transparent]))),
        ),
        Positioned(
          right: size.width * 0.3,
          top:   size.height * 0.35 + _c.value * 15,
          child: Container(width: 120, height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _blue.withValues(alpha: 0.18), Colors.transparent]))),
        ),
      ]),
    );
  }
}
