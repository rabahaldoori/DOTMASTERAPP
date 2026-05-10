import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/fuel/fuel_logs_screen.dart';
import '../features/fuel/add_fuel_screen.dart';
import '../features/fuel/fuel_detail_screen.dart';
import '../features/trips/trips_screen.dart';
import '../features/trips/trip_detail_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/truck/truck_screen.dart';
import '../features/profile/profile_screen.dart';
import '../shared/widgets/main_scaffold.dart';
import '../features/driver/driver_dashboard_screen.dart';
import '../features/driver/driver_trips_screen.dart';
import '../features/driver/driver_fuel_screen.dart';
import '../features/driver/driver_duty_screen.dart';
import '../features/driver/driver_profile_screen.dart';
import '../features/driver/driver_scaffold.dart';
import '../features/driver/driver_notifications_screen.dart';
import '../features/about/about_screen.dart';
import '../features/driver/inspection/inspection_checklist_screen.dart';
import '../features/driver/inspection/issue_report_screen.dart';
import '../features/driver/inspection/review_submit_screen.dart';
import '../features/driver/inspection/inspection_history_screen.dart';
import '../features/driver/inspection/inspection_detail_screen.dart';
import '../features/driver/driver_maintenance_screen.dart';
import '../features/driver/driver_maintenance_form_screen.dart';
import '../features/maintenance/admin_maintenance_screen.dart';
import '../features/inspection_template/inspection_template_screen.dart';
import '../features/admin/admin_drivers_screen.dart';
import '../features/admin/add_driver_screen.dart';
import '../core/api_client.dart';

final router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final loggedIn = await ApiClient.isLoggedIn;
    final loggingIn = state.matchedLocation == '/login';

    if (!loggedIn && !loggingIn) return '/login';

    if (loggedIn && loggingIn) {
      // Role-based home redirect
      final role = await ApiClient.getUserRole();
      return role == 'driver' ? '/driver-dashboard' : '/dashboard';
    }

    // Prevent drivers from accessing admin routes
    final role = await ApiClient.getUserRole();
    if (loggedIn && role == 'driver') {
      final loc = state.matchedLocation;
      final adminRoutes = ['/dashboard', '/fuel', '/trips', '/reports', '/truck'];
      if (adminRoutes.any((r) => loc.startsWith(r))) {
        return '/driver-dashboard';
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // ── Admin Shell ────────────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(path: '/dashboard',   builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/fuel',        builder: (_, __) => const FuelLogsScreen()),
        GoRoute(path: '/fuel/add',    builder: (_, __) => const AddFuelScreen()),
        GoRoute(
          path: '/fuel/:id',
          builder: (_, state) {
            final fuel = (state.extra as Map<String, dynamic>?) ?? {};
            return FuelDetailScreen(fuel: fuel);
          },
        ),
        GoRoute(
          path: '/trips',
          builder: (_, __) => const TripsScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                final extra = state.extra as Map?;
                return TripDetailScreen(tripId: id, initialData: extra);
              },
            ),
          ],
        ),
        GoRoute(path: '/reports',     builder: (_, __) => const ReportsScreen()),
        GoRoute(path: '/truck',       builder: (_, __) => const TruckScreen()),
        GoRoute(path: '/profile',     builder: (_, __) => const ProfileScreen()),
        GoRoute(path: '/about',       builder: (_, __) => const AboutScreen()),
        GoRoute(path: '/maintenance', builder: (_, __) => const AdminMaintenanceScreen()),
        GoRoute(path: '/inspection-template',
            builder: (_, __) => const InspectionTemplateScreen()),
        GoRoute(path: '/inspection-history',
            builder: (_, __) => const InspectionHistoryScreen(isAdmin: true)),
        GoRoute(path: '/admin/drivers',
            builder: (_, __) => const AdminDriversScreen()),
        GoRoute(path: '/admin/drivers/add',
            builder: (_, __) => const AddDriverScreen()),
        GoRoute(
          path: '/maintenance/add',
          builder: (_, __) => const DriverMaintenanceFormScreen(
              returnRoute: '/maintenance'),
        ),
        GoRoute(
          path: '/maintenance/edit',
          builder: (_, state) => DriverMaintenanceFormScreen(
              record: state.extra as Map?,
              returnRoute: '/maintenance'),
        ),
      ],
    ),

    // ── Driver Shell ───────────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => DriverScaffold(child: child),
      routes: [
        GoRoute(path: '/driver-dashboard', builder: (_, __) => const DriverDashboardScreen()),
        GoRoute(path: '/driver-trips',     builder: (_, __) => const DriverTripsScreen()),
        GoRoute(path: '/driver-fuel',      builder: (_, __) => const DriverFuelScreen()),
        GoRoute(path: '/driver-duty',      builder: (_, __) => const DriverDutyScreen()),
        GoRoute(path: '/driver-maintenance', builder: (_, __) => const DriverMaintenanceScreen()),
        GoRoute(path: '/driver-profile',   builder: (_, __) => const DriverProfileScreen()),
      ],
    ),

    // ── Inspection Flow (full-screen, no driver shell nav) ─────────────────
    GoRoute(path: '/driver-inspection',
        builder: (_, __) => const InspectionChecklistScreen()),
    GoRoute(path: '/driver-inspection/issue',
        builder: (_, __) => const IssueReportScreen()),
    GoRoute(path: '/driver-inspection/review',
        builder: (_, __) => const ReviewSubmitScreen()),
    GoRoute(path: '/driver-inspection/history',
        builder: (_, __) => const InspectionHistoryScreen(isAdmin: false)),
    GoRoute(path: '/inspection-detail',
        builder: (_, state) {
          final insp = state.extra as Map<String, dynamic>? ?? {};
          return InspectionDetailScreen(insp: insp);
        }),
    GoRoute(path: '/driver-notifications',
        builder: (_, __) => const DriverNotificationsScreen()),
    GoRoute(path: '/notifications',
        builder: (_, __) => const DriverNotificationsScreen()),

    // ── Maintenance Form (full-screen, no nav bar) ─────────────────────────
    GoRoute(
      path: '/driver-maintenance/add',
      builder: (_, __) => const DriverMaintenanceFormScreen(),
    ),
    GoRoute(
      path: '/driver-maintenance/edit',
      builder: (_, state) {
        final record = state.extra as Map?;
        return DriverMaintenanceFormScreen(record: record);
      },
    ),
  ],
);
