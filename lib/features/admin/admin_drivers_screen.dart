import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_client.dart';
import 'add_driver_screen.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _navy   = Color(0xFF0B1D3A);
const _blue   = Color(0xFF1D6AF5);
const _cyan   = Color(0xFF06B6D4);
const _slate  = Color(0xFF64748B);
const _bg     = Color(0xFFF1F5FB);

// Per-driver gradient pool (cycles through these)
final _avatarGradients = [
  [const Color(0xFF1D6AF5), const Color(0xFF06B6D4)],
  [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
  [const Color(0xFF059669), const Color(0xFF065F46)],
  [const Color(0xFFEF4444), const Color(0xFFB91C1C)],
  [const Color(0xFFF59E0B), const Color(0xFFB45309)],
  [const Color(0xFF0891B2), const Color(0xFF0E7490)],
];

class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> {
  List<Map<String, dynamic>> _drivers  = [];
  List<Map<String, dynamic>> _filtered = [];
  bool   _loading = true;
  String _search  = '';
  String _filter  = 'all'; // all | active | inactive | on_leave

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res  = await ApiClient.getDrivers();
      final list = (res.data is List)
          ? List<Map<String, dynamic>>.from(res.data as List)
          : List<Map<String, dynamic>>.from(
              (res.data as Map)['results'] as List? ?? []);
      setState(() { _drivers = list; _loading = false; });
      _applyFilter();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    var list = _drivers.where((d) {
      final name = (d['full_name'] ?? '').toString().toLowerCase();
      final matchSearch = _search.isEmpty || name.contains(_search.toLowerCase());
      final matchFilter = _filter == 'all' || d['status'] == _filter;
      return matchSearch && matchFilter;
    }).toList();
    setState(() => _filtered = list);
  }

  int get _activeCount   => _drivers.where((d) => d['status'] == 'active').length;
  int get _inactiveCount => _drivers.where((d) => d['status'] == 'inactive').length;
  int get _leaveCount    => _drivers.where((d) => d['status'] == 'on_leave').length;

  void _showAddDriver() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddDriverScreen()),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              GestureDetector(
                onTap: _showAddDriver,
                child: Container(
                  margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_blue, _cyan],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(
                        color: _blue.withOpacity(0.35),
                        blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_add_alt_1_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('Add Driver',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ]),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _Header(
                total:    _drivers.length,
                active:   _activeCount,
                inactive: _inactiveCount,
                onLeave:  _leaveCount,
              ),
            ),
          ),
        ],
        body: Column(children: [
          // ── Search + filter chips ───────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(children: [
              // Search
              TextField(
                onChanged: (q) { _search = q; _applyFilter(); },
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name…',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14, color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Colors.grey.shade400, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _blue, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Filter chips
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _Chip(label: 'All',      value: 'all',      current: _filter,
                        onTap: (v) { _filter = v; _applyFilter(); }),
                    _Chip(label: 'Active',   value: 'active',   current: _filter,
                        onTap: (v) { _filter = v; _applyFilter(); }),
                    _Chip(label: 'Inactive', value: 'inactive', current: _filter,
                        onTap: (v) { _filter = v; _applyFilter(); }),
                    _Chip(label: 'On Leave', value: 'on_leave', current: _filter,
                        onTap: (v) { _filter = v; _applyFilter(); }),
                  ],
                ),
              ),
            ]),
          ),

          // ── Count ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: [
              Text('${_filtered.length} driver${_filtered.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _slate)),
            ]),
          ),

          // ── List ───────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _blue))
                : _filtered.isEmpty
                    ? _Empty(searching: _search.isNotEmpty)
                    : RefreshIndicator(
                        color: _blue,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _DriverCard(
                            driver: _filtered[i],
                            index: i,
                          ),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

// ─── Gradient header ─────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int total, active, inactive, onLeave;
  const _Header({
    required this.total, required this.active,
    required this.inactive, required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B1D3A), Color(0xFF0F3260)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        // Decorative orb top-right
        Positioned(top: -30, right: -30,
          child: Container(width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _blue.withOpacity(0.12)))),
        Positioned(bottom: 20, left: -20,
          child: Container(width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _cyan.withOpacity(0.08)))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.people_alt_rounded,
                        color: Colors.white, size: 20)),
                  const SizedBox(width: 10),
                  Text('Drivers',
                      style: GoogleFonts.inter(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ]),
                const SizedBox(height: 16),
                // Stats row
                Row(children: [
                  _StatBubble(label: 'Total',    value: '$total',    color: Colors.white),
                  const SizedBox(width: 8),
                  _StatBubble(label: 'Active',   value: '$active',   color: const Color(0xFF4ADE80)),
                  const SizedBox(width: 8),
                  _StatBubble(label: 'Inactive', value: '$inactive', color: const Color(0xFFF87171)),
                  const SizedBox(width: 8),
                  _StatBubble(label: 'Leave',    value: '$onLeave',  color: const Color(0xFFFBBF24)),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _StatBubble extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBubble({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(children: [
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.60))),
      ]),
    ),
  );
}

