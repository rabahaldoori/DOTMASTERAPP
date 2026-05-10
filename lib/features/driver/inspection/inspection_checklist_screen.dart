import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api_client.dart';
import 'inspection_session.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _navy    = Color(0xFF031634);
const _blue    = Color(0xFF0453CD);
const _cyan    = Color(0xFF06B6D4);
const _surface = Color(0xFFF0F4FA);
const _white   = Colors.white;
const _grey    = Color(0xFF75777E);
const _border  = Color(0xFFDCE2F3);

class InspectionChecklistScreen extends StatefulWidget {
  const InspectionChecklistScreen({super.key});
  @override
  State<InspectionChecklistScreen> createState() => _State();
}

class _State extends State<InspectionChecklistScreen> {
  // Category: {name, icon, items: [{label, status: null/pass/fail}]}
  final List<_Category> _categories = [
    _Category(
      name: 'Tires & Wheels',
      icon: Icons.tire_repair,
      items: [
        _Item('Front Left Tire Pressure'),
        _Item('Front Right Tire Pressure'),
        _Item('Rear Tires Condition'),
        _Item('Wheel Lug Nuts'),
      ],
    ),
    _Category(
      name: 'Lights & Reflectors',
      icon: Icons.wb_sunny_outlined,
      items: [
        _Item('Headlights & High Beams'),
        _Item('Turn Signals & Flashers'),
        _Item('Brake Lights'),
        _Item('Marker Lights'),
      ],
    ),
    _Category(
      name: 'Engine Compartment',
      icon: Icons.settings_outlined,
      items: [
        _Item('Oil Level'),
        _Item('Coolant Level'),
        _Item('Belt Condition'),
        _Item('Fluid Leaks'),
      ],
    ),
    _Category(
      name: 'Brake System',
      icon: Icons.directions_bus_outlined,
      items: [
        _Item('Air Pressure'),
        _Item('Brake Pads'),
        _Item('Brake Lines'),
        _Item('Emergency Brake'),
      ],
    ),
    _Category(
      name: 'Cab & Interior',
      icon: Icons.airline_seat_recline_normal,
      items: [
        _Item('Windshield Condition'),
        _Item('Mirrors Adjustment'),
        _Item('Horn Function'),
        _Item('Seat Belts'),
      ],
    ),
  ];

  int _expanded = 0; // Tires & Wheels open by default
  final _scrollController = ScrollController();
  int?   _truckId;
  String _truckUnit = 'Your Vehicle';
  bool _templateLoaded = false;

  // Default template used as fallback when server template is unavailable
  List<_Category> _defaultCategories() => [
    _Category(name: 'Tires & Wheels', icon: Icons.tire_repair, items: [
      _Item('Front Left Tire Pressure'), _Item('Front Right Tire Pressure'),
      _Item('Rear Tires Condition'),     _Item('Wheel Lug Nuts'),
    ]),
    _Category(name: 'Lights & Reflectors', icon: Icons.wb_sunny_outlined, items: [
      _Item('Headlights & High Beams'), _Item('Turn Signals & Flashers'),
      _Item('Brake Lights'),            _Item('Marker Lights'),
    ]),
    _Category(name: 'Engine Compartment', icon: Icons.settings_outlined, items: [
      _Item('Oil Level'), _Item('Coolant Level'),
      _Item('Belt Condition'), _Item('Fluid Leaks'),
    ]),
    _Category(name: 'Brake System', icon: Icons.directions_bus_outlined, items: [
      _Item('Air Pressure'), _Item('Brake Pads'),
      _Item('Brake Lines'),  _Item('Emergency Brake'),
    ]),
    _Category(name: 'Cab & Interior', icon: Icons.airline_seat_recline_normal, items: [
      _Item('Windshield Condition'), _Item('Mirrors Adjustment'),
      _Item('Horn Function'),        _Item('Seat Belts'),
    ]),
  ];

  // Today's completed inspection (if any)
  Map<String, dynamic>? _todayInspection;
  bool _checkingToday = true;

