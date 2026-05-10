import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/font_ext.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/l10n/language_picker.dart';
import '../../core/l10n/app_strings.dart';

const _navy  = Color(0xFF031634);
const _navy2 = Color(0xFF0D2952);
const _blue  = Color(0xFF0453CD);
const _cyan  = Color(0xFF06B6D4);
const _green = Color(0xFF16A34A);
const _red   = Color(0xFFDC2626);
const _surf  = Color(0xFFF0F3FA);
const _bord  = Color(0xFFDCE2F3);
const _grey  = Color(0xFF64748B);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _user = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res  = await ApiClient.getProfile();
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _user = {
          'name':       data['full_name'] ?? data['username'] ?? 'User',
          'email':      data['email']     ?? '',
          'role':       data['role']      ?? 'admin',
          'company':    data['company_name'] ?? '',
          'phone':      data['phone']     ?? '',
          'avatar_url': data['avatar_url'] ?? data['avatar'] ?? '',
        };
        _loading = false;
      });
    } catch (_) {
      final cached = await ApiClient.getUser();
      if (!mounted) return;
      setState(() { _user = Map<String, dynamic>.from(cached); _loading = false; });
    }
  }

  // ── Personal Information sheet ──────────────────────────────────────────────
  void _showPersonalInfo(BuildContext context) {
    final s = context.read<LocaleProvider>().s;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final name    = _user['name']    ?? '';
        final email   = _user['email']   ?? '';
        final phone   = _user['phone']   ?? '';
        final role    = (_user['role']   ?? '').toString()
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
        final company = _user['company'] ?? '';
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _SheetHandle(),
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: _blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_outline_rounded,
                    color: _blue, size: 20)),
              const SizedBox(width: 12),
              Text(s.personalInformation, style: context.af(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _navy)),
            ]),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _InfoCell(icon: Icons.badge_outlined,    label: s.fullName,  value: name.isEmpty    ? '—' : name),
                _InfoCell(icon: Icons.email_outlined,    label: s.email,     value: email.isEmpty   ? '—' : email),
                _InfoCell(icon: Icons.phone_outlined,    label: s.phone,     value: phone.isEmpty   ? '—' : phone),
                _InfoCell(icon: Icons.work_outline,      label: s.role,      value: role.isEmpty    ? '—' : role),
                _InfoCell(icon: Icons.business_outlined, label: s.company,   value: company.isEmpty ? '—' : company),
              ],
            ),
          ]),
        );
      },
    );
  }

  // ── Security & Privacy sheet ─────────────────────────────────────────────────
  void _showSecurity(BuildContext context) {
    final s = context.read<LocaleProvider>().s;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _SheetHandle(),
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.lock_outline_rounded,
                      color: Color(0xFF7C3AED), size: 20)),
                const SizedBox(width: 12),
                Text(s.securityPrivacy, style: context.af(
                    fontSize: 17, fontWeight: FontWeight.w700, color: _navy)),
              ]),
              const SizedBox(height: 20),
              _SheetToggleRow(
                icon: Icons.face_unlock_outlined,
                iconColor: _blue,
                label: s.faceIdBiometric,
                subtitle: s.signInWithoutPassword,
                value: true,
                onChanged: (v) {},
              ),
              Container(height: 1, color: const Color(0xFFF1F5F9),
                  margin: const EdgeInsets.symmetric(vertical: 4)),
              GestureDetector(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  _showChangePassword(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: _grey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.key_outlined, size: 18, color: _grey)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.changePassword, style: context.af(
                          fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
                      Text(s.updateLoginPassword, style: context.af(fontSize: 12, color: _grey)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFCBD5E1)),
                  ]),
                ),
              ),
              Container(height: 1, color: const Color(0xFFF1F5F9),
                  margin: const EdgeInsets.symmetric(vertical: 4)),
              GestureDetector(
                onTap: () => _showPrivacyPolicy(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: _green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.privacy_tip_outlined, size: 18, color: _green)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.privacyPolicy, style: context.af(
                          fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
                      Text(s.howWeHandleData, style: context.af(fontSize: 12, color: _grey)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFCBD5E1)),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    final s = context.read<LocaleProvider>().s;
    // Mutable state — starts as defaults; will be overwritten once API loads
    bool push  = true;
    bool email = true;
    bool sms   = false;
    bool loading = true;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          // Load prefs from backend the first time
          if (loading) {
            ApiClient.getNotificationPrefs().then((res) {
              if (ctx.mounted) {
                setS(() {
                  push    = res.data['push']  ?? true;
                  email   = res.data['email'] ?? true;
                  sms     = res.data['sms']   ?? false;
                  loading = false;
                });
              }
            }).catchError((_) {
              if (ctx.mounted) setS(() => loading = false);
            });
          }

          Future<void> toggle({bool? newPush, bool? newEmail, bool? newSms}) async {
            // Optimistic UI update
            setS(() {
              if (newPush  != null) push  = newPush;
              if (newEmail != null) email = newEmail;
              if (newSms   != null) sms   = newSms;
            });
            HapticFeedback.selectionClick();
            try {
              await ApiClient.updateNotificationPrefs(
                push:  newPush,
                email: newEmail,
                sms:   newSms,
              );
            } catch (_) {
              // Revert on failure
              setS(() {
                if (newPush  != null) push  = !newPush;
                if (newEmail != null) email = !newEmail;
                if (newSms   != null) sms   = !newSms;
              });
            }
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _SheetHandle(),
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.notifications_outlined,
                      color: _cyan, size: 20)),
                const SizedBox(width: 12),
                Text(s.notificationSettings, style: context.af(
                    fontSize: 17, fontWeight: FontWeight.w700, color: _navy)),
              ]),
              const SizedBox(height: 8),
              Text(s.chooseNotifications,
                  style: context.af(fontSize: 13, color: _grey)),
              const SizedBox(height: 16),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(
                      color: Color(0xFF0453CD), strokeWidth: 2)),
                )
              else ...[
                _SheetToggleRow(
                  icon: Icons.notifications_active_outlined,
                  iconColor: _cyan,
                  label: s.pushNotifications,
                  subtitle: s.pushNotifSubtitle,
                  value: push,
                  onChanged: (v) => toggle(newPush: v),
                ),
                Container(height: 1, color: const Color(0xFFF1F5F9),
                    margin: const EdgeInsets.symmetric(vertical: 4)),
                _SheetToggleRow(
                  icon: Icons.email_outlined,
                  iconColor: _blue,
                  label: s.emailNotifications,
                  subtitle: s.emailNotifSubtitle,
                  value: email,
                  onChanged: (v) => toggle(newEmail: v),
                ),
                Container(height: 1, color: const Color(0xFFF1F5F9),
                    margin: const EdgeInsets.symmetric(vertical: 4)),
                _SheetToggleRow(
                  icon: Icons.sms_outlined,
                  iconColor: _green,
                  label: s.smsNotifications,
                  subtitle: s.smsNotifSubtitle,
                  value: sms,
                  onChanged: (v) => toggle(newSms: v),
                  last: true,
                ),
              ],
            ]),
          );
        },
      ),
    );
  }

  // ── Help & Support sheet ─────────────────────────────────────────────────────
  void _showHelpSupport(BuildContext context) {
    final s = context.read<LocaleProvider>().s;
    const faqs = [
      (
        q: 'How do I add a fuel log?',
        a: 'Go to the Fuel tab in the bottom navigation bar. Tap the + button to create a new fuel purchase. Fill in the date, gallons, price, jurisdiction, and truck details, then tap Save.'
      ),
      (
        q: 'How do I submit an IFTA report?',
        a: 'Navigate to Reports → IFTA. Select the quarter and year, then tap Generate Report. Review the totals and tap Submit or Export PDF to download your quarterly IFTA fuel tax report.'
      ),
      (
        q: 'How do I add a new trip?',
        a: 'Open the Trips tab and tap the + icon. Enter the origin, destination, truck, driver, and start/end odometer readings. The app calculates total miles automatically.'
      ),
      (
        q: 'I forgot my password. How do I reset it?',
        a: 'On the login screen, tap "Forgot Password?" and enter your registered email address. You will receive a reset link within a few minutes. Check your spam folder if you don\'t see it.'
      ),
      (
        q: 'How do I enable Face ID / biometric login?',
        a: 'Go to Profile → Security & Privacy and toggle on "Face ID / Biometric Login." You will be prompted to authenticate once to confirm. After that, you can log in using biometrics.'
      ),
      (
        q: 'My company data is not showing. What should I do?',
        a: 'Ensure you are logged in with the correct account and that your company subscription is active. If your trial has expired, contact your account owner to upgrade. If the issue persists, log out and log back in.'
      ),
    ];

    // Support contact info — loaded from API
    String supportEmail    = 'support@dotmaster.app';
    String supportPhone    = '+1 (800) DOT-MASTER';
    String supportDialable = '+18003681234';
    String waLabel         = 'Chat with us on WhatsApp';
    bool contactLoading    = true;
    final openIndex        = ValueNotifier<int?>(null);

    // Load contact info immediately before showing the sheet
    ApiClient.getLegalContent().then((res) {
      supportEmail    = (res.data['support_email']          ?? supportEmail).toString();
      supportPhone    = (res.data['support_phone']          ?? supportPhone).toString();
      supportDialable = (res.data['support_phone_dialable'] ?? supportDialable).toString();
      waLabel         = (res.data['support_whatsapp_label'] ?? waLabel).toString();
      contactLoading  = false;
    }).catchError((_) {
      contactLoading = false;
    });

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => StatefulBuilder(
          builder: (ctx, setS) {
            // Once API loaded, trigger re-render of this subtree
            if (contactLoading) {
              ApiClient.getLegalContent().then((res) {
                if (ctx.mounted) setS(() {
                  supportEmail    = (res.data['support_email']          ?? supportEmail).toString();
                  supportPhone    = (res.data['support_phone']          ?? supportPhone).toString();
                  supportDialable = (res.data['support_phone_dialable'] ?? supportDialable).toString();
                  waLabel         = (res.data['support_whatsapp_label'] ?? waLabel).toString();
                  contactLoading  = false;
                });
              }).catchError((_) {
                if (ctx.mounted) setS(() => contactLoading = false);
              });
            }
            return ValueListenableBuilder<int?>(
              valueListenable: openIndex,
          builder: (ctx, open, _) => Column(children: [
            // ── Header (sticky) ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(children: [
                _SheetHandle(),
                Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: const Color(0xFF64748B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.help_outline_rounded,
                        color: Color(0xFF64748B), size: 20)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.helpSupport, style: context.af(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: _navy)),
                    Text(s.weAreHereToHelp, style: context.af(
                        fontSize: 12, color: _grey)),
                  ]),
                ]),
                const SizedBox(height: 16),
                Container(height: 1, color: const Color(0xFFF1F5F9)),
              ]),
            ),

            // ── Scrollable body ─────────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // Contact tiles — loaded from backend
                  _SupportContactTile(
                    icon: Icons.email_outlined,
                    color: _blue,
                    title: s.emailSupport,
                    subtitle: supportEmail,
                    onTap: () async {
                      final uri = Uri(
                        scheme: 'mailto',
                        path: supportEmail,
                        queryParameters: {
                          'subject': 'DOT Master Support Request',
                        },
                      );
                      if (await canLaunchUrl(uri)) launchUrl(uri);
                    },
                  ),
                  const SizedBox(height: 10),
                  _SupportContactTile(
                    icon: Icons.phone_outlined,
                    color: _green,
                    title: s.callSupport,
                    subtitle: supportPhone,
                    onTap: () async {
                      final uri = Uri(scheme: 'tel', path: supportDialable);
                      if (await canLaunchUrl(uri)) launchUrl(uri);
                    },
                  ),
                  const SizedBox(height: 10),
                  _SupportContactTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: const Color(0xFF25D366),
                    title: s.whatsappSupport,
                    subtitle: waLabel,
                    onTap: () async {
                      final waNum = supportDialable.replaceAll('+', '');
                      final uri = Uri.parse(
                          'https://wa.me/$waNum?text=Hello%2C%20I%20need%20help%20with%20DOT%20Master');
                      if (await canLaunchUrl(uri)) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  // FAQ section
                  Text(s.frequentlyAsked,
                      style: context.af(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: _navy, letterSpacing: 0.3)),
                  const SizedBox(height: 10),

                  ...List.generate(faqs.length, (i) {
                    final isOpen = open == i;
                    return GestureDetector(
                      onTap: () => openIndex.value = isOpen ? null : i,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isOpen
                              ? _blue.withOpacity(0.04)
                              : Colors.white,
                          border: Border.all(
                            color: isOpen
                                ? _blue.withOpacity(0.25)
                                : const Color(0xFFE2E8F0),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Expanded(child: Text(faqs[i].q,
                                    style: context.af(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: isOpen ? _blue : _navy))),
                                Icon(
                                  isOpen
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: isOpen ? _blue : _grey,
                                  size: 20,
                                ),
                              ]),
                            ),
                            if (isOpen)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                child: Text(faqs[i].a,
                                    style: context.af(
                                        fontSize: 13,
                                        color: const Color(0xFF475569),
                                        height: 1.6)),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Version info footer
                  Center(child: Text(
                    'DOT Master v1.0.0  •  $supportEmail',
                    style: context.af(
                        fontSize: 11, color: const Color(0xFFCBD5E1)),
                  )),
                ],
              ),
            ),
          ]),
          ); // ValueListenableBuilder
        },
      ), // StatefulBuilder
      ),
    );
  }

  // ── Privacy Policy sheet ─────────────────────────────────────────────────────
  void _showPrivacyPolicy(BuildContext context) {
    final s = context.read<LocaleProvider>().s;
    String content = '';
    bool loading = true;
    String? error;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          if (loading && error == null) {
            ApiClient.getLegalContent().then((res) {
              if (ctx.mounted) setS(() {
                content = (res.data['privacy_policy'] ?? '').toString().trim();
                loading = false;
              });
            }).catchError((e) {
              if (ctx.mounted) setS(() {
                error = 'Unable to load Privacy Policy. Please try again.';
                loading = false;
              });
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollCtrl) => Column(children: [
              // Handle + header (non-scrolling)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(children: [
                  _SheetHandle(),
                  Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: _green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.privacy_tip_outlined,
                          color: _green, size: 20)),
                    const SizedBox(width: 12),
                    Text(s.privacyPolicy, style: context.af(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: _navy)),
                  ]),
                  const SizedBox(height: 16),
                  Container(height: 1, color: const Color(0xFFF1F5F9)),
                ]),
              ),
              // Content (scrollable)
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator(
                        color: Color(0xFF0453CD), strokeWidth: 2))
                    : error != null
                        ? Center(child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(error!,
                                textAlign: TextAlign.center,
                                style: context.af(
                                    fontSize: 13, color: _grey)),
                          ))
                        : content.isEmpty
                            ? Center(child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.article_outlined,
                                      size: 48, color: const Color(0xFFCBD5E1)),
                                  const SizedBox(height: 12),
                                  Text(s.privacyPolicyNotSet,
                                      style: context.af(
                                          fontSize: 14, color: _grey)),
                                ],
                              ))
                            : ListView(
                                controller: scrollCtrl,
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                                children: [
                                  SelectableText(
                                    content,
                                    style: context.af(
                                        fontSize: 13.5,
                                        color: const Color(0xFF334155),
                                        height: 1.75),
                                  ),
                                ],
                              ),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── Change Password sheet ────────────────────────────────────────────────────
  void _showChangePassword(BuildContext context) {
    final s = context.read<LocaleProvider>().s;
    final oldCtrl  = TextEditingController();
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    bool oldObscure  = true;
    bool newObscure  = true;
    bool confObscure = true;
    bool loading   = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> submit() async {
            final s2   = ctx.read<LocaleProvider>().s;
            final old  = oldCtrl.text.trim();
            final nw   = newCtrl.text.trim();
            final conf = confCtrl.text.trim();
            if (old.isEmpty || nw.isEmpty || conf.isEmpty) {
              setS(() => errorMsg = s2.fillAllFields);
              return;
            }
            if (nw.length < 8) {
              setS(() => errorMsg = s2.passwordMin8);
              return;
            }
            if (nw != conf) {
              setS(() => errorMsg = s2.passwordsNoMatch);
              return;
            }
            setS(() { loading = true; errorMsg = null; });
            try {
              await ApiClient.changePassword(old, nw);
              if (ctx.mounted) {
                Navigator.of(ctx, rootNavigator: true).pop();
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(s2.passwordChanged,
                      style: context.af(color: Colors.white)),
                  backgroundColor: _green,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
              }
            } catch (e) {
              String msg = s2.failedChangePassword;
              if (e.toString().contains('400') ||
                  e.toString().toLowerCase().contains('incorrect') ||
                  e.toString().toLowerCase().contains('invalid') ||
                  e.toString().toLowerCase().contains('wrong')) {
                msg = s2.currentPasswordIncorrect;
              }
              setS(() { loading = false; errorMsg = msg; });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                left: 20, right: 20, top: 0,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _SheetHandle(),
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.lock_outline_rounded,
                      color: Color(0xFF7C3AED), size: 20)),
                const SizedBox(width: 12),
                Text(s.changePassword, style: context.af(
                    fontSize: 17, fontWeight: FontWeight.w700, color: _navy)),
              ]),
              const SizedBox(height: 20),

              // Error banner
              if (errorMsg != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: _red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _red.withOpacity(0.25))),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded,
                        color: _red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(errorMsg!, style: context.af(
                        fontSize: 13, color: _red,
                        fontWeight: FontWeight.w500))),
                  ]),
                ),
                const SizedBox(height: 14),
              ],

              _PwdField(controller: oldCtrl, label: s.currentPassword,
                  obscure: oldObscure, onToggle: () => setS(() => oldObscure = !oldObscure)),
              const SizedBox(height: 12),
              _PwdField(controller: newCtrl, label: s.newPassword,
                  obscure: newObscure, onToggle: () => setS(() => newObscure = !newObscure)),
              const SizedBox(height: 12),
              _PwdField(controller: confCtrl, label: s.confirmNewPassword,
                  obscure: confObscure, onToggle: () => setS(() => confObscure = !confObscure)),
              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    disabledBackgroundColor: _navy.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(s.updatePassword, style: context.af(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    final s = context.read<LocaleProvider>().s;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15),
                  blurRadius: 40, offset: const Offset(0, 12)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _red.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: _red, size: 26),
            ),
            const SizedBox(height: 16),
            // Title
            Text(s.signOut,
                style: context.af(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 8),
            Text(s.areYouSureSignOut,
                textAlign: TextAlign.center,
                style: context.af(fontSize: 14, color: _grey)),
            const SizedBox(height: 24),
            // Buttons
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(s.cancel,
                          style: context.af(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _grey)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _red,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: _red.withOpacity(0.35),
                            blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: Text(s.signOut,
                          style: context.af(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (confirmed == true) {
      await ApiClient.logout();
      if (mounted) context.go('/login');
    }
  }

  String get _initials {
    final parts = (_user['name'] ?? '').toString().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }

  String get _avatarUrl => (_user['avatar_url'] ?? '').toString().trim();

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
    if (picked == null || !mounted) return;

    try {
      final file = File(picked.path);
      // PATCH /api/auth/me/ with multipart
      final res = await ApiClient.uploadAvatar(file);
      final url = (res.data as Map<String, dynamic>)['avatar_url'] ??
                  (res.data as Map<String, dynamic>)['avatar'] ?? '';
      if (url.toString().isNotEmpty && mounted) {
        setState(() => _user['avatar_url'] = url.toString());
      }
    } catch (e) {
      if (mounted) {
        final s2 = context.read<LocaleProvider>().s;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s2.couldNotUploadPhoto)));
      }
    }
  }

  String _roleLabel(AppStrings s) {
    switch ((_user['role'] ?? '').toString().toLowerCase()) {
      case 'admin':      return s.fleetAdministrator;
      case 'manager':    return s.fleetManager;
      case 'dispatcher': return s.dispatcher;
      default:           return s.fleetMember;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s       = context.watch<LocaleProvider>().s;
    final name    = (_user['name']    ?? 'User').toString();
    final email   = (_user['email']   ?? '').toString();
    final company = (_user['company'] ?? '').toString();
    final phone   = (_user['phone']   ?? '').toString();

    return Scaffold(
      backgroundColor: _surf,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : CustomScrollView(slivers: [
              // ── Gradient header ─────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: _navy,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                automaticallyImplyLeading: false,
                title: Text(s.myProfile, style: context.af(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [_navy, _navy2])),
                    child: Stack(children: [
                      // subtle background circles
                      Positioned(right: -40, top: -40, child: Container(
                        width: 180, height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.03)),
                      )),
                      Positioned(left: -20, bottom: 20, child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _cyan.withOpacity(0.05)),
                      )),
                      SafeArea(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // Avatar
                          Center(
                            child: GestureDetector(
                              onTap: _changePhoto,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 90, height: 90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: _avatarUrl.isEmpty
                                          ? const LinearGradient(
                                              colors: [_blue, _cyan],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight)
                                          : null,
                                      boxShadow: [BoxShadow(
                                          color: _blue.withOpacity(0.4),
                                          blurRadius: 20, offset: const Offset(0, 8))],
                                    ),
                                    child: ClipOval(
                                      child: _avatarUrl.isNotEmpty
                                          ? Image.network(
                                              _avatarUrl,
                                              width: 90, height: 90,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Center(
                                                child: Text(_initials,
                                                    style: context.af(
                                                        fontSize: 34,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.white))),
                                              loadingBuilder: (ctx, child, progress) =>
                                                progress == null
                                                    ? child
                                                    : const Center(
                                                        child: CircularProgressIndicator(
                                                            color: Colors.white, strokeWidth: 2)),
                                            )
                                          : Center(child: Text(_initials,
                                              style: context.af(fontSize: 34,
                                                  fontWeight: FontWeight.w900, color: Colors.white))),
                                    ),
                                  ),
                                  // Camera edit button
                                  Positioned(right: 0, bottom: 0,
                                    child: Container(
                                      width: 26, height: 26,
                                      decoration: BoxDecoration(
                                        color: _blue, shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: [BoxShadow(
                                            color: _blue.withOpacity(0.5), blurRadius: 6)],
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded,
                                          size: 13, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(name, textAlign: TextAlign.center,
                              style: context.af(
                                  fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(_roleLabel(s), textAlign: TextAlign.center,
                              style: context.af(fontSize: 13, color: Colors.white60)),
                          if (company.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.15)),
                              ),
                              child: Text(company, textAlign: TextAlign.center,
                                  style: context.af(
                                      fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                            ),
                          ],
                        ],
                      )),
                    ]),
                  ),
                ),
              ),

              SliverToBoxAdapter(child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16,
                    16 + 80 + MediaQuery.of(context).padding.bottom),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Contact info card ──────────────────────────────────
                  _Card(children: [
                    if (email.isNotEmpty)
                      _InfoRow(icon: Icons.email_outlined, label: s.email, value: email),
                    if (phone.isNotEmpty) ...[
                      const _Div(),
                      _InfoRow(icon: Icons.phone_outlined, label: s.phone, value: phone),
                    ],
                    if (company.isNotEmpty) ...[
                      const _Div(),
                      _InfoRow(icon: Icons.business_outlined, label: s.company, value: company),
                    ],
                    if (email.isEmpty && phone.isEmpty && company.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(s.noContactInfo, style: context.af(color: _grey)),
                      ),
                  ]),
                  const SizedBox(height: 24),

                  // ── Settings ───────────────────────────────────────────
                  _Label(s.settings),
                  const SizedBox(height: 8),
                  _Card(children: [
                    _MenuItem(
                      icon: Icons.person_outline_rounded,
                      iconColor: _blue,
                      label: s.personalInformation,
                      onTap: () => _showPersonalInfo(context),
                    ),
                    const _Div(),
                    _MenuItem(
                      icon: Icons.lock_outline_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      label: s.securityPrivacy,
                      onTap: () => _showSecurity(context),
                    ),
                    const _Div(),
                    _MenuItem(
                      icon: Icons.notifications_outlined,
                      iconColor: _cyan,
                      label: s.notificationSettings,
                      onTap: () => _showNotifications(context),
                    ),
                    const _Div(),
                    Builder(builder: (ctx) {
                      final lp = ctx.watch<LocaleProvider>();
                      return _MenuItem(
                        icon: Icons.language_rounded,
                        iconColor: const Color(0xFF059669),
                        label: s.appLanguage,
                        trailing: lp.language.code.toUpperCase(),
                        onTap: () => LanguagePicker.show(ctx),
                      );
                    }),
                  ]),
                  const SizedBox(height: 16),

                  // ── Subscription ───────────────────────────────────────────
                  _Label('SUBSCRIPTION'),
                  const SizedBox(height: 8),
                  _Card(children: [
                    _MenuItem(
                      icon: Icons.workspace_premium_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      label: 'Subscription & Plans',
                      onTap: () => context.push('/subscription'),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Support ────────────────────────────────────────────────
                  _Label(s.support),
                  const SizedBox(height: 8),
                  _Card(children: [
                    _MenuItem(
                      icon: Icons.help_outline_rounded,
                      iconColor: _grey,
                      label: s.helpSupport,
                      onTap: () => _showHelpSupport(context),
                    ),
                    const _Div(),
                    _MenuItem(
                      icon: Icons.info_outline_rounded,
                      iconColor: _grey,
                      label: s.aboutDotComply,
                      trailing: 'v1.0.0',
                      onTap: () => context.push('/about'),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Logout ─────────────────────────────────────────────
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _red.withOpacity(0.20)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.logout_rounded, color: _red, size: 20),
                        const SizedBox(width: 10),
                        Text(s.signOut, style: context.af(
                            fontSize: 15, fontWeight: FontWeight.w700, color: _red)),
                      ]),
                    ),
                  ),
                ]),
              )),
            ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: context.af(fontSize: 10, fontWeight: FontWeight.w700,
          color: _grey, letterSpacing: 0.8));
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _bord),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Column(children: children),
  );
}