// ─── Filter chip ─────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _Chip({
    required this.label, required this.value,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _navy : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _slate)),
      ),
    );
  }
}

// ─── Driver Card ─────────────────────────────────────────────────────────────
class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final int index;
  const _DriverCard({required this.driver, required this.index});

  Color get _statusColor {
    switch (driver['status']) {
      case 'active':   return const Color(0xFF22C55E);
      case 'inactive': return const Color(0xFFEF4444);
      case 'on_leave': return const Color(0xFFF59E0B);
      default:         return _slate;
    }
  }

  String get _statusLabel {
    switch (driver['status']) {
      case 'active':   return 'Active';
      case 'inactive': return 'Inactive';
      case 'on_leave': return 'On Leave';
      default:         return (driver['status'] ?? '—').toString();
    }
  }

  IconData get _statusIcon {
    switch (driver['status']) {
      case 'active':   return Icons.check_circle_rounded;
      case 'inactive': return Icons.cancel_rounded;
      case 'on_leave': return Icons.bedtime_rounded;
      default:         return Icons.help_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name    = (driver['full_name']  ?? 'Unknown').toString();
    final cdl     = (driver['cdl_number'] ?? '').toString();
    final state   = (driver['cdl_state']  ?? '').toString();
    final truck   = driver['assigned_truck_unit'];
    final grads   = _avatarGradients[index % _avatarGradients.length];
    final initials = name.trim().split(' ')
        .where((p) => p.isNotEmpty).take(2)
        .map((p) => p[0].toUpperCase()).join();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Avatar
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: grads,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(initials,
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Wrap(spacing: 10, children: [
                if (cdl.isNotEmpty)
                  _InfoChip(
                      icon: Icons.badge_outlined,
                      label: '$cdl${state.isNotEmpty ? ' · $state' : ''}'),
                if (truck != null)
                  _InfoChip(
                      icon: Icons.local_shipping_outlined,
                      label: truck.toString()),
              ]),
            ],
          )),
          const SizedBox(width: 10),

          // Status badge
          Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor.withOpacity(0.30)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon, size: 11, color: _statusColor),
                const SizedBox(width: 4),
                Text(_statusLabel,
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: _statusColor)),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: Colors.grey.shade400),
      const SizedBox(width: 3),
      Text(label,
          style: GoogleFonts.inter(fontSize: 11, color: _slate)),
    ],
  );
}

// ─── Empty state ─────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  final bool searching;
  const _Empty({required this.searching});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.people_outline_rounded,
            size: 36, color: _blue)),
      const SizedBox(height: 16),
      Text(
        searching ? 'No drivers match your search'
                  : 'No drivers yet',
        style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B))),
      const SizedBox(height: 6),
      if (!searching)
        Text('Tap "Add Driver" to get started',
            style: GoogleFonts.inter(fontSize: 13, color: _slate)),
    ]),
  );
}

