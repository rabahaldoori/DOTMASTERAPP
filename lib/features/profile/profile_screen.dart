import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';

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

  Future<void> _logout() async {
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
            Text('Sign Out',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 8),
            // Body
            Text('Are you sure you want to sign out?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: _grey)),
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
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
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
                      child: Text('Sign Out',
                          style: GoogleFonts.inter(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload photo. Try again.')));
      }
    }
  }

  String get _roleLabel {
    switch ((_user['role'] ?? '').toString().toLowerCase()) {
      case 'admin':      return 'Fleet Administrator';
      case 'manager':    return 'Fleet Manager';
      case 'dispatcher': return 'Dispatcher';
      default:           return 'Fleet Member';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                title: Text('My Profile', style: GoogleFonts.inter(
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
                                                    style: GoogleFonts.inter(
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
                                              style: GoogleFonts.inter(fontSize: 34,
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
                              style: GoogleFonts.inter(
                                  fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(_roleLabel, textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white60)),
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
                                  style: GoogleFonts.inter(
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
                      _InfoRow(icon: Icons.email_outlined, label: 'Email', value: email),
                    if (phone.isNotEmpty) ...[
                      const _Div(),
                      _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: phone),
                    ],
                    if (company.isNotEmpty) ...[
                      const _Div(),
                      _InfoRow(icon: Icons.business_outlined, label: 'Company', value: company),
                    ],
                    if (email.isEmpty && phone.isEmpty && company.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('No contact info', style: GoogleFonts.inter(color: _grey)),
                      ),
                  ]),
                  const SizedBox(height: 24),

                  // ── Settings ───────────────────────────────────────────
                  _Label('SETTINGS'),
                  const SizedBox(height: 8),
                  _Card(children: [
                    _MenuItem(
                      icon: Icons.person_outline_rounded,
                      iconColor: _blue,
                      label: 'Personal Information',
                      onTap: () {},
                    ),
                    const _Div(),
                    _MenuItem(
                      icon: Icons.lock_outline_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      label: 'Security & Privacy',
                      onTap: () {},
                    ),
                    const _Div(),
                    _MenuItem(
                      icon: Icons.notifications_outlined,
                      iconColor: _cyan,
                      label: 'Notification Settings',
                      onTap: () {},
                    ),
                    const _Div(),
                    _MenuItem(
                      icon: Icons.language_rounded,
                      iconColor: const Color(0xFF059669),
                      label: 'App Language',
                      trailing: 'English',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Support ────────────────────────────────────────────
                  _Label('SUPPORT'),
                  const SizedBox(height: 8),
                  _Card(children: [
                    _MenuItem(
                      icon: Icons.help_outline_rounded,
                      iconColor: _grey,
                      label: 'Help & Support',
                      onTap: () {},
                    ),
                    const _Div(),
                    _MenuItem(
                      icon: Icons.info_outline_rounded,
                      iconColor: _grey,
                      label: 'About DOT Comply',
                      trailing: 'v1.0.0',
                      onTap: () {},
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
                        Text('Sign Out', style: GoogleFonts.inter(
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
      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
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
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
            color: _grey, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
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
        Expanded(child: Text(label, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: _navy))),
        if (trailing != null)
          Text(trailing!, style: GoogleFonts.inter(fontSize: 13, color: _grey)),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
      ]),
    ),
  );
}
