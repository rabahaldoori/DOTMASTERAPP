import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/font_ext.dart';
import '../../core/l10n/language_picker.dart';
import 'package:provider/provider.dart';

const _navy  = Color(0xFF031634);
const _blue  = Color(0xFF0453CD);
const _green = Color(0xFF10B981);
const _grey  = Color(0xFF64748B);
const _red   = Color(0xFFEF4444);
const _bg    = Color(0xFFF3F5FA);

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});
  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading   = true;
  bool _uploading = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.getDriverData();
      setState(() => _profile = Map<String, dynamic>.from(res.data['profile'] ?? {}));
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked == null || _profile == null) return;
    setState(() => _uploading = true);
    try {
      final res = await ApiClient.uploadDriverPhoto(_profile!['id'], picked.path);
      if (res.statusCode == 200 && res.data['photo'] != null) {
        setState(() => _profile!['photo'] = res.data['photo']);
        if (mounted) _snack(context.read<LocaleProvider>().s.photoUpdated, _green);
      }
    } catch (_) {
      if (mounted) _snack(context.read<LocaleProvider>().s.uploadFailed, _red);
    } finally {
      setState(() => _uploading = false);
    }
  }

  void _snack(String msg, Color col) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: context.af(color: Colors.white)),
      backgroundColor: col, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 52, height: 52,
              decoration: BoxDecoration(color: _red.withOpacity(0.10), shape: BoxShape.circle),
              child: const Icon(Icons.logout_rounded, color: _red, size: 26)),
            const SizedBox(height: 14),
            Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return Text(s.signOut, style: c.af(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)); }),
            const SizedBox(height: 6),
            Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return Text(s.areYouSureSignOut, textAlign: TextAlign.center, style: c.af(fontSize: 13, color: _grey)); }),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Builder(builder: (c) => Text(c.read<LocaleProvider>().s.cancel, style: c.af(fontWeight: FontWeight.w600, color: _grey))),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: _red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Builder(builder: (c) => Text(c.read<LocaleProvider>().s.signOut, style: c.af(fontWeight: FontWeight.w700, color: Colors.white))),
              )),
            ]),
          ]),
        ),
      ),
    );
    if (ok == true && mounted) {
      await ApiClient.logout();
      if (mounted) context.go('/login');
    }
  }

  // ── Personal Information ────────────────────────────────────────────────────
  void _showPersonalInfo() {
    final p       = _profile;
    final name    = p?['full_name'] ?? '—';
    final email   = p?['email']    ?? '—';
    final phone   = p?['phone']    ?? '—';
    final company = p?['company_name'] ?? '—';
    final cdl     = p?['cdl_number']  ?? '—';
    final state   = p?['cdl_state']   ?? '—';
    showModalBottomSheet(
      context: context, useRootNavigator: true,
      useSafeArea: true, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _DSheetHandle(),
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person_outline_rounded, color: _blue, size: 20)),
            const SizedBox(width: 12),
            Builder(builder: (c) => Text(c.read<LocaleProvider>().s.personalInformation, style: c.af(fontSize: 17, fontWeight: FontWeight.w700, color: _navy))),
          ]),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2, crossAxisSpacing: 12, mainAxisSpacing: 12,
            children: [
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DInfoCell(icon: Icons.badge_outlined,    label: s.fullName,  value: name.toString()); }),
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DInfoCell(icon: Icons.email_outlined,    label: s.email,     value: email.toString()); }),
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DInfoCell(icon: Icons.phone_outlined,    label: s.phone,     value: phone.toString()); }),
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DInfoCell(icon: Icons.business_outlined, label: s.company,   value: company.toString()); }),
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DInfoCell(icon: Icons.badge_rounded,     label: s.cdlNumber, value: cdl.toString()); }),
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DInfoCell(icon: Icons.map_outlined,      label: s.cdlState,  value: state.toString()); }),
            ],
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Security & Privacy ───────────────────────────────────────────────────────
  void _showSecurity() {
    showModalBottomSheet(
      context: context, useRootNavigator: true,
      useSafeArea: true, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _DSheetHandle(),
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF7C3AED), size: 20)),
            const SizedBox(width: 12),
            Builder(builder: (c) => Text(c.read<LocaleProvider>().s.securityPrivacy, style: c.af(fontSize: 17, fontWeight: FontWeight.w700, color: _navy))),
          ]),
          const SizedBox(height: 20),
          // Change Password
          GestureDetector(
            onTap: () { Navigator.of(context, rootNavigator: true).pop(); _showChangePassword(); },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _grey.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.key_outlined, size: 18, color: _grey)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Builder(builder: (c) => Text(c.read<LocaleProvider>().s.changePassword, style: c.af(fontSize: 14, fontWeight: FontWeight.w600, color: _navy))),
                  Builder(builder: (c) => Text(c.read<LocaleProvider>().s.updateLoginPassword, style: c.af(fontSize: 12, color: _grey))),
                ])),
                const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFCBD5E1)),
              ]),
            ),
          ),
          Container(height: 1, color: const Color(0xFFF1F5F9), margin: const EdgeInsets.symmetric(vertical: 4)),
          // Privacy Policy
          GestureDetector(
            onTap: () => _showPrivacyPolicy(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _green.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.privacy_tip_outlined, size: 18, color: _green)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Builder(builder: (c) => Text(c.read<LocaleProvider>().s.privacyPolicy, style: c.af(fontSize: 14, fontWeight: FontWeight.w600, color: _navy))),
                  Builder(builder: (c) => Text(c.read<LocaleProvider>().s.howWeHandleData, style: c.af(fontSize: 12, color: _grey))),
                ])),
                const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFCBD5E1)),
              ]),
            ),
          ),
        ]),
      )),
    );
  }

  // ── Change Password ───────────────────────────────────────────────────────────
  void _showChangePassword() {
    final oldCtrl  = TextEditingController();
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    bool oldObs = true, newObs = true, confObs = true;
    bool loading = false;
    String? errorMsg;
    showModalBottomSheet(
      context: context, useRootNavigator: true,
      useSafeArea: true, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Future<void> submit() async {
          final old = oldCtrl.text.trim(), nw = newCtrl.text.trim(), conf = confCtrl.text.trim();
          if (old.isEmpty || nw.isEmpty || conf.isEmpty) { setS(() => errorMsg = 'Please fill in all fields.'); return; }
          if (nw.length < 8) { setS(() => errorMsg = 'Password must be at least 8 characters.'); return; }
          if (nw != conf) { setS(() => errorMsg = 'Passwords do not match.'); return; }
          setS(() { loading = true; errorMsg = null; });
          try {
            await ApiClient.changePassword(old, nw);
            if (ctx.mounted) {
              Navigator.of(ctx, rootNavigator: true).pop();
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Builder(builder: (c) => Text('Password changed!', style: c.af(color: Colors.white))),
                backgroundColor: _green, behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
            }
          } catch (e) {
            String msg = 'Failed. Please try again.';
            if (e.toString().toLowerCase().contains('incorrect') || e.toString().toLowerCase().contains('wrong')) msg = 'Current password is incorrect.';
            setS(() { loading = false; errorMsg = msg; });
          }
        }
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 0, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _DSheetHandle(),
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF7C3AED), size: 20)),
              const SizedBox(width: 12),
              Builder(builder: (c) => Text(c.read<LocaleProvider>().s.changePassword, style: c.af(fontSize: 17, fontWeight: FontWeight.w700, color: _navy))),
            ]),
            const SizedBox(height: 20),
            if (errorMsg != null) ...[
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: _red.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: _red.withOpacity(0.25))),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: _red, size: 16), const SizedBox(width: 8),
                  Expanded(child: Builder(builder: (c) => Text(errorMsg!, style: c.af(fontSize: 13, color: _red, fontWeight: FontWeight.w500)))),
                ])),
              const SizedBox(height: 14),
            ],
            Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DPwdField(controller: oldCtrl, label: s.currentPassword, obscure: oldObs, onToggle: () => setS(() => oldObs = !oldObs)); }),
            const SizedBox(height: 12),
            Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DPwdField(controller: newCtrl, label: s.newPassword, obscure: newObs, onToggle: () => setS(() => newObs = !newObs)); }),
            const SizedBox(height: 12),
            Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DPwdField(controller: confCtrl, label: s.confirmNewPassword, obscure: confObs, onToggle: () => setS(() => confObs = !confObs)); }),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: loading ? null : submit,
                style: ElevatedButton.styleFrom(backgroundColor: _navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Builder(builder: (c) => Text(c.read<LocaleProvider>().s.updatePassword, style: c.af(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
              )),
          ]),
        );
      }),
    );
  }

  // ── Privacy Policy ───────────────────────────────────────────────────────────
  void _showPrivacyPolicy() {
    String content = ''; bool loading = true; String? error;
    showModalBottomSheet(
      context: context, useRootNavigator: true,
      useSafeArea: true, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (loading && error == null) {
          ApiClient.getLegalContent().then((res) {
            if (ctx.mounted) setS(() { content = (res.data['privacy_policy'] ?? '').toString().trim(); loading = false; });
          }).catchError((e) { if (ctx.mounted) setS(() { error = 'Unable to load.'; loading = false; }); });
        }
        return DraggableScrollableSheet(
          initialChildSize: 0.85, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
          builder: (_, scrollCtrl) => Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 0), child: Column(children: [
              _DSheetHandle(),
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _green.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.privacy_tip_outlined, color: _green, size: 20)),
                const SizedBox(width: 12),
                Builder(builder: (c) => Text(c.read<LocaleProvider>().s.privacyPolicy, style: c.af(fontSize: 17, fontWeight: FontWeight.w700, color: _navy))),
              ]),
              const SizedBox(height: 16),
              Container(height: 1, color: const Color(0xFFF1F5F9)),
            ])),
            Expanded(child: loading
                ? const Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2))
                : error != null ? Center(child: Builder(builder: (c) => Text(error!, style: c.af(fontSize: 13, color: _grey))))
                : content.isEmpty ? Center(child: Builder(builder: (c) => Text('Privacy Policy not set yet.', style: c.af(fontSize: 14, color: _grey))))
                : ListView(controller: scrollCtrl, padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [Builder(builder: (c) => SelectableText(content, style: c.af(fontSize: 13.5, color: const Color(0xFF334155), height: 1.75)))])),
          ]),
        );
      }),
    );
  }

  // ── Notification Settings ────────────────────────────────────────────────────
  void _showNotifications() {
    bool push = true, email = true, sms = false, loading = true;
    showModalBottomSheet(
      context: context, useRootNavigator: true,
      useSafeArea: true, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (loading) {
          ApiClient.getNotificationPrefs().then((res) {
            if (ctx.mounted) setS(() { push = res.data['push'] ?? true; email = res.data['email'] ?? true; sms = res.data['sms'] ?? false; loading = false; });
          }).catchError((_) { if (ctx.mounted) setS(() => loading = false); });
        }
        Future<void> toggle({bool? newPush, bool? newEmail, bool? newSms}) async {
          setS(() { if (newPush != null) push = newPush; if (newEmail != null) email = newEmail; if (newSms != null) sms = newSms; });
          HapticFeedback.selectionClick();
          try { await ApiClient.updateNotificationPrefs(push: newPush, email: newEmail, sms: newSms); }
          catch (_) { setS(() { if (newPush != null) push = !newPush; if (newEmail != null) email = !newEmail; if (newSms != null) sms = !newSms; }); }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _DSheetHandle(),
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.notifications_outlined, color: Color(0xFF06B6D4), size: 20)),
              const SizedBox(width: 12),
              Builder(builder: (c) => Text(c.read<LocaleProvider>().s.notificationSettings, style: c.af(fontSize: 17, fontWeight: FontWeight.w700, color: _navy))),
            ]),
            const SizedBox(height: 8),
            Builder(builder: (c) => Text(c.read<LocaleProvider>().s.chooseNotifications, style: c.af(fontSize: 13, color: _grey))),
            const SizedBox(height: 16),
            if (loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2)))
            else ...[
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DToggleRow(icon: Icons.notifications_active_outlined, iconColor: const Color(0xFF06B6D4), label: s.pushNotifications, subtitle: s.pushNotifSubtitle, value: push, onChanged: (v) => toggle(newPush: v)); }),
              Container(height: 1, color: const Color(0xFFF1F5F9), margin: const EdgeInsets.symmetric(vertical: 4)),
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DToggleRow(icon: Icons.email_outlined, iconColor: _blue, label: s.emailNotifications, subtitle: s.emailNotifSubtitle, value: email, onChanged: (v) => toggle(newEmail: v)); }),
              Container(height: 1, color: const Color(0xFFF1F5F9), margin: const EdgeInsets.symmetric(vertical: 4)),
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DToggleRow(icon: Icons.sms_outlined, iconColor: _green, label: s.smsNotifications, subtitle: s.smsNotifSubtitle, value: sms, onChanged: (v) => toggle(newSms: v)); }),
            ],
          ]),
        );
      }),
    );
  }

  void _showHelpSupport() {
    const faqs = [
      (q: 'How do I log fuel?', a: 'Go to the Fuel tab and tap + to add a new fuel purchase.'),
      (q: 'How do I start a trip?', a: 'Go to the Trips tab, tap +, fill in origin, destination, and odometer readings.'),
      (q: 'How do I complete an inspection?', a: 'Your dispatcher will assign inspections. Open Notifications to view pending inspections.'),
      (q: 'I forgot my password.', a: 'On the login screen tap "Forgot Password?" and enter your email to receive a reset link.'),
      (q: 'How do I enable biometric login?', a: 'Not available on the driver profile yet. Contact your admin.'),
    ];
    final openIndex = ValueNotifier<int?>(null);
    String supportEmail = 'support@dotmaster.app';
    String supportPhone = '+1 (800) DOT-MASTER';
    String supportDialable = '+18003681234';
    String waLabel = 'Chat with us on WhatsApp';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => StatefulBuilder(
          builder: (ctx, setS) {
            ApiClient.getLegalContent().then((res) {
              if (ctx.mounted) setS(() {
                supportEmail    = (res.data['support_email']          ?? supportEmail).toString();
                supportPhone    = (res.data['support_phone']          ?? supportPhone).toString();
                supportDialable = (res.data['support_phone_dialable'] ?? supportDialable).toString();
                waLabel         = (res.data['support_whatsapp_label'] ?? waLabel).toString();
              });
            }).catchError((_) {});
            return ValueListenableBuilder<int?>(
              valueListenable: openIndex,
              builder: (ctx, open, _) => Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(children: [
                    Container(margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 36, height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
                    Row(children: [
                      Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: _grey.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.help_outline_rounded, color: _grey, size: 20)),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Builder(builder: (c) => Text(c.read<LocaleProvider>().s.helpSupport, style: c.af(fontSize: 17, fontWeight: FontWeight.w700, color: _navy))),
                        Builder(builder: (c) => Text(c.read<LocaleProvider>().s.weAreHereToHelp, style: c.af(fontSize: 12, color: _grey))),
                      ]),
                    ]),
                    const SizedBox(height: 16),
                    Container(height: 1, color: const Color(0xFFF1F5F9)),
                  ]),
                ),
                Expanded(child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    _SupportTile(icon: Icons.email_outlined, color: _blue, title: 'Email Support', subtitle: supportEmail,
                      onTap: () async { final u = Uri(scheme: 'mailto', path: supportEmail, queryParameters: {'subject': 'Support Request'}); if (await canLaunchUrl(u)) launchUrl(u); }),
                    const SizedBox(height: 10),
                    _SupportTile(icon: Icons.phone_outlined, color: _green, title: 'Call Support', subtitle: supportPhone,
                      onTap: () async { final u = Uri(scheme: 'tel', path: supportDialable); if (await canLaunchUrl(u)) launchUrl(u); }),
                    const SizedBox(height: 10),
                    _SupportTile(icon: Icons.chat_bubble_outline_rounded, color: const Color(0xFF25D366), title: 'WhatsApp', subtitle: waLabel,
                      onTap: () async { final n = supportDialable.replaceAll('+', ''); final u = Uri.parse('https://wa.me/$n'); if (await canLaunchUrl(u)) launchUrl(u, mode: LaunchMode.externalApplication); }),
                    const SizedBox(height: 24),
                    Builder(builder: (c) => Text(c.read<LocaleProvider>().s.frequentlyAsked, style: c.af(fontSize: 13, fontWeight: FontWeight.w700, color: _navy))),
                    const SizedBox(height: 10),
                    ...List.generate(faqs.length, (i) {
                      final isOpen = open == i;
                      return GestureDetector(
                        onTap: () => openIndex.value = isOpen ? null : i,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isOpen ? _blue.withOpacity(0.04) : Colors.white,
                            border: Border.all(color: isOpen ? _blue.withOpacity(0.25) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Expanded(child: Builder(builder: (c) => Text(faqs[i].q, style: c.af(fontSize: 13.5, fontWeight: FontWeight.w600, color: isOpen ? _blue : _navy)))),
                                Icon(isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: isOpen ? _blue : _grey, size: 20),
                              ])),
                            if (isOpen) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: Builder(builder: (c) => Text(faqs[i].a, style: c.af(fontSize: 13, color: const Color(0xFF475569), height: 1.6)))),
                          ]),
                        ),
                      );
                    }),
                  ],
                )),
              ]),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator(color: _blue)));

    final p        = _profile;
    final name     = p?['full_name'] as String? ?? '—';
    final email    = p?['email']    as String? ?? '—';
    final phone    = p?['phone']    as String? ?? '—';
    final company  = p?['company_name'] as String? ?? '—';
    final initials = name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
    final photoUrl = p?['photo'] as String?;
    final cdlExpiryStr = p?['cdl_expiry'] as String?;
    final cdlDays = cdlExpiryStr != null ? DateTime.tryParse(cdlExpiryStr)?.difference(DateTime.now()).inDays : null;
    final cdlWarn = cdlDays != null && cdlDays < 90;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(slivers: [
        // ── SliverAppBar ───────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 255,
          pinned: true,
          backgroundColor: _navy,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Row(children: [
            Container(padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.15))),
              child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 14)),
            const SizedBox(width: 8),
            Builder(builder: (c) => Text(c.read<LocaleProvider>().s.myProfile, style: c.af(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
            const Spacer(),
            GestureDetector(onTap: _logout,
              child: Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _red.withOpacity(0.30))),
                child: const Icon(Icons.logout_rounded, color: _red, size: 16))),
          ]),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [_navy, Color(0xFF0A2347)])),
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.fromLTRB(0, kToolbarHeight + 2, 0, 10),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Stack(alignment: Alignment.center, children: [
                    Container(width: 80, height: 80,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2.5)),
                      child: ClipOval(child: photoUrl != null
                          ? Image.network(photoUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarFallback(initials))
                          : _avatarFallback(initials))),
                    Positioned(bottom: 0, right: 0,
                      child: GestureDetector(onTap: _uploading ? null : _pickAndUpload,
                        child: Container(width: 24, height: 24,
                          decoration: BoxDecoration(color: _uploading ? _grey : _blue,
                              shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          child: _uploading
                              ? const Padding(padding: EdgeInsets.all(3),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white)))),
                  ]),
                  const SizedBox(height: 6),
                  Text(name.toUpperCase(), style: context.af(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(email, style: context.af(fontSize: 11, color: Colors.white54)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _green.withOpacity(0.45))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 5, height: 5, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Builder(builder: (c) => Text(c.read<LocaleProvider>().s.active.toUpperCase(), style: c.af(fontSize: 9, fontWeight: FontWeight.w700, color: _green))),
                    ])),
                ]),
              )),
            ),
          ),
        ),

        // ── Body ───────────────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
          sliver: SliverList(delegate: SliverChildListDelegate([

            // CDL warning
            if (cdlWarn) ...[
              Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.withOpacity(0.35))),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('CDL expires in $cdlDays days. Renew soon.',
                      style: context.af(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600))),
                ])),
              const SizedBox(height: 16),
            ],

            // ── Profile info card ────────────────────────────────────────────
            Builder(builder: (c) => _DLabel(c.read<LocaleProvider>().s.profileSection)),
            const SizedBox(height: 8),
            _DCard(children: [
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DRow(icon: Icons.email_outlined,    iconColor: _blue, label: s.email,   value: email); }),
              const _DDivider(),
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DRow(icon: Icons.phone_outlined,    iconColor: _blue, label: s.phone,   value: phone); }),
              const _DDivider(),
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DRow(icon: Icons.business_outlined, iconColor: _blue, label: s.company, value: company); }),
            ]),
            const SizedBox(height: 20),

            // ── License Info ─────────────────────────────────────────────────
            Builder(builder: (c) => _DLabel(c.read<LocaleProvider>().s.licenseInfoSection)),
            const SizedBox(height: 8),
            _DCard(children: [
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DRow(icon: Icons.badge_outlined, iconColor: _blue, label: s.cdlNumber, value: p?['cdl_number'] ?? '—'); }),
              const _DDivider(),
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DRow(icon: Icons.map_outlined, iconColor: _blue, label: s.cdlState, value: p?['cdl_state'] ?? '—'); }),
              const _DDivider(),
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DRow(icon: Icons.event_outlined, iconColor: cdlWarn ? Colors.orange : _blue, label: s.cdlExpiry, value: cdlExpiryStr != null ? _fmt(cdlExpiryStr) : '—', valueColor: cdlWarn ? Colors.orange : null); }),
              const _DDivider(),
              Builder(builder: (c) { final s = c.read<LocaleProvider>().s; return _DRow(icon: Icons.work_history_outlined, iconColor: _blue, label: s.hireDate, value: p?['hire_date'] != null ? _fmt(p!['hire_date']) : '—'); }),
            ]),
            const SizedBox(height: 20),

            // ── Settings ─────────────────────────────────────────────────────
            Builder(builder: (c) => _DLabel(c.read<LocaleProvider>().s.settingsSection)),
            const SizedBox(height: 8),
            _DCard(children: [
              Builder(builder: (c) => _DMenuItem(icon: Icons.person_outline_rounded, iconColor: _blue, label: c.read<LocaleProvider>().s.personalInformation, onTap: _showPersonalInfo)),
              const _DDivider(),
              Builder(builder: (c) => _DMenuItem(icon: Icons.lock_outline_rounded, iconColor: const Color(0xFF8B5CF6), label: c.read<LocaleProvider>().s.securityPrivacy, onTap: _showSecurity)),
              const _DDivider(),
              Builder(builder: (c) => _DMenuItem(icon: Icons.notifications_outlined, iconColor: const Color(0xFF06B6D4), label: c.read<LocaleProvider>().s.notificationSettings, onTap: _showNotifications)),
              const _DDivider(),
              Builder(builder: (c) => _DMenuItem(icon: Icons.language_rounded, iconColor: const Color(0xFF0891B2), label: c.read<LocaleProvider>().s.changeLanguage, onTap: () => LanguagePicker.show(context))),
            ]),
            const SizedBox(height: 20),

            // ── Support ──────────────────────────────────────────────────────
            Builder(builder: (c) => _DLabel(c.read<LocaleProvider>().s.supportSection)),
            const SizedBox(height: 8),
            _DCard(children: [
              Builder(builder: (c) => _DMenuItem(icon: Icons.help_outline_rounded, iconColor: _grey, label: c.read<LocaleProvider>().s.helpSupport, onTap: _showHelpSupport)),
              const _DDivider(),
              Builder(builder: (c) => _DMenuItem(icon: Icons.info_outline_rounded, iconColor: _grey, label: c.read<LocaleProvider>().s.aboutDotComply, trailing: 'v1.0.0', onTap: () => context.push('/about'))),
            ]),
            const SizedBox(height: 16),

            // ── Sign Out ─────────────────────────────────────────────────────
            GestureDetector(
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _red.withOpacity(0.20))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.logout_rounded, color: _red, size: 20),
                  const SizedBox(width: 10),
                  Builder(builder: (c) => Text(c.read<LocaleProvider>().s.signOut, style: c.af(fontSize: 15, fontWeight: FontWeight.w700, color: _red))),
                ]),
              ),
            ),
          ])),
        ),
      ]),
    );
  }

  Widget _avatarFallback(String initials) => Container(
    color: _blue, alignment: Alignment.center,
    child: Text(initials, style: context.af(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)));

  static String _fmt(String d) {
    try { final dt = DateTime.parse(d); return '${dt.month}/${dt.day}/${dt.year}'; }
    catch (_) { return d; }
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _DLabel extends StatelessWidget {
  final String text;
  const _DLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: context.af(fontSize: 11, fontWeight: FontWeight.w700,
          color: _grey, letterSpacing: 0.8));
}

