import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location  = GoRouterState.of(context).matchedLocation;
    final isDash    = location.startsWith('/dashboard');
    final isFuel    = location.startsWith('/fuel');
    final isTrips   = location.startsWith('/trips');
    final isReports = location.startsWith('/reports');
    final isTruck   = location.startsWith('/truck');
    final isProfile = location.startsWith('/profile');

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF0F3FA),
      body: child,
      bottomNavigationBar: _GlassTabBar(
        isDash: isDash, isFuel: isFuel, isTrips: isTrips,
        isReports: isReports, isTruck: isTruck, isProfile: isProfile,
      ),
    );
  }
}

// ── Floating Navy Glass Tab Bar ────────────────────────────────────────────────
class _GlassTabBar extends StatelessWidget {
  final bool isDash, isFuel, isTrips, isReports, isTruck, isProfile;
  const _GlassTabBar({
    required this.isDash, required this.isFuel, required this.isTrips,
    required this.isReports, required this.isTruck, required this.isProfile,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 12, right: 12,
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
                  blurRadius: 32, spreadRadius: -2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.08),
                  blurRadius: 20, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(children: [
              // ── Gloss shine strip ──────────────────────────────────────
              Positioned(
                top: 0, left: 20, right: 20,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.45),
                      Colors.white.withOpacity(0.45),
                      Colors.transparent,
                    ], stops: const [0.0, 0.3, 0.7, 1.0]),
                  ),
                ),
              ),
              // ── Top half gloss wash ────────────────────────────────────
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
              // ── Tab items ──────────────────────────────────────────────
              Row(children: [
                _TabItem(icon: Icons.grid_view_rounded,
                    label: 'Dashboard', active: isDash,
                    onTap: () => context.go('/dashboard')),
                _TabItem(icon: Icons.local_gas_station_rounded,
                    label: 'Fuel', active: isFuel,
                    onTap: () => context.go('/fuel')),
                _TabItem(icon: Icons.route_rounded,
                    label: 'Trips', active: isTrips,
                    onTap: () => context.go('/trips')),
                _TabItem(icon: Icons.bar_chart_rounded,
                    label: 'Reports', active: isReports,
                    onTap: () => context.go('/reports')),
                _TabItem(icon: Icons.local_shipping_outlined,
                    label: 'Truck', active: isTruck,
                    onTap: () => context.go('/truck')),
                _TabItem(icon: Icons.person_rounded,
                    label: 'Profile', active: isProfile,
                    onTap: () => context.go('/profile')),
              ]),
            ]),
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

  static const _cyan = Color(0xFF06B6D4);

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
              width:  active ? 40 : 32,
              height: 28,
              decoration: active
                  ? BoxDecoration(
                      color: _cyan.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10))
                  : const BoxDecoration(),
              child: Icon(icon, size: 17,
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
