import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverScaffold extends StatelessWidget {
  final Widget child;
  const DriverScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isDash  = location.startsWith('/driver-dashboard');
    final isTrips = location.startsWith('/driver-trips');
    final isFuel  = location.startsWith('/driver-fuel');
    final isMaint = location.startsWith('/driver-maintenance');
    final isProf  = location.startsWith('/driver-profile');

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF0F3FF),
      body: child,
      bottomNavigationBar: _GlassTabBar(
        isDash: isDash, isTrips: isTrips,
        isFuel: isFuel, isMaint: isMaint, isProf: isProf,
      ),
    );
  }
}

// ── Floating Navy Tab Bar ──────────────────────────────────────────────────────
class _GlassTabBar extends StatelessWidget {
  final bool isDash, isTrips, isFuel, isMaint, isProf;
  const _GlassTabBar({
    required this.isDash, required this.isTrips,
    required this.isFuel, required this.isMaint, required this.isProf,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16,
        bottom: safeBottom > 0 ? safeBottom + 8 : 18,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A2550),
                  Color(0xFF031634),
                  Color(0xFF0D3A6B),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF031634).withOpacity(0.55),
                  blurRadius: 32,
                  spreadRadius: -2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // ── Gloss shine strip at top ─────────────────────────────
                Positioned(
                  top: 0, left: 20, right: 20,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.45),
                          Colors.white.withOpacity(0.45),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
                // ── Top half gloss wash ───────────────────────────────────
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.10),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Tab items ─────────────────────────────────────────────
                Row(
                  children: [
                    _TabItem(icon: Icons.grid_view_rounded,  label: 'Home',        active: isDash,  onTap: () => context.go('/driver-dashboard')),
                    _TabItem(icon: Icons.route_rounded,      label: 'Trips',       active: isTrips, onTap: () => context.go('/driver-trips')),
                    _TabItem(icon: Icons.local_gas_station,  label: 'Fuel',        active: isFuel,  onTap: () => context.go('/driver-fuel')),
                    _TabItem(icon: Icons.build_rounded,      label: 'Maintenance', active: isMaint, onTap: () => context.go('/driver-maintenance')),
                    _TabItem(icon: Icons.person_rounded,     label: 'Profile',     active: isProf,  onTap: () => context.go('/driver-profile')),
                  ],
                ),
              ],   // Stack children
            ),
          ),
        ),
      ),
    );
  }
}

// ── Individual Tab Item ────────────────────────────────────────────────────────
class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon, required this.label,
    required this.active, required this.onTap,
  });

  static const _cyan = Color(0xFF06B6D4);  // same cyan accent as header

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width:  active ? 44 : 36,
              height: 30,
              decoration: active
                  ? BoxDecoration(
                      color: _cyan.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : const BoxDecoration(),
              child: Icon(icon, size: 18,
                  color: active ? _cyan : Colors.white.withOpacity(0.45)),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: GoogleFonts.inter(
                fontSize: 8.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? _cyan : Colors.white.withOpacity(0.45),
                letterSpacing: -0.1,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.clip),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 4, height: 4,
              decoration: BoxDecoration(
                color: active ? _cyan : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
