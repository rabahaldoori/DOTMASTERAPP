import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';

// ── Color constants ─────────────────────────────────────────────────────────
const _navy  = Color(0xFF031634);
const _blue  = Color(0xFF0453CD);
const _grey  = Color(0xFF64748B);
const _green = Color(0xFF10B981);
const _bg    = Color(0xFFF3F5FA);

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  // Defaults shown while loading
  String _appName     = 'DOT Master';
  String _tagline     = 'Smart IFTA & DOT Compliance for Modern Fleets';
  String _description = 'Loading…';
  String _version     = '1.0.0';
  String _website     = 'https://dotmaster.app';
  String _copyright   = '© 2025 DOT Master. All rights reserved.';
  bool   _loading     = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.getLegalContent();
      if (!mounted) return;
      setState(() {
        _appName     = (res.data['about_app_name']    ?? _appName).toString();
        _tagline     = (res.data['about_tagline']     ?? _tagline).toString();
        _description = (res.data['about_description'] ?? _description).toString();
        _version     = (res.data['about_version']     ?? _version).toString();
        _website     = (res.data['about_website']     ?? _website).toString();
        _copyright   = (res.data['about_copyright']   ?? _copyright).toString();
        _loading     = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _description = 'DOT Master is the all-in-one fleet compliance platform '
            'built for commercial trucking operators.';
        _loading = false;
        _error = 'Could not reach server. Showing cached info.';
      });
    }
  }

  Future<void> _openWebsite() async {
    final uri = Uri.parse(_website);
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('About', style: GoogleFonts.inter(
            fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: _blue, strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(children: [
                // ── App Logo & Name ──────────────────────────────────────────
                _AppLogoHero(appName: _appName, version: _version),
                const SizedBox(height: 10),

                // ── Error banner ─────────────────────────────────────────────
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.orange.shade700))),
                    ]),
                  ),

                // ── Tagline ───────────────────────────────────────────────────
                Text(_tagline,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: _grey, height: 1.5)),
                const SizedBox(height: 28),

                // ── Description card ─────────────────────────────────────────
                _AboutCard(
                  icon: Icons.info_outline_rounded,
                  title: 'About $_appName',
                  child: Text(_description,
                      style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: const Color(0xFF475569),
                          height: 1.75)),
                ),
                const SizedBox(height: 14),

                // ── App info card ─────────────────────────────────────────────
                _AboutCard(
                  icon: Icons.smartphone_rounded,
                  title: 'App Information',
                  child: Column(children: [
                    _InfoRow(label: 'Version',  value: 'v$_version'),
                    _InfoRow(label: 'Platform', value: 'iOS & Android'),
                    _InfoRow(label: 'Category', value: 'Fleet & Compliance'),
                    _InfoRow(label: 'Website',
                      value: _website,
                      onTap: _openWebsite,
                      isLink: true,
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── Key features ─────────────────────────────────────────────
                _AboutCard(
                  icon: Icons.local_shipping_outlined,
                  title: 'Key Features',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _FeatureBullet('IFTA Quarterly Fuel Tax Reporting'),
                      _FeatureBullet('Trip & Mileage Tracking'),
                      _FeatureBullet('Fuel Log Management with Receipts'),
                      _FeatureBullet('DOT Pre-Trip & Post-Trip Inspections'),
                      _FeatureBullet('Fleet Maintenance Scheduling'),
                      _FeatureBullet('Document Management (BOL, Permits)'),
                      _FeatureBullet('Multi-Driver & Multi-Truck Support'),
                      _FeatureBullet('Biometric Login (Face ID / Fingerprint)'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Legal links ───────────────────────────────────────────────
                _AboutCard(
                  icon: Icons.gavel_rounded,
                  title: 'Legal',
                  child: Column(children: [
                    _LegalLink(
                      label: 'Privacy Policy',
                      onTap: () => Navigator.of(context).pop(), // returns to profile where policy is
                    ),
                    const Divider(height: 1, thickness: 1,
                        indent: 0, endIndent: 0,
                        color: Color(0xFFF1F5F9)),
                    _LegalLink(
                      label: 'Terms of Service',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),

                // ── Return button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                    label: Text('Back to Profile',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Copyright footer ──────────────────────────────────────────
                Text(_copyright,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFFCBD5E1))),
                const SizedBox(height: 8),
                Text('Built with ❤️ for the trucking industry',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFFCBD5E1))),
                const SizedBox(height: 32),
              ]),
            ),
    );
  }
}

// ── App logo hero ─────────────────────────────────────────────────────────────
class _AppLogoHero extends StatelessWidget {
  final String appName;
  final String version;
  const _AppLogoHero({required this.appName, required this.version});

  @override
  Widget build(BuildContext context) => Column(children: [
    Image.asset(
      'assets/images/logo.png',
      width: 110,
      height: 110,
      fit: BoxFit.contain,
    ),
    const SizedBox(height: 16),
    Text(appName,
        style: GoogleFonts.inter(
            fontSize: 26, fontWeight: FontWeight.w800, color: _navy)),
    const SizedBox(height: 4),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('v$version',
          style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w700, color: _blue)),
    ),
    const SizedBox(height: 16),
  ]);
}

// ── About card container ──────────────────────────────────────────────────────
class _AboutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _AboutCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(children: [
            Icon(icon, color: _blue, size: 18),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: _navy, letterSpacing: 0.2)),
          ]),
        ),
        Container(height: 1, color: const Color(0xFFF1F5F9)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: child,
        ),
      ],
    ),
  );
}

// ── Info row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool isLink;
  const _InfoRow({
    required this.label,
    required this.value,
    this.onTap,
    this.isLink = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(
            fontSize: 13, color: _grey)),
        GestureDetector(
          onTap: onTap,
          child: Text(value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isLink ? _blue : _navy,
                decoration: isLink
                    ? TextDecoration.underline
                    : TextDecoration.none,
              )),
        ),
      ],
    ),
  );
}

// ── Feature bullet ────────────────────────────────────────────────────────────
class _FeatureBullet extends StatelessWidget {
  final String text;
  const _FeatureBullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.check_circle_rounded, color: _green, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: GoogleFonts.inter(
          fontSize: 13, color: const Color(0xFF475569), height: 1.4))),
    ]),
  );
}

// ── Legal link row ────────────────────────────────────────────────────────────
class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LegalLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: _navy)),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: Color(0xFFCBD5E1)),
        ],
      ),
    ),
  );
}
