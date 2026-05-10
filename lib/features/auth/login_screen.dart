import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/biometric_service.dart';
import '../../core/theme.dart';
import '../../core/onesignal_service.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/font_ext.dart';

// ── Brand colours ──────────────────────────────────────────────────────────────
const _navy    = Color(0xFF020F22);
const _navy2   = Color(0xFF05183A);
const _blue    = Color(0xFF0453CD);
const _cyan    = Color(0xFF06B6D4);
const _white   = Colors.white;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;
  bool _remember   = false;
  bool _loading    = false;
  bool _bioLoading = false;
  bool _bioVisible = false;          // show button only when canAuthenticate()
  bool _featureRegistration = true;  // default ON until API responds
  String? _biometricName;            // 'Face ID' | 'Fingerprint' | null
  BiometricType? _biometricType;
  String? _error;

  final _bio = BiometricService();   // singleton — mirrors fly365

  late final AnimationController _anim;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
    _initBiometric();
    _loadFeatureFlags();
  }

  Future<void> _loadFeatureFlags() async {
    try {
      final res  = await ApiClient.getLegalContent();
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _featureRegistration = data['feature_registration'] as bool? ?? true;
      });
    } catch (_) { /* keep default */ }
  }

  Future<void> _initBiometric() async {
    try {
      // getAvailableBiometrics = enrolled biometrics; may be empty on some devices
      // even though they support biometrics (e.g. not set up yet in iOS Settings)
      final types = await _bio.getAvailableBiometrics();

      // Detect type: prefer face, fall back to fingerprint/strong/weak
      BiometricType? type;
      if (types.contains(BiometricType.face)) {
        type = BiometricType.face;
      } else if (types.any((t) =>
          t == BiometricType.fingerprint ||
          t == BiometricType.strong ||
          t == BiometricType.weak)) {
        type = BiometricType.fingerprint;
      } else {
        // Fallback: check device hardware support directly
        final deviceSupported = await _bio.isAvailable();
        if (deviceSupported) type = BiometricType.fingerprint; // generic
      }

      final name    = _bio.getBiometricName(types.isNotEmpty ? types : (type != null ? [type] : []));
      final canAuth = await _bio.canAuthenticate();

      if (mounted) setState(() {
        _biometricName = name;
        _biometricType = type;
        _bioVisible    = canAuth;
      });
    } catch (_) {}
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  // ── Biometric Login ────────────────────────────────────────────────────────

  Future<void> _biometricLogin() async {
    if (_bioLoading) return;
    setState(() { _bioLoading = true; _error = null; });
    try {
      // Verify the user with hardware biometric / passcode
      final authenticated = await _bio.authenticate(
        reason: 'Sign in to DOT Master with ${_biometricName ?? "biometrics"}',
      );
      if (!authenticated) {
        setState(() => _bioLoading = false);
        return;
      }

      // Use the dedicated biometric refresh token (survives logout)
      final bioRefreshToken = await _bio.getStoredRefreshToken();
      if (bioRefreshToken == null) {
        if (!mounted) return;
        final s = context.read<LocaleProvider>().s;
        setState(() {
          _bioLoading = false;
          _bioVisible = false;
          _error = s.sessionExpiredPleaseSignIn;
        });
        return;
      }

      // Exchange biometric refresh token for a new access token
      final refreshed = await ApiClient.refreshWithToken(bioRefreshToken);
      if (!refreshed) {
        if (!mounted) return;
        final s = context.read<LocaleProvider>().s;
        setState(() {
          _bioLoading = false;
          _bioVisible = false;
          _error = s.sessionExpiredPleaseSignIn;
        });
        return;
      }

      // Sync the new refresh token back into the biometric store
      final newRefresh = await ApiClient.getRefreshToken();
      if (newRefresh != null) await _bio.syncRefreshToken(newRefresh);

      // Restore user profile
      try {
        final profile = await ApiClient.getProfile();
        final data = profile.data as Map<String, dynamic>?;
        if (data != null) await ApiClient.saveUser(data);
      } catch (_) {}

      final role = await ApiClient.getUserRole();
      if (role != null && mounted) {
        context.go(role == 'driver' ? '/driver-dashboard' : '/dashboard');
      } else {
        if (mounted) setState(() => _error = context.read<LocaleProvider>().s.couldNotRestoreSession);
      }
    } catch (e) {
      if (mounted) setState(() => _error = context.read<LocaleProvider>().s.biometricFailed);
    } finally {
      if (mounted) setState(() => _bioLoading = false);
    }
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (res.statusCode == 200) {
        await ApiClient.saveTokens(res.data['access'], res.data['refresh']);
        Map<String, dynamic>? profileData;
        try {
          final profile = await ApiClient.getProfile();
          profileData = profile.data as Map<String, dynamic>?;
          await ApiClient.saveUser(profileData ?? {});
        } catch (_) {}
        final role = await ApiClient.getUserRole();
        try {
          final userId = profileData?['id']?.toString()
              ?? res.data['user']?['id']?.toString() ?? '';
          if (userId.isNotEmpty) {
            await OneSignalService.identifyUser(
              userId:      userId,
              role:        role ?? 'driver',
              companyId:   profileData?['company_id']?.toString(),
              companyName: profileData?['company_name'] as String?,
              driverId:    profileData?['driver_profile_id']?.toString(),
            );
          }
        } catch (_) {}
        if (mounted) {
          final refreshToken = res.data['refresh'] as String? ?? '';
          await _promptFaceIdEnrollment(_emailCtrl.text.trim(), refreshToken);
          if (mounted) context.go(role == 'driver' ? '/driver-dashboard' : '/dashboard');
        }
      }
    } catch (e) {
      setState(() {
        _error = context.read<LocaleProvider>().s.invalidCredentials;
      });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  /// Show biometric opt-in dialog after first successful password login.
  Future<void> _promptFaceIdEnrollment(String email, String refreshToken) async {
    // Skip if already enabled
    if (await _bio.isEnabled()) return;
    // Skip if already asked (user said "Not Now" before)
    if (await _bio.wasAsked()) return;
    // Skip if hardware unavailable
    if (!await _bio.isAvailable()) return;

    await _bio.markAsked();
    if (!mounted) return;

    final isFace  = _biometricType == BiometricType.face;
    final bioLabel = _biometricName ?? (isFace ? 'Face ID' : 'Fingerprint');
    final bioIcon  = isFace ? Icons.face_unlock_outlined : Icons.fingerprint_rounded;

    final wantsEnable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2952),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4),
                blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: _blue.withOpacity(0.4)),
              ),
              child: Icon(bioIcon, color: _cyan, size: 32),
            ),
            const SizedBox(height: 16),
            Text('${context.read<LocaleProvider>().s.enableBiometricTitle} $bioLabel?',
                style: context.af(fontSize: 20, fontWeight: FontWeight.w800, color: _white)),
            const SizedBox(height: 8),
            Text(
              context.read<LocaleProvider>().s.enableBiometricBody,
              textAlign: TextAlign.center,
              style: context.af(fontSize: 13, color: Colors.white54, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Center(child: Text(context.read<LocaleProvider>().s.notNow,
                      style: context.af(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white60))),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0A5FE8), Color(0xFF031DAA)]),
                    boxShadow: [BoxShadow(color: _blue.withOpacity(0.4),
                        blurRadius: 14, offset: const Offset(0, 4))],
                  ),
                  child: Center(child: Text(context.read<LocaleProvider>().s.enable,
                      style: context.af(fontSize: 14, fontWeight: FontWeight.w700, color: _white))),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );

    if (wantsEnable == true && mounted) {
      // BiometricService.enable() verifies biometric hardware works,
      // then stores username + dedicated refresh token (survives logout)
      final success = await _bio.enable(email, refreshToken);
      if (success && mounted) setState(() => _bioVisible = true);
    }
  }

  Future<void> _forgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2952),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: _blue.withOpacity(0.4)),
              ),
              child: const Icon(Icons.lock_reset_rounded, color: _cyan, size: 24),
            ),
            const SizedBox(height: 14),
            Text(context.read<LocaleProvider>().s.resetPassword,
                style: context.af(fontSize: 18, fontWeight: FontWeight.w700, color: _white)),
            const SizedBox(height: 6),
            Text(context.read<LocaleProvider>().s.resetPasswordSubtitle,
                textAlign: TextAlign.center,
                style: context.af(fontSize: 13, color: Colors.white54)),
            const SizedBox(height: 20),
            _GlassField(
              controller: emailCtrl,
              hint: 'driver@dotmaster.app',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _OutlineBtn(
                label: context.read<LocaleProvider>().s.cancel,
                onTap: () => Navigator.pop(ctx),
              )),
              const SizedBox(width: 10),
              Expanded(child: _SolidBtn(
                label: context.read<LocaleProvider>().s.sendLink,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ApiClient.forgotPassword(emailCtrl.text.trim());
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.read<LocaleProvider>().s.resetLinkSent,
                            style: context.af(color: _white)),
                        backgroundColor: const Color(0xFF16A34A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  } catch (_) {}
                },
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _navy,
        body: Stack(children: [

          // ── Animated background orbs ─────────────────────────────────────
          const _BackgroundOrbs(),

          // ── Scrollable content ───────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                   child: Column(children: [
                    // ── Logo block (shifted up without changing size) ───────
                    Transform.translate(
                      offset: const Offset(0, -28),
                      child: _LogoBlock(),
                    ),
                    const SizedBox(height: 12),

                    // ── Glass card ─────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.10)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 40, offset: const Offset(0, 16)),
                        ],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        // Title
                        Builder(builder: (ctx) {
                          final s = ctx.watch<LocaleProvider>().s;
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.welcomeBack, style: ctx.af(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: _cyan, letterSpacing: 1.4)),
                            const SizedBox(height: 4),
                            Text(s.signInToAccount, style: ctx.af(
                                fontSize: 22, fontWeight: FontWeight.w800, color: _white)),
                          ]);
                        }),
                        const SizedBox(height: 24),

                        // Error banner
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFEF4444).withOpacity(0.35)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFEF4444), size: 17),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!,
                                  style: context.af(
                                      fontSize: 12, color: const Color(0xFFFCA5A5)))),
                            ]),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Email
                        _FieldLabel(context.watch<LocaleProvider>().s.emailAddress),
                        const SizedBox(height: 6),
                        _GlassField(
                          controller: _emailCtrl,
                          hint: 'driver@dotmaster.app',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 10),

                        // Password
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          _FieldLabel(context.watch<LocaleProvider>().s.password),
                          GestureDetector(
                            onTap: _forgotPassword,
                            child: Text(context.watch<LocaleProvider>().s.forgotQ,
                                style: context.af(fontSize: 12, color: _cyan, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        _GlassField(
                          controller: _passCtrl,
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          onSubmitted: (_) => _login(),
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18, color: Colors.white38),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Remember me
                        GestureDetector(
                          onTap: () => setState(() => _remember = !_remember),
                          child: Row(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                color: _remember
                                    ? _blue : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _remember
                                      ? _blue : Colors.white.withOpacity(0.20)),
                              ),
                              child: _remember
                                  ? const Icon(Icons.check, size: 13,
                                      color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text(context.watch<LocaleProvider>().s.rememberDevice,
                                style: context.af(fontSize: 13, color: Colors.white70)),
                          ]),
                        ),
                        const SizedBox(height: 10),

                        // Sign In Button
                        _SignInButton(loading: _loading, onTap: _login),
                      ]),
                    ),

                    // OR divider + biometric button — only shown when canAuthenticate()
                    if (_bioVisible) ...[
                      const SizedBox(height: 28),
                      Row(children: [
                        Expanded(child: Container(height: 1,
                            color: Colors.white.withOpacity(0.08))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('OR', style: context.af(
                              fontSize: 10, color: Colors.white30,
                              fontWeight: FontWeight.w600, letterSpacing: 1)),
                        ),
                        Expanded(child: Container(height: 1,
                            color: Colors.white.withOpacity(0.08))),
                      ]),
                      const SizedBox(height: 20),
                      _FaceIdButton(
                        loading: _bioLoading,
                        onTap: _biometricLogin,
                        biometricType: _biometricType,
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Register link (shown only when registration is enabled) ─
                    if (_featureRegistration)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Builder(builder: (ctx) {
                        final s = ctx.watch<LocaleProvider>().s;
                        return Row(children: [
                          Text(s.dontHaveAccount, style: ctx.af(
                              fontSize: 13, color: Colors.white38)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => context.go('/register'),
                            child: Text(s.createAccount, style: ctx.af(
                                fontSize: 13, color: _cyan,
                                fontWeight: FontWeight.w700)),
                          ),
                        ]);
                      }),
                    ]),

                    const SizedBox(height: 36),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Background animated orbs ───────────────────────────────────────────────────
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
        // Top-right large orb
        Positioned(
          right: -80 + _c.value * 20,
          top: -60 + _c.value * 30,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _blue.withOpacity(0.25), Colors.transparent]),
            ),
          ),
        ),
        // Bottom-left orb
        Positioned(
          left: -60 + _c.value * 15,
          bottom: size.height * 0.25 - _c.value * 20,
          child: Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _cyan.withOpacity(0.15), Colors.transparent]),
            ),
          ),
        ),
        // Centre accent dot
        Positioned(
          right: size.width * 0.3,
          top: size.height * 0.35 + _c.value * 15,
          child: Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _blue.withOpacity(0.18), Colors.transparent]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Logo block ─────────────────────────────────────────────────────────────────
