import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';

const _navy    = Color(0xFF031634);
const _navy2   = Color(0xFF0A2347);
const _blue    = Color(0xFF0453CD);
const _green   = Color(0xFF22C55E);
const _orange  = Color(0xFFF97316);
const _surface = Color(0xFFF0F3FF);

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
      if (mounted) _snack('Upload failed. Try again.', Colors.red);
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
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.10),
                  shape: BoxShape.circle),
              child: const Icon(Icons.logout_rounded, color: Colors.red, size: 26)),
            const SizedBox(height: 14),
            Text('Sign Out', style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 6),
            Text('Are you sure you want to sign out?', textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Text('Cancel', style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: Colors.grey)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Text('Sign Out', style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: CircularProgressIndicator(color: _blue)));

    final p        = _profile;
    final name     = p?['full_name'] as String? ?? '—';
    final email    = p?['email']    as String? ?? '—';
    final initials = name.split(' ').where((w) => w.isNotEmpty)
        .map((w) => w[0]).take(2).join().toUpperCase();
    final photoUrl = p?['photo'] as String?;
    final status   = (p?['status'] as String? ?? 'active').toLowerCase();

    // CDL expiry
    final cdlExpiryStr = p?['cdl_expiry'] as String?;
    final cdlDays = cdlExpiryStr != null
        ? DateTime.tryParse(cdlExpiryStr)?.difference(DateTime.now()).inDays
        : null;
    final cdlWarning = cdlDays != null && cdlDays < 90;

    return Scaffold(
      backgroundColor: _surface,
      body: CustomScrollView(slivers: [
        // ── Pinned SliverAppBar ─────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: _navy,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          // ── Collapsed title: "My Profile" + logout ─────────────────────
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            Text('My Profile', style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: Colors.white)),
            const Spacer(),
            GestureDetector(
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.30)),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.red, size: 16)),
            ),
          ]),
          // ── Expanded: avatar + name + status (no title duplication) ────
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_navy, _navy2]),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, kToolbarHeight + 4, 0, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Avatar
                      Stack(alignment: Alignment.center, children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3), width: 2.5)),
                          child: ClipOval(child: photoUrl != null
                              ? Image.network(photoUrl, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _avatarFallback(initials))
                              : _avatarFallback(initials)),
                        ),
                        Positioned(bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: _uploading ? null : _pickAndUpload,
                            child: Container(width: 22, height: 22,
                              decoration: BoxDecoration(
                                  color: _uploading ? Colors.grey : _blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2)),
                              child: _uploading
                                  ? const Padding(padding: EdgeInsets.all(3),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.camera_alt_rounded,
                                      size: 11, color: Colors.white)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(name.toUpperCase(), style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(email, style: GoogleFonts.inter(
                          fontSize: 10, color: Colors.white54)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'active'
                              ? _green.withOpacity(0.18)
                              : Colors.orange.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: status == 'active'
                              ? _green.withOpacity(0.45)
                              : Colors.orange.withOpacity(0.45)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 5, height: 5,
                              decoration: BoxDecoration(
                                  color: status == 'active'
                                      ? _green : Colors.orange,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(status.toUpperCase(), style: GoogleFonts.inter(
                              fontSize: 9, fontWeight: FontWeight.w700,
                              color: status == 'active'
                                  ? _green : Colors.orange)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Body ─────────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([

            // CDL warning banner
            if (cdlWarning) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _orange.withOpacity(0.35)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: _orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'CDL expires in $cdlDays days. Renew soon to stay compliant.',
                    style: GoogleFonts.inter(fontSize: 12, color: _orange,
                        fontWeight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── License section ─────────────────────────────────────────
            _SectionHeader(title: 'License Info', icon: Icons.credit_card_rounded),
            const SizedBox(height: 10),
            _ModernCard(children: [
              _Row(icon: Icons.badge_outlined,     label: 'CDL Number',
                  value: p?['cdl_number'] ?? '—'),
              _divider(),
              _Row(icon: Icons.map_outlined,        label: 'CDL State',
                  value: p?['cdl_state'] ?? '—'),
              _divider(),
              _Row(icon: Icons.event_outlined,      label: 'CDL Expires',
                  value: cdlExpiryStr != null ? _fmt(cdlExpiryStr) : '—',
                  valueColor: cdlWarning ? _orange : null),
              _divider(),
              _Row(icon: Icons.work_history_outlined, label: 'Hire Date',
                  value: p?['hire_date'] != null ? _fmt(p!['hire_date']) : '—'),
            ]),
            const SizedBox(height: 20),

            // ── Account section ─────────────────────────────────────────
            _SectionHeader(title: 'Account', icon: Icons.manage_accounts_rounded),
            const SizedBox(height: 10),
            _ModernCard(children: [
              _Row(icon: Icons.email_outlined,      label: 'Email',  value: email),
              _divider(),
              _Row(icon: Icons.phone_outlined,      label: 'Phone',
                  value: p?['phone'] ?? '—'),
              _divider(),
              _Row(icon: Icons.business_outlined,   label: 'Company',
                  value: p?['company_name'] ?? '—'),
            ]),
            const SizedBox(height: 20),
          ])),
        ),
      ]),
    );
  }

  Widget _avatarFallback(String initials) => Container(
    color: _blue,
    alignment: Alignment.center,
    child: Text(initials, style: GoogleFonts.inter(
        fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
  );

  Widget _divider() => Divider(height: 1, indent: 48, color: Colors.grey.shade100);

  String _fmt(String d) {
    try { final dt = DateTime.parse(d); return '${dt.month}/${dt.day}/${dt.year}'; }
    catch (_) { return d; }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: _blue),
    const SizedBox(width: 6),
    Text(title, style: GoogleFonts.inter(fontSize: 12,
        fontWeight: FontWeight.w800, color: _navy, letterSpacing: 0.3)),
  ]);
}

class _ModernCard extends StatelessWidget {
  final List<Widget> children;
  const _ModernCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE8EDF5)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Column(children: children),
  );
}

class _Row extends StatelessWidget {
  final IconData icon; final String label, value; final Color? valueColor;
  const _Row({required this.icon, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(color: const Color(0xFFF0F3FF),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: _blue)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: GoogleFonts.inter(
          fontSize: 13, color: const Color(0xFF64748B)))),
      Text(value, style: GoogleFonts.inter(fontSize: 13,
          fontWeight: FontWeight.w700,
          color: valueColor ?? const Color(0xFF1E293B))),
    ]),
  );
}