  @override
  void initState() {
    super.initState();
    _loadTruck();
    _checkTodayInspection();
    _loadTemplate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    try {
      final res = await ApiClient.getInspectionTemplate();
      if (res.statusCode == 200 && mounted) {
        final List raw = res.data as List? ?? [];
        if (raw.isNotEmpty) {
          final loaded = raw.map<_Category>((cat) {
            final iconName = cat['icon'] as String? ?? 'checklist';
            final icon = _iconFromName(iconName);
            final items = (cat['items'] as List? ?? []).map<_Item>((it) =>
              _Item(it['label'] as String? ?? '', serverId: it['id'] as int?)
            ).toList();
            return _Category(
              name: cat['name'] as String? ?? '',
              icon: icon,
              items: items,
              serverId: cat['id'] as int?,
            );
          }).toList();
          if (mounted) setState(() {
            _categories
              ..clear()
              ..addAll(loaded);
            _templateLoaded = true;
          });
          return;
        }
      }
    } catch (_) {}
    // Fallback to defaults
    if (mounted && !_templateLoaded) {
      setState(() {
        _categories
          ..clear()
          ..addAll(_defaultCategories());
        _templateLoaded = true;
      });
    }
  }

  static IconData _iconFromName(String name) {
    const map = <String, IconData>{
      'tire_repair':                    Icons.tire_repair,
      'wb_sunny_outlined':              Icons.wb_sunny_outlined,
      'settings_outlined':              Icons.settings_outlined,
      'directions_bus_outlined':        Icons.directions_bus_outlined,
      'airline_seat_recline_normal':    Icons.airline_seat_recline_normal,
      'local_shipping_rounded':         Icons.local_shipping_rounded,
      'warning_amber_rounded':          Icons.warning_amber_rounded,
      'fire_extinguisher':              Icons.fire_extinguisher,
      'build_outlined':                 Icons.build_outlined,
    };
    return map[name] ?? Icons.checklist_rounded;
  }

