import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/font_ext.dart';
import 'truck_edit_screen.dart';

const _navy  = Color(0xFF031634);
const _navy2 = Color(0xFF0D2952);
const _blue  = Color(0xFF0453CD);
const _green = Color(0xFF16A34A);
const _amber = Color(0xFFF59E0B);
const _red   = Color(0xFFDC2626);
const _surf  = Color(0xFFF0F3FA);
const _bord  = Color(0xFFDCE2F3);
const _grey  = Color(0xFF64748B);

// ─────────────────────────────────────────────────────────────────────────────
class TruckScreen extends StatefulWidget {
  const TruckScreen({super.key});
  @override
  State<TruckScreen> createState() => _TruckScreenState();
}

class _TruckScreenState extends State<TruckScreen> {
  List<Map> _trucks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.getTrucks();
      if (!mounted) return;
      final data = res.data;
      final list = (data is Map ? (data['results'] ?? data['trucks'] ?? []) : data) as List;
      setState(() { _trucks = list.cast<Map>(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      final s = context.read<LocaleProvider>().s;
      setState(() { _error = s.couldNotLoadTrucks; _loading = false; });
    }
  }

  void _openAddModal() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TruckEditScreen()),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    final count = _trucks.length;
    final countLabel = count == 1
        ? '$count ${s.truckRegistered}'
        : '$count ${s.trucksRegistered}';

    return Scaffold(
      backgroundColor: _surf,
      body: RefreshIndicator(
        color: _blue,
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            automaticallyImplyLeading: false,
            title: Text(s.myTrucks, style: context.af(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            actions: [
              IconButton(
                tooltip: s.addTruck,
                onPressed: _openAddModal,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, _navy2]),
                ),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 12),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(s.fleetManagement, style: context.af(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500)),
                      Text(countLabel, style: context.af(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                    const Spacer(),
                    GestureDetector(
                      onTap: _openAddModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _blue, borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: _blue.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                          Text(s.addTruck, style: context.af(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        ]),
                      ),
                    ),
                  ]),
                )),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _blue)))
          else if (_error != null)
            SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, size: 48, color: _red),
              const SizedBox(height: 12),
              Text(_error!, style: context.af(color: _grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(backgroundColor: _navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(s.retry, style: context.af(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ])))
          else if (_trucks.isEmpty)
            SliverFillRemaining(child: _EmptyTrucks(onAdd: _openAddModal))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) => _TruckCard(truck: _trucks[i], onRefresh: _load),
                childCount: _trucks.length,
              )),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _TruckCard extends StatelessWidget {
  final Map truck;
  final VoidCallback onRefresh;
  const _TruckCard({required this.truck, required this.onRefresh});

  Color get _statusColor {
    switch ((truck['status'] ?? '').toString()) {
      case 'active':      return _green;
      case 'maintenance': return _amber;
      case 'inactive':    return _grey;
      default:            return _red;
    }
  }

  String _statusLabel(AppStrings s) => {
    'active':      s.statusActive,
    'maintenance': s.statusMaintenance,
    'inactive':    s.statusInactive,
    'retired':     s.statusRetired,
  }[(truck['status'] ?? 'active').toString()] ?? s.statusActive;

  @override
  Widget build(BuildContext context) {
    final s      = context.watch<LocaleProvider>().s;
    final unit   = truck['unit_number'] ?? '—';
    final year   = truck['year']?.toString() ?? '';
    final make   = truck['make'] ?? '';
    final model  = truck['model'] ?? '';
    final plate  = truck['license_plate'] ?? '—';
    final state  = truck['license_state'] ?? '';
    final fuel   = (truck['fuel_type'] ?? 'diesel').toString().replaceAll('_', ' ');
    final driver = truck['assigned_driver_name'] ?? truck['assigned_driver']?.toString();

    return GestureDetector(
      onTap: () => _openEdit(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _bord),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            // Left: truck icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_navy, _navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),

            // Middle: name + tags
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$year $make $model', style: context.af(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                const SizedBox(height: 3),
                Row(children: [
                  _Tag(label: plate + (state.isNotEmpty ? ' · $state' : ''), icon: Icons.credit_card_rounded),
                  const SizedBox(width: 6),
                  _Tag(label: fuel, icon: Icons.local_gas_station_rounded),
                ]),
                if (driver != null) ...[
                  const SizedBox(height: 3),
                  Text('👤 $driver', style: context.af(fontSize: 10, color: _grey)),
                ],
              ],
            )),

            // Right: status + unit + chevron
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _statusColor.withOpacity(0.35)),
                ),
                child: Text(_statusLabel(s), style: context.af(fontSize: 9, fontWeight: FontWeight.w700, color: _statusColor)),
              ),
              const SizedBox(height: 4),
              Text(unit, style: context.af(fontSize: 10, color: _grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right_rounded, size: 18, color: _grey),
            ]),
          ]),
        ),
      ),
    );
  }

  void _openEdit(BuildContext ctx) async {
    final saved = await Navigator.push<bool>(
      ctx,
      MaterialPageRoute(builder: (_) => TruckEditScreen(existing: truck)),
    );
    if (saved == true) onRefresh();
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Tag({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 10, color: _grey),
    const SizedBox(width: 3),
    Text(label, style: context.af(fontSize: 10, color: _grey, fontWeight: FontWeight.w500),
        maxLines: 1, overflow: TextOverflow.ellipsis),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
class _EmptyTrucks extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTrucks({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: _blue.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.local_shipping_outlined, size: 40, color: _blue)),
        const SizedBox(height: 16),
        Text(s.noTrucksYet, style: context.af(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 8),
        Text(s.addFirstTruck, textAlign: TextAlign.center, style: context.af(fontSize: 13, color: _grey)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(s.addTruck, style: context.af(fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]),
    ));
  }
}
