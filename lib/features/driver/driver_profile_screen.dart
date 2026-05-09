import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';

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
        if (mounted) _snack('Photo updated!', _green);
      }
    } catch (_) {
      if (mounted) _snack('Upload failed.', _red);
    } finally {
      setState(() => _uploading = false);
    }
  }

  void _snack(String msg, Color col) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
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
            Text('Sign Out', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 6),
            Text('Are you sure you want to sign out?', textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: _grey)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _grey)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: _red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
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
                        Text('Help & Support', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: _navy)),
                        Text("We're here to help", style: GoogleFonts.inter(fontSize: 12, color: _grey)),
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
                    Text('Frequently Asked Questions', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
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
                                Expanded(child: Text(faqs[i].q, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: isOpen ? _blue : _navy))),
                                Icon(isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: isOpen ? _blue : _grey, size: 20),
                              ])),
                            if (isOpen) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: Text(faqs[i].a, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.6))),
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
            Text('My Profile', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
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
                  Text(name.toUpperCase(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(email, style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
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
                      Text('ACTIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: _green)),
                    ])),
                ]),
              )),
            ),
          ),
        ),

        // ── Body ───────────────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
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
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600))),
                ])),
              const SizedBox(height: 16),
            ],

            // ── Profile info card ────────────────────────────────────────────
            _DLabel('PROFILE'),
            const SizedBox(height: 8),
            _DCard(children: [
              _DRow(icon: Icons.email_outlined,      iconColor: _blue, label: 'Email',   value: email),
              const _DDivider(),
              _DRow(icon: Icons.phone_outlined,      iconColor: _blue, label: 'Phone',   value: phone),
              const _DDivider(),
              _DRow(icon: Icons.business_outlined,   iconColor: _blue, label: 'Company', value: company),
            ]),
            const SizedBox(height: 20),

            // ── License Info ─────────────────────────────────────────────────
            _DLabel('LICENSE INFO'),
            const SizedBox(height: 8),
            _DCard(children: [
              _DRow(icon: Icons.badge_outlined,        iconColor: _blue, label: 'CDL Number', value: p?['cdl_number'] ?? '—'),
              const _DDivider(),
              _DRow(icon: Icons.map_outlined,          iconColor: _blue, label: 'CDL State',  value: p?['cdl_state'] ?? '—'),
              const _DDivider(),
              _DRow(icon: Icons.event_outlined,        iconColor: cdlWarn ? Colors.orange : _blue,
                    label: 'CDL Expires',
                    value: cdlExpiryStr != null ? _fmt(cdlExpiryStr) : '—',
                    valueColor: cdlWarn ? Colors.orange : null),
              const _DDivider(),
              _DRow(icon: Icons.work_history_outlined, iconColor: _blue, label: 'Hire Date',
                    value: p?['hire_date'] != null ? _fmt(p!['hire_date']) : '—'),
            ]),
            const SizedBox(height: 20),

            // ── Settings ─────────────────────────────────────────────────────
            _DLabel('SETTINGS'),
            const SizedBox(height: 8),
            _DCard(children: [
              _DMenuItem(icon: Icons.person_outline_rounded, iconColor: _blue,
                  label: 'Personal Information', onTap: () {}),
              const _DDivider(),
              _DMenuItem(icon: Icons.lock_outline_rounded, iconColor: const Color(0xFF8B5CF6),
                  label: 'Security & Privacy', onTap: () {}),
              const _DDivider(),
              _DMenuItem(icon: Icons.notifications_outlined, iconColor: const Color(0xFF06B6D4),
                  label: 'Notification Settings', onTap: () {}),
            ]),
            const SizedBox(height: 20),

            // ── Support ──────────────────────────────────────────────────────
            _DLabel('SUPPORT'),
            const SizedBox(height: 8),
            _DCard(children: [
              _DMenuItem(icon: Icons.help_outline_rounded, iconColor: _grey,
                  label: 'Help & Support', onTap: _showHelpSupport),
              const _DDivider(),
              _DMenuItem(icon: Icons.info_outline_rounded, iconColor: _grey,
                  label: 'About DOT Comply', trailing: 'v1.0.0',
                  onTap: () => context.push('/about')),
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
                  Text('Sign Out', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _red)),
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
    child: Text(initials, style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)));

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
      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
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
      Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: _grey))),
      Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
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
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: _navy))),
        if (trailing != null) ...[
          Text(trailing!, style: GoogleFonts.inter(fontSize: 13, color: _grey)),
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
          Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: _grey)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
      ]),
    ));
}