  Future<void> _checkTodayInspection() async {
    final session = InspectionSession.instance;
    final typeParam = session.inspectionType.isNotEmpty
        ? session.inspectionType
        : 'pre_trip';
    try {
      final res = await ApiClient.getTodayInspection(type: typeParam);
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _todayInspection = Map<String, dynamic>.from(res.data as Map);
          _checkingToday   = false;
        });
      } else {
        if (mounted) setState(() => _checkingToday = false);
      }
    } catch (_) {
      // 404 = no inspection today — that's expected, not an error
      if (mounted) setState(() => _checkingToday = false);
    }
  }

  Future<void> _loadTruck() async {
    try {
      final res = await ApiClient.getDriverData();
      if (res.statusCode == 200) {
        final active = res.data['active_truck'];
        if (active != null && mounted) {
          setState(() {
            _truckId   = active['id'] as int?;
            _truckUnit = active['unit_number'] ?? 'Vehicle';
          });
        }
      }
    } catch (_) {}
  }

  int get _totalItems  => _categories.fold(0, (s, c) => s + c.items.length);
  int get _checkedItems => _categories.fold(0,
      (s, c) => s + c.items.where((i) => i.status != null).length);
  double get _progress => _totalItems > 0 ? _checkedItems / _totalItems : 0;

  @override
  Widget build(BuildContext context) {
    if (_checkingToday) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F3FF),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_todayInspection != null) {
      return _buildCompletedScreen();
    }

    return Scaffold(
      backgroundColor: _surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _buildProgressCard(),
                const SizedBox(height: 12),
                _buildVehicleCard(),
                const SizedBox(height: 12),
                ..._buildCategoryList(),
                const SizedBox(height: 12),
                _buildComplianceFooter(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildCompletedScreen() {
    final insp       = _todayInspection!;
    final passed     = (insp['passed_items'] ?? 0) as int;
    final failed     = (insp['failed_items'] ?? 0) as int;
    final total      = passed + failed;
    final inspNum    = insp['inspection_number'] ?? insp['id'];
    final typeRaw    = (insp['type_display'] ?? insp['inspection_type'] ?? '').toString();
    final typeLabel  = typeRaw.replaceAll('_', ' ').toUpperCase();
    final submittedAt = insp['submitted_at'] != null
        ? DateTime.tryParse(insp['submitted_at'].toString())?.toLocal()
        : null;
    final timeStr = submittedAt != null
        ? '${submittedAt.hour.toString().padLeft(2,'0')}:${submittedAt.minute.toString().padLeft(2,'0')}'
        : '';
    final dateStr = submittedAt != null
        ? '${_monthName(submittedAt.month)} ${submittedAt.day}, ${submittedAt.year}'
        : '';
    final score = total > 0 ? ((passed / total) * 100).round() : 100;
    final allPassed = failed == 0;

    return Scaffold(
      backgroundColor: _surface,
      body: Column(children: [
        // ── Hero banner ───────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF020D1F), Color(0xFF0A2550), Color(0xFF0453CD)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(children: [
              Positioned(top: -30, right: -30,
                child: Container(width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _cyan.withValues(alpha: 0.07)))),
              Positioned(bottom: -20, left: -20,
                child: Container(width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: _white, size: 16)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
                      child: Text('#$inspNum', style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: _white))),
                  ]),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _cyan.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _cyan.withValues(alpha: 0.4))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6,
                        decoration: const BoxDecoration(
                            color: _cyan, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(typeLabel, style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: _cyan, letterSpacing: 0.8)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: allPassed
                            ? const Color(0xFF15803D).withValues(alpha: 0.25)
                            : Colors.orange.withValues(alpha: 0.25),
                        border: Border.all(
                          color: allPassed
                              ? const Color(0xFF22C55E).withValues(alpha: 0.6)
                              : Colors.orange.withValues(alpha: 0.6),
                          width: 2)),
                      child: Icon(
                        allPassed ? Icons.verified_rounded : Icons.warning_rounded,
                        color: allPassed ? const Color(0xFF22C55E) : Colors.orange,
                        size: 28)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(allPassed ? 'All Clear!' : '$failed Issue${failed > 1 ? 's' : ''} Found',
                          style: GoogleFonts.inter(fontSize: 24,
                              fontWeight: FontWeight.w900, color: _white,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text(dateStr.isEmpty ? 'Today' : '$dateStr  ·  $timeStr',
                          style: GoogleFonts.inter(fontSize: 12,
                              color: Colors.white60, fontWeight: FontWeight.w500)),
                    ])),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(children: [
              Row(children: [
                _CompletedStat('$passed', 'Passed',
                    Icons.check_circle_rounded, const Color(0xFF15803D)),
                const SizedBox(width: 10),
                _CompletedStat('$failed', 'Failed',
                    Icons.cancel_rounded, const Color(0xFFB91C1C)),
                const SizedBox(width: 10),
                _CompletedStat('$total', 'Total',
                    Icons.checklist_rounded, _navy),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8, offset: const Offset(0, 2))]),
                child: Column(children: [
                  Row(children: [
                    Text('Compliance Score', style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
                    const Spacer(),
                    Text('$score%', style: GoogleFonts.inter(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: allPassed ? const Color(0xFF15803D) : _blue)),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: score / 100, minHeight: 10,
                      backgroundColor: const Color(0xFFDCE2F3),
                      valueColor: AlwaysStoppedAnimation(
                          allPassed ? const Color(0xFF15803D) : _blue))),
                  if (allPassed) ...[const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.verified_user_rounded,
                          size: 15, color: Color(0xFF15803D)),
                      const SizedBox(width: 6),
                      Text('Vehicle passed all safety checks',
                          style: GoogleFonts.inter(fontSize: 12,
                              color: const Color(0xFF15803D),
                              fontWeight: FontWeight.w600)),
                    ])],
                ]),
              ),
              if (failed > 0) ...[const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA))),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB91C1C),
                        borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: _white, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$failed Item${failed > 1 ? 's' : ''} Need Attention',
                          style: GoogleFonts.inter(fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF991B1B))),
                      const SizedBox(height: 2),
                      Text('Review failed items and schedule maintenance.',
                          style: GoogleFonts.inter(fontSize: 12,
                              color: const Color(0xFFB91C1C))),
                    ])),
                  ]),
                )],
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  final session = InspectionSession.instance;
                  session.existingInspectionId = insp['id'] as int?;
                  setState(() => _todayInspection = null);
                },
                child: Container(
                  width: double.infinity, height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0341A8), Color(0xFF0453CD)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                      color: _blue.withValues(alpha: 0.3),
                      blurRadius: 14, offset: const Offset(0, 5))]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.edit_rounded, color: _white, size: 20),
                    const SizedBox(width: 10),
                    Text('Edit This Inspection', style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w800, color: _white)),
                  ])),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); context.push('/driver-inspection/history'); },
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    color: _navy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _navy.withValues(alpha: 0.15))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.history_rounded, color: _navy, size: 18),
                    const SizedBox(width: 8),
                    Text('View History', style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600, color: _navy)),
                  ])),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); context.pop(); },
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.arrow_back_rounded, color: _grey, size: 18),
                    const SizedBox(width: 8),
                    Text('Go Back', style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600, color: _grey)),
                  ])),
              ),

            ]),
          ),
        ),
      ]),
    );
  }

  Widget _CompletedStat(String value, String label, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: _white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6, offset: const Offset(0, 2))]),
          child: Column(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: color, size: 20)),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(
                fontSize: 11, color: _grey, fontWeight: FontWeight.w500)),
          ]),
        ),
      );

  String _monthName(int m) => const ['','Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'][m];


  Widget _buildAppBar() => SliverAppBar(
    pinned: true,
    expandedHeight: 130,
    backgroundColor: _navy,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    elevation: 0,
    leading: IconButton(
      icon: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: _white, size: 16),
      ),
      onPressed: () => context.pop(),
    ),
    actions: [
      IconButton(
        icon: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.more_vert, color: _white, size: 18),
        ),
        onPressed: () {},
      ),
      const SizedBox(width: 8),
    ],
    flexibleSpace: FlexibleSpaceBar(
      collapseMode: CollapseMode.parallax,
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF031634), Color(0xFF0A2550), Color(0xFF0453CD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          Positioned(right: -20, top: -20,
            child: Container(width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04)))),
          Positioned(left: -30, bottom: -30,
            child: Container(width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _cyan.withOpacity(0.07)))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _cyan.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _cyan.withOpacity(0.35)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: _cyan, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text('Pre-Trip', style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: _cyan, letterSpacing: 0.5)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('Inspection Checklist',
                    style: GoogleFonts.inter(fontSize: 22,
                        fontWeight: FontWeight.w900, color: _white,
                        letterSpacing: -0.3)),
                ]),
            ),
          ),
        ]),
      ),
    ),
  );

  // ── Photo picker ──────────────────────────────────────────────────────────────
  Future<void> _pickPhoto(_Item item) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFDCE2F3),
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Attach Photo', style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF031634))),
          const SizedBox(height: 20),
          _photoSourceTile(Icons.camera_alt_rounded, 'Take a Photo', ImageSource.camera),
          const SizedBox(height: 10),
          _photoSourceTile(Icons.photo_library_rounded, 'Choose from Gallery', ImageSource.gallery),
          const SizedBox(height: 10),
          if (item.photoPath != null)
            GestureDetector(
              onTap: () { Navigator.pop(context, null); setState(() => item.photoPath = null); },
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Text('Remove Photo', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                ]),
              ),
            ),
        ]),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1200);
    if (picked != null && mounted) setState(() => item.photoPath = picked.path);
  }

  Widget _photoSourceTile(IconData icon, String label, ImageSource source) =>
      GestureDetector(
        onTap: () => Navigator.pop(context, source),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FA), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: const Color(0xFF0453CD)),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF031634))),
          ]),
        ),
      );

  void _viewPhoto(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black, insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(child: Image.file(File(path), fit: BoxFit.contain)),
          Positioned(
            top: 40, right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildProgressCard() => Container(

    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0A2550), Color(0xFF0453CD)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
        color: _blue.withOpacity(0.3),
        blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Inspection Progress',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white60,
                  fontWeight: FontWeight.w500, letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text('${(_progress * 100).round()}% Complete',
              style: GoogleFonts.inter(fontSize: 22,
                  fontWeight: FontWeight.w800, color: _white)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$_checkedItems / $_totalItems tasks',
              style: GoogleFonts.inter(fontSize: 12,
                  fontWeight: FontWeight.w700, color: _white)),
        ),
      ]),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: _progress,
          minHeight: 7,
          backgroundColor: Colors.white.withOpacity(0.18),
          valueColor: const AlwaysStoppedAnimation(_cyan),
        ),
      ),
    ]),
  );

  Widget _buildVehicleCard() => Container(
    height: 90,
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: _blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.local_shipping_rounded,
              size: 24, color: _blue),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Assigned Vehicle',
              style: GoogleFonts.inter(fontSize: 11,
                  color: _grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(_truckUnit,
              style: GoogleFonts.inter(fontSize: 15,
                  fontWeight: FontWeight.w700, color: _navy)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('Active', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: Color(0xFF15803D))),
          ]),
        ),
      ]),
    ),
  );

  // Auto-advance to next category when all items in current are done
  void _checkAutoAdvance(_Category cat, int catIndex) {
    final allDone = cat.items.every((item) => item.status != null);
    if (!allDone) return;
    final nextIndex = catIndex + 1;
    if (nextIndex >= _categories.length) return; // last category — stay

    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _expanded = nextIndex);
      // Scroll: estimate ~(card height ~80px + 10px gap) per card + header offset
      const headerHeight = 230.0;
      const cardHeight   = 90.0;
      const gap          = 10.0;
      final targetOffset = headerHeight + nextIndex * (cardHeight + gap);
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  List<Widget> _buildCategoryList() {
    return List.generate(_categories.length, (i) {
      final cat = _categories[i];
      final isOpen = _expanded == i;
      final done = cat.items.where((item) => item.status != null).length;
      final hasIssue = cat.items.any((item) => item.status == false);

      // Status label
      final allDone = done == cat.items.length;
      final statusLabel = allDone
          ? '✓ Completed'
          : isOpen ? 'In Progress'
          : 'Not started';
      final statusColor = allDone
          ? const Color(0xFF15803D)
          : isOpen ? _blue : _grey;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOpen ? _blue.withOpacity(0.4) : _border,
              width: isOpen ? 1.5 : 1,
            ),
            boxShadow: isOpen ? [
              BoxShadow(color: _blue.withOpacity(0.08),
                  blurRadius: 12, offset: const Offset(0, 4)),
            ] : [
              BoxShadow(color: Colors.black.withOpacity(0.03),
                  blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _expanded = isOpen ? -1 : i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: isOpen ? _blue.withOpacity(0.10)
                          : allDone ? const Color(0xFF22C55E).withOpacity(0.08)
                          : _surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(allDone ? Icons.check_circle_rounded : cat.icon,
                        size: 22,
                        color: isOpen ? _blue
                            : allDone ? const Color(0xFF22C55E) : _grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cat.name, style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: isOpen ? _blue : _navy)),
                    const SizedBox(height: 2),
                    Text(statusLabel, style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: statusColor)),
                  ])),
                  if (hasIssue)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text('Issue', style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: Colors.red.shade700)),
                    ),
                  // Progress indicator
                  if (!allDone)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text('$done/${cat.items.length}',
                        style: GoogleFonts.inter(fontSize: 11,
                            fontWeight: FontWeight.w600, color: _grey)),
                    ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _grey, size: 22),
                  ),
                ]),
              ),
            ),
            if (isOpen) ...[
              Container(height: 1, color: _border),
              ...cat.items.map((item) => _buildCheckItem(item, cat)),
            ],
          ]),
        ),
      );
    });
  }

  Widget _buildCheckItem(_Item item, _Category cat) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item.label, style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w500, color: _navy))),
          GestureDetector(
            onTap: () => _pickPhoto(item),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: item.photoPath != null
                    ? _blue.withOpacity(0.10)
                    : _surface,
                borderRadius: BorderRadius.circular(8),
                border: item.photoPath != null
                    ? Border.all(color: _blue.withOpacity(0.4), width: 1.5)
                    : null,
              ),
              child: Icon(
                item.photoPath != null
                    ? Icons.photo_camera
                    : Icons.add_a_photo_outlined,
                size: 18,
                color: item.photoPath != null ? _blue : _grey,
              ),
            ),
          ),
        ]),
        // Photo thumbnail row
        if (item.photoPath != null) ...[         
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _viewPhoto(item.photoPath!),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(item.photoPath!),
                    height: 80, width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => item.photoPath = null),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          _PassFailBtn(
            label: 'PASS',
            icon: Icons.check_circle_outline,
            selected: item.status == true,
            isPass: true,
            onTap: () {
              setState(() {
                item.status = item.status == true ? null : true;
                HapticFeedback.selectionClick();
              });
              if (item.status == true) _checkAutoAdvance(cat, _expanded);
            },
          ),
          const SizedBox(width: 10),
          _PassFailBtn(
            label: 'FAIL',
            icon: Icons.cancel_outlined,
            selected: item.status == false,
            isPass: false,
            onTap: () {
              setState(() {
                item.status = item.status == false ? null : false;
                HapticFeedback.selectionClick();
              });
              if (item.status == false) {
                _checkAutoAdvance(cat, _expanded);
                Future.microtask(() => context.push('/driver-inspection/issue'));
              }
            },
          ),
        ]),
        if (cat.items.last != item)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(height: 1, color: _border),
          ),
      ]),
    );
  }

  Widget _buildComplianceFooter() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _navy,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
        color: _navy.withOpacity(0.3),
        blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: Row(children: [
      SizedBox(
        width: 60, height: 60,
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(
                _progress >= 0.8 ? _cyan : _blue),
            strokeWidth: 5,
          ),
          Text('${(_progress * 100).round()}%',
              style: GoogleFonts.inter(fontSize: 11,
                  fontWeight: FontWeight.w800, color: _white)),
        ]),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Daily Compliance',
            style: GoogleFonts.inter(fontSize: 15,
                fontWeight: FontWeight.w700, color: _white)),
        const SizedBox(height: 2),
        Text('Safety rating: ${_progress >= 0.8 ? '🟢 High' : _progress >= 0.5 ? '🟡 Medium' : '🔴 Low'}',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),
      ])),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.verified_outlined,
            color: Colors.white54, size: 20),
      ),
    ]),
  );

  Widget _buildFAB() => FloatingActionButton.extended(
    onPressed: () {
      final session = InspectionSession.instance;
      session.truckId   = _truckId;
      session.truckUnit = _truckUnit;
      session.checklistItems = _categories.expand((cat) => cat.items.map((item) {
        String? photoB64;
        if (item.photoPath != null) {
          try {
            photoB64 = base64Encode(File(item.photoPath!).readAsBytesSync());
          } catch (_) {}
        }
        return <String, dynamic>{
          'category': cat.name,
          'label':    item.label,
          'status':   item.status,
          'note':     '',
          if (photoB64 != null) 'photo': photoB64,
        };
      })).toList();
      context.push('/driver-inspection/review');
    },
    backgroundColor: _blue,
    elevation: 6,
    icon: const Icon(Icons.arrow_forward_rounded, color: _white, size: 18),
    label: Text('Review & Submit',
        style: GoogleFonts.inter(fontSize: 13,
            fontWeight: FontWeight.w700, color: _white)),
  );

  BoxDecoration _cardDeco() => BoxDecoration(
    color: _white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _border),
  );
}