class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 52, color: Color(0xFFEEF2FA));
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: _blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: _blue),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.af(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: _grey, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(value, style: context.af(fontSize: 13, fontWeight: FontWeight.w700,
            color: _navy), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.iconColor, required this.label,
      this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: context.af(
            fontSize: 14, fontWeight: FontWeight.w600, color: _navy))),
        if (trailing != null)
          Text(trailing!, style: context.af(fontSize: 13, color: _grey)),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
      ]),
    ),
  );
}

// ── Sheet helpers ─────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
    const SizedBox(height: 12),
    Container(
      width: 36, height: 4,
      decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(2)),
    ),
    const SizedBox(height: 20),
  ]);
}

class _SheetInfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool last;
  const _SheetInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: const Color(0xFF64748B))),
        const SizedBox(height: 8),
        Text(label, style: context.af(
            fontSize: 11, color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500, letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text(value,
            textAlign: TextAlign.center,
            style: context.af(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF031634))),
      ]),
    ),
    if (!last)
      Container(height: 1, color: const Color(0xFFF1F5F9)),
  ]);
}

class _SheetToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, subtitle;
  final bool value, last;
  final ValueChanged<bool> onChanged;
  const _SheetToggleRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: iconColor)),
      const SizedBox(width: 12),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.af(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: const Color(0xFF031634))),
        Text(subtitle, style: context.af(
            fontSize: 12, color: const Color(0xFF64748B))),
      ])),
      Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF0453CD),
      ),
    ]),
  );
}

// ── Info cell (used in the 2-column personal info grid) ───────────────────────
class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoCell({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5))),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(height: 5),
        Text(label, style: context.af(
            fontSize: 10, color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500, letterSpacing: 0.2)),
        const SizedBox(height: 3),
        Text(value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.af(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF031634))),
      ],
    ),
  );
}

// ── Password input field ──────────────────────────────────────────────────────
class _PwdField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  const _PwdField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      style: context.af(fontSize: 14, color: const Color(0xFF031634)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.af(
            fontSize: 13, color: const Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            size: 18, color: Color(0xFF94A3B8)),
        suffixIcon: IconButton(
          icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: const Color(0xFF94A3B8)),
          onPressed: onToggle,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
    ),
  );
}

// ── Support Contact Tile ──────────────────────────────────────────────────────
class _SupportContactTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportContactTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.af(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(subtitle, style: context.af(
                fontSize: 12, color: const Color(0xFF64748B))),
          ],
        )),
        Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: const Color(0xFFCBD5E1)),
      ]),
    ),
  );
}