class _DCard extends StatelessWidget {
  final List<Widget> children;
  const _DCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
    child: Column(children: children));
}

class _DDivider extends StatelessWidget {
  const _DDivider();
  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: 52, color: Colors.grey.shade100);
}

class _DRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  final Color? valueColor;
  const _DRow({required this.icon, required this.iconColor, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Container(width: 34, height: 34,
        decoration: BoxDecoration(color: iconColor.withOpacity(0.10), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 17, color: iconColor)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: context.af(fontSize: 13, color: _grey))),
      Text(value, style: context.af(fontSize: 13, fontWeight: FontWeight.w700,
          color: valueColor ?? const Color(0xFF1E293B))),
    ]));
}

class _DMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  const _DMenuItem({required this.icon, required this.iconColor, required this.label, required this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(color: iconColor.withOpacity(0.10), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: context.af(fontSize: 14, fontWeight: FontWeight.w500, color: _navy))),
        if (trailing != null) ...[
          Text(trailing!, style: context.af(fontSize: 13, color: _grey)),
          const SizedBox(width: 4),
        ],
        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
      ]),
    ));
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _SupportTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: context.af(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(subtitle, style: context.af(fontSize: 12, color: _grey)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
      ]),
    ));
}

// ── Sheet helper widgets ───────────────────────────────────────────────────────