// ── Data models ────────────────────────────────────────────────────────────────
class _Category {
  final String name;
  final IconData icon;
  final List<_Item> items;
  final int? serverId;
  _Category({required this.name, required this.icon,
      required this.items, this.serverId});
}

class _Item {
  final String label;
  final int? serverId;
  bool? status; // null = not set, true = pass, false = fail
  String? photoPath; // local file path of attached photo
  _Item(this.label, {this.serverId});
}

// ── PASS / FAIL button ─────────────────────────────────────────────────────────
class _PassFailBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool isPass;
  final VoidCallback onTap;

  const _PassFailBtn({
    required this.label, required this.icon,
    required this.selected, required this.isPass, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isPass ? _blue : Colors.red.shade600;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          decoration: BoxDecoration(
            color: selected ? activeColor : _white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? activeColor : _border,
              width: selected ? 0 : 1.5,
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16,
                color: selected ? _white : (isPass ? _grey : _grey)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: selected ? _white : _grey)),
          ]),
        ),
      ),
    );
  }
}

// ── Result badge for completed screen ─────────────────────────────────────────
class _ResultBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _ResultBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
          ),
          child: Center(
            child: Text('$count',
              style: GoogleFonts.inter(fontSize: 20,
                  fontWeight: FontWeight.w800, color: color)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: const Color(0xFF75777E))),
      ],
    );
  }
}
