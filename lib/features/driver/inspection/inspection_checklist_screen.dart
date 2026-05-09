import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import 'inspection_session.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _navy    = Color(0xFF031634);
const _blue    = Color(0xFF0453CD);
const _surface = Color(0xFFF0F3FF);
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

  int _expanded = 1; // Lights & Reflectors open by default
  int?   _truckId;
  String _truckUnit = 'Your Vehicle';

  // Today's completed inspection (if any)
  Map<String, dynamic>? _todayInspection;
  bool _checkingToday = true;

  @override
  void initState() {
    super.initState();
    _loadTruck();
    _checkTodayInspection();
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
    final insp = _todayInspection!;
    final passed = insp['passed_items'] ?? 0;
    final failed = insp['failed_items'] ?? 0;
    final total  = passed + failed;
    final inspNum = insp['inspection_number'] ?? insp['id'];
    final typeDisplay = (insp['type_display'] ?? insp['inspection_type'] ?? '')
        .toString().replaceAll('_', ' ');
    final submittedAt = insp['submitted_at'] != null
        ? DateTime.tryParse(insp['submitted_at'].toString())
        : null;
    final timeStr = submittedAt != null
        ? '${submittedAt.hour.toString().padLeft(2,'0')}:${submittedAt.minute.toString().padLeft(2,'0')}'
        : '';

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Container(
              color: _white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                  Text('Inspection',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: _navy)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Big green checkmark
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF15803D).withOpacity(0.12),
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          size: 60, color: Color(0xFF15803D)),
                    ),
                    const SizedBox(height: 20),
                    Text('Inspection Completed Today',
                      style: GoogleFonts.inter(fontSize: 22,
                          fontWeight: FontWeight.w700, color: _navy)),
                    const SizedBox(height: 8),
                    Text('$typeDisplay • $timeStr',
                      style: GoogleFonts.inter(fontSize: 14, color: _grey)),
                    const SizedBox(height: 28),

                    // Results card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                          color: _navy.withOpacity(0.06),
                          blurRadius: 12, offset: const Offset(0,4))],
                      ),
                      child: Column(
                        children: [
                          Text('Inspection #$inspNum',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600,
                                fontSize: 15, color: _navy)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ResultBadge(label: 'Passed', count: passed,
                                  color: const Color(0xFF15803D)),
                              _ResultBadge(label: 'Failed', count: failed,
                                  color: const Color(0xFFB91C1C)),
                              _ResultBadge(label: 'Total', count: total,
                                  color: _navy),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Edit / Redo buttons
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: Text('Edit This Inspection',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600,
                              fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: _white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          // Pre-load checklist with existing data and go to review
                          final session = InspectionSession.instance;
                          session.existingInspectionId = insp['id'] as int?;
                          setState(() => _todayInspection = null);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text('Go Back',
                        style: GoogleFonts.inter(
                            color: _grey, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() => SliverAppBar(
    pinned: true,
    backgroundColor: _white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: _navy),
      onPressed: () => context.pop(),
    ),
    title: Text('Pre-Trip Inspection',
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _navy)),
    actions: [
      IconButton(icon: const Icon(Icons.more_vert, color: _navy),
          onPressed: () {}),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _border),
    ),
  );

  Widget _buildProgressCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDeco(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Inspection Progress',
          style: GoogleFonts.inter(fontSize: 12, color: _grey,
              fontWeight: FontWeight.w500, letterSpacing: 0.2)),
      const SizedBox(height: 4),
      Row(children: [
        Text('${(_progress * 100).round()}% Complete',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: _navy)),
        const Spacer(),
        Text('$_checkedItems of $_totalItems tasks',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _blue)),
      ]),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: _progress,
          minHeight: 8,
          backgroundColor: const Color(0xFFE8EBF5),
          valueColor: const AlwaysStoppedAnimation(_blue),
        ),
      ),
    ]),
  );

  Widget _buildVehicleCard() => Container(
    height: 110,
    decoration: BoxDecoration(
      color: _navy,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Stack(children: [
      // Watermark
      Positioned(right: -10, top: 10, bottom: 10,
        child: Opacity(opacity: 0.08, child: Icon(Icons.local_shipping,
            size: 120, color: _white))),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('Assigned Vehicle',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 4),
          Text('Unit #4052 – Peterbilt 579',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700,
                  color: _white)),
        ]),
      ),
    ]),
  );

  List<Widget> _buildCategoryList() {
    return List.generate(_categories.length, (i) {
      final cat = _categories[i];
      final isOpen = _expanded == i;
      final done = cat.items.where((item) => item.status != null).length;
      final hasIssue = cat.items.any((item) => item.status == false);

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOpen ? _blue.withOpacity(0.35) : _border,
              width: isOpen ? 1.5 : 1,
            ),
          ),
          child: Column(children: [
            // Header row
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _expanded = isOpen ? -1 : i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: isOpen ? _blue.withOpacity(0.10) : _surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(cat.icon, size: 20,
                        color: isOpen ? _blue : _grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cat.name, style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: isOpen ? _blue : _navy)),
                    Text(done == cat.items.length
                        ? '${cat.items.length} items checked'
                        : isOpen ? 'Pending Review' : 'Not started',
                        style: GoogleFonts.inter(fontSize: 12,
                            color: isOpen ? _blue.withOpacity(0.7) : _grey)),
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
                  Icon(isOpen ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: _grey, size: 22),
                ]),
              ),
            ),
            // Expanded items
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
            onTap: () {/* photo capture */},
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_a_photo_outlined, size: 18, color: _grey),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _PassFailBtn(
            label: 'PASS',
            icon: Icons.check_circle_outline,
            selected: item.status == true,
            isPass: true,
            onTap: () => setState(() {
              item.status = item.status == true ? null : true;
              HapticFeedback.selectionClick();
            }),
          ),
          const SizedBox(width: 10),
          _PassFailBtn(
            label: 'FAIL',
            icon: Icons.cancel_outlined,
            selected: item.status == false,
            isPass: false,
            onTap: () => setState(() {
              item.status = item.status == false ? null : false;
              HapticFeedback.selectionClick();
              if (item.status == false) {
                Future.microtask(() => context.push('/driver-inspection/issue'));
              }
            }),
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
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _navy,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      SizedBox(
        width: 56, height: 56,
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(_white),
            strokeWidth: 5,
          ),
          Text('${(_progress * 100).round()}%',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                  color: _white)),
        ]),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Daily Compliance',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700,
                color: _white)),
        Text('Vehicle safety rating: ${_progress >= 0.8 ? 'High' : _progress >= 0.5 ? 'Medium' : 'Low'}',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),
      ])),
      const Icon(Icons.settings_outlined, color: Colors.white38, size: 20),
    ]),
  );

  Widget _buildFAB() => FloatingActionButton(
    onPressed: () {
      // Populate shared session before navigating
      final session = InspectionSession.instance;
      session.truckId   = _truckId;
      session.truckUnit = _truckUnit;
      session.checklistItems = _categories.expand((cat) => cat.items.map((item) => {
        'category': cat.name,
        'label':    item.label,
        'status':   item.status,
        'note':     '',
      })).toList();
      context.push('/driver-inspection/review');
    },
    backgroundColor: _blue,
    elevation: 4,
    child: const Icon(Icons.arrow_forward_rounded, color: _white),
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
  _Category({required this.name, required this.icon, required this.items});
}

class _Item {
  final String label;
  bool? status; // null = not set, true = pass, false = fail
  _Item(this.label);
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