class _DSheetHandle extends StatelessWidget {
  const _DSheetHandle();
  @override
  Widget build(BuildContext context) => Column(children: [
    const SizedBox(height: 12),
    Container(width: 36, height: 4,
        decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
    const SizedBox(height: 20),
  ]);
}

class _DToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _DToggleRow({required this.icon, required this.iconColor, required this.label,
      required this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: iconColor.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: iconColor)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.af(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF031634))),
        Text(subtitle, style: context.af(fontSize: 12, color: const Color(0xFF64748B))),
      ])),
      Switch.adaptive(value: value, onChanged: onChanged, activeColor: _blue),
    ]),
  );
}

class _DInfoCell extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DInfoCell({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5))),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
      Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      const SizedBox(height: 5),
      Text(label, style: context.af(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
      const SizedBox(height: 3),
      Text(value, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: context.af(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF031634))),
    ]),
  );
}

class _DPwdField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  const _DPwdField({required this.controller, required this.label, required this.obscure, required this.onToggle});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    style: context.af(fontSize: 14, color: const Color(0xFF0F172A)),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: context.af(fontSize: 13, color: const Color(0xFF64748B)),
      suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: const Color(0xFF94A3B8)),
          onPressed: onToggle),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0453CD), width: 1.5)),
    ),
  );
}