class _LogoBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
    // Lottie truck animation with glow
    Stack(alignment: Alignment.center, children: [
      // Soft glow behind animation
      Container(
        width: 150, height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            _blue.withOpacity(0.30), Colors.transparent]),
        ),
      ),
      // Lottie animation
      Lottie.asset(
        'assets/images/truck_orange.json',
        width: 190,
        height: 190,
        fit: BoxFit.contain,
        repeat: true,
      ),
    ]),
    const SizedBox(height: 4),
    Builder(builder: (ctx) {
      final s = ctx.watch<LocaleProvider>().s;
      return Column(children: [
        Text('DOT Comply', style: ctx.af(
            fontSize: 30, fontWeight: FontWeight.w900, color: _white,
            letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Text(s.fuelComplianceSubtitle,
            textAlign: TextAlign.center,
            style: ctx.af(fontSize: 13, color: Colors.white38)),
      ]);
    }),
  ]);
}

// ── Field label ────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: context.af(
      fontSize: 12, fontWeight: FontWeight.w600,
      color: Colors.white60, letterSpacing: 0.4));
}

// ── Glass text field ───────────────────────────────────────────────────────────
class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final void Function(String)? onSubmitted;

  const _GlassField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    onSubmitted: onSubmitted,
    style: context.af(color: _white, fontSize: 13),
    cursorColor: _cyan,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: context.af(color: Colors.white24, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white38, size: 17),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _cyan, width: 1.5),
      ),
    ),
  );
}

// ── Sign In button ─────────────────────────────────────────────────────────────
class _SignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SignInButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: loading
              ? [const Color(0xFF334155), const Color(0xFF1E293B)]
              : [const Color(0xFF0A5FE8), const Color(0xFF031DAA)]),
        boxShadow: loading ? [] : [
          BoxShadow(color: _blue.withOpacity(0.45),
              blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Center(
        child: loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(context.read<LocaleProvider>().s.signIn,
                    style: context.af(fontSize: 15, fontWeight: FontWeight.w700,
                    color: _white)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    color: _white, size: 18),
              ]),
      ),
    ),
  );
}

// ── Face ID button ─────────────────────────────────────────────────────────────
class _FaceIdButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  final BiometricType? biometricType;
  const _FaceIdButton({required this.loading, required this.onTap, this.biometricType});

  @override
  Widget build(BuildContext context) {
    final isFace = biometricType != BiometricType.fingerprint;
    final s = context.watch<LocaleProvider>().s;
    final label  = isFace ? s.signInWithFaceId : s.signInWithFingerprint;

    return GestureDetector(
      onTap: loading ? null : () { HapticFeedback.lightImpact(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: loading
                  ? _cyan.withOpacity(0.60)
                  : Colors.white.withOpacity(0.12),
              width: 1.5),
          boxShadow: loading
              ? [BoxShadow(color: _cyan.withOpacity(0.15), blurRadius: 12)]
              : [],
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: _cyan, strokeWidth: 2)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (isFace)
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                        Colors.white, BlendMode.srcIn),
                    child: SizedBox(
                      width: 26, height: 26,
                      child: Image.asset(
                        'assets/images/face-id.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.fingerprint_rounded,
                      color: Colors.white, size: 26),
                const SizedBox(width: 10),
                Text(label,
                    style: context.af(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ]),
      ),
    );
  }
}

// ── Face ID custom painter ─────────────────────────────────────────────────────
class _FaceIdPainter extends CustomPainter {
  final Color color;
  const _FaceIdPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    const r = 3.5; // corner radius of brackets
    const arm = 7.0; // length of each bracket arm

    // ── Corner brackets ────────────────────────────────────────────────────────
    // Top-left
    canvas.drawPath(Path()
      ..moveTo(0, arm + r)
      ..arcToPoint(Offset(r, r), radius: const Radius.circular(r))
      ..lineTo(arm, 0), paint);

    // Top-right
    canvas.drawPath(Path()
      ..moveTo(w - arm, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, arm + r), paint);

    // Bottom-left
    canvas.drawPath(Path()
      ..moveTo(0, h - arm - r)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: const Radius.circular(r))
      ..lineTo(arm, h), paint);

    // Bottom-right
    canvas.drawPath(Path()
      ..moveTo(w - arm, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: const Radius.circular(r))
      ..lineTo(w, h - arm - r), paint);

    // ── Face features ──────────────────────────────────────────────────────────
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Left eye
    canvas.drawCircle(Offset(w * 0.35, h * 0.38), 1.3, dot);
    // Right eye
    canvas.drawCircle(Offset(w * 0.65, h * 0.38), 1.3, dot);

    // Smile arc
    final smilePath = Path();
    smilePath.moveTo(w * 0.33, h * 0.60);
    smilePath.quadraticBezierTo(w * 0.50, h * 0.75, w * 0.67, h * 0.60);
    canvas.drawPath(smilePath, paint);

    // Nose (tiny vertical line)
    canvas.drawLine(
      Offset(w * 0.50, h * 0.46),
      Offset(w * 0.50, h * 0.56),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FaceIdPainter old) => old.color != color;
}


// ── Outline button (dialog) ───────────────────────────────────────────────────
class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Center(child: Text(label, style: context.af(
          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white60))),
    ),
  );
}

// ── Solid button (dialog) ─────────────────────────────────────────────────────
class _SolidBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SolidBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A5FE8), Color(0xFF031DAA)]),
      ),
      child: Center(child: Text(label, style: context.af(
          fontSize: 13, fontWeight: FontWeight.w600, color: _white))),
    ),
  );
}
