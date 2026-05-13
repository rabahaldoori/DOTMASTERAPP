import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/font_ext.dart';

const _navy  = Color(0xFF031634);
const _blue  = Color(0xFF3B82F6);
const _green = Color(0xFF059669);
const _grey  = Color(0xFF64748B);
const _bg    = Color(0xFFF8FAFF);

class AddTripPage extends StatefulWidget {
  /// Called after a trip is successfully created so the list can refresh.
  final VoidCallback? onCreated;
  const AddTripPage({super.key, this.onCreated});

  @override
  State<AddTripPage> createState() => _AddTripPageState();
}

class _AddTripPageState extends State<AddTripPage> {
  final _formKey = GlobalKey<FormState>();

  // Route
  final _originCtrl = TextEditingController();
  final _destCtrl   = TextEditingController();
  final _stopsCtrl  = <TextEditingController>[];

  // Route result
  Map<String, dynamic>? _routeResult;
  bool _calcLoading = false;
  String? _calcError;

  // Dates
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;

  // Truck / Driver dropdowns
  List _trucks  = [];
  List _drivers = [];
  int? _selectedTruckId;
  int? _selectedDriverId;
  bool _loadingDropdowns = true;

  // Notes
  final _notesCtrl = TextEditingController();

  // Submit
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    for (final c in _stopsCtrl) {
      c.dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Load trucks & drivers ────────────────────────────────────────────────
  Future<void> _loadDropdowns() async {
    try {
      final results = await Future.wait([
        ApiClient.getTrucks(),
        ApiClient.getDrivers(),
      ]);
      final trucks  = List.from(results[0].data['results'] ?? results[0].data ?? []);
      final drivers = List.from(results[1].data['results'] ?? results[1].data ?? []);
      if (mounted) setState(() { _trucks = trucks; _drivers = drivers; _loadingDropdowns = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDropdowns = false);
    }
  }

  // ── Calculate route ──────────────────────────────────────────────────────
  Future<void> _calculateRoute() async {
    if (_originCtrl.text.trim().isEmpty || _destCtrl.text.trim().isEmpty) {
      setState(() => _calcError = 'Enter a From and To address first.');
      return;
    }
    setState(() { _calcLoading = true; _calcError = null; _routeResult = null; });
    try {
      final res = await ApiClient.calculateRoute(
        origin:      _originCtrl.text.trim(),
        destination: _destCtrl.text.trim(),
        stops:       _stopsCtrl.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
      );
      final data = Map<String, dynamic>.from(res.data);

      // Auto-populate End Date from estimated arrival
      final totalSecs = ((data['duration_seconds'] ?? 0) as num).toInt();
      if (totalSecs > 0) {
        final departAt = _startDate != null
            ? DateTime(
                _startDate!.year, _startDate!.month, _startDate!.day,
                _startTime?.hour ?? 8, _startTime?.minute ?? 0,
              )
            : DateTime.now().copyWith(hour: 8, minute: 0, second: 0);
        final arrival = departAt.add(Duration(seconds: totalSecs));
        _endDate = DateTime(arrival.year, arrival.month, arrival.day);
      }

      setState(() { _routeResult = data; _calcLoading = false; });
    } catch (e) {
      setState(() { _calcError = 'Route calculation failed. Check the addresses and try again.'; _calcLoading = false; });
    }
  }

  // ── Date pickers ─────────────────────────────────────────────────────────
  Future<void> _pickStartDate() async {
    FocusScope.of(context).unfocus(); // prevent autocomplete re-trigger
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2030),
      builder: _datePickerTheme,
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _pickStartTime() async {
    FocusScope.of(context).unfocus(); // prevent autocomplete re-trigger
    final t = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: _datePickerTheme,
    );
    if (t != null) setState(() => _startTime = t);
  }

  Future<void> _pickEndDate() async {
    FocusScope.of(context).unfocus(); // prevent autocomplete re-trigger
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2030),
      builder: _datePickerTheme,
    );
    if (d != null) setState(() => _endDate = d);
  }

  Widget _datePickerTheme(BuildContext ctx, Widget? child) => Theme(
    data: Theme.of(ctx).copyWith(
      colorScheme: const ColorScheme.light(primary: _navy, onPrimary: Colors.white),
    ),
    child: child!,
  );

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) { _showErr('Please select a departure date.'); return; }
    if (_selectedTruckId == null) { _showErr('Please select a truck.'); return; }
    if (_selectedDriverId == null) { _showErr('Please select a driver.'); return; }

    // Build start datetime string
    final st = _startTime ?? TimeOfDay.now();
    final startDt = DateTime(_startDate!.year, _startDate!.month, _startDate!.day, st.hour, st.minute);
    final startStr = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(startDt);
    final endStr   = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;

    final milesState = _routeResult?['miles_by_state'] as Map? ?? {};
    final totalMiles = (_routeResult?['total_miles'] ?? 0.0).toDouble();

    final payload = <String, dynamic>{
      'origin_address':      _originCtrl.text.trim(),
      'destination_address': _destCtrl.text.trim(),
      'origin_city':         _routeResult?['origin_city'] ?? '',
      'origin_state':        _routeResult?['origin_state'] ?? '',
      'destination_city':    _routeResult?['destination_city'] ?? '',
      'destination_state':   _routeResult?['destination_state'] ?? '',
      'start_date':          startStr,
      if (endStr != null) 'end_date': endStr,
      'truck':               _selectedTruckId,
      'driver':              _selectedDriverId,
      'notes':               _notesCtrl.text.trim(),
      'miles_by_state':      Map<String, dynamic>.from(milesState),
      'total_miles':         totalMiles,
      'status':              'active',
    };

    setState(() => _submitting = true);
    try {
      await ApiClient.createTrip(payload);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Trip created successfully!'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      setState(() => _submitting = false);
      _showErr('Failed to create trip. Please try again.');
    }
  }

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Stack(
        children: [
          // ── Scrollable body ───────────────────────────────────────────────
          CustomScrollView(
            slivers: [
              // ── Pinned AppBar (title only, no expansion) ──────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withAlpha(80), width: 1.2),
                      ),
                      child: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
                title: Row(children: [
                  const Icon(Icons.local_shipping_rounded, size: 15, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text('Log New Trip',
                      style: context.af(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),

              // ── Hero banner (scrolls away) ────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F1F3D), Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(30),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('IFTA TRIP LOG',
                                  style: TextStyle(fontSize: 9, color: Colors.white70,
                                      fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                            ),
                            const SizedBox(height: 8),
                            const Text('New Trip',
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                            const Text('Route calculated via Google Maps',
                                style: TextStyle(fontSize: 11.5, color: Colors.white60)),
                          ],
                        ),
                      ),
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withAlpha(40), width: 1.5),
                        ),
                        child: const Icon(Icons.local_shipping_rounded, color: Colors.white70, size: 30),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Form sections ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Form(
                  key: _formKey,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 90),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ════ Section 1: Route ════════════════════════════════
                        _sectionHeader(Icons.route_rounded, 'Route Details', _blue),
                        const SizedBox(height: 10),
                        _card([
                          // From
                          _PlacesField(
                            controller: _originCtrl,
                            hint: 'e.g. Dallas, TX',
                            label: 'From Address *',
                            icon: Icons.radio_button_checked_rounded,
                            iconColor: _green,
                            onChanged: (_) => setState(() => _routeResult = null),
                          ),
                          // Stops
                          ..._stopsCtrl.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _PlacesField(
                              controller: e.value,
                              hint: 'e.g. Albuquerque, NM',
                              label: 'Stop ${e.key + 1}',
                              icon: Icons.radio_button_unchecked_rounded,
                              iconColor: _blue,
                              onChanged: (_) => setState(() => _routeResult = null),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                onPressed: () => setState(() {
                                  e.value.dispose();
                                  _stopsCtrl.removeAt(e.key);
                                  _routeResult = null;
                                }),
                              ),
                            ),
                          )),
                          // Add stop
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 2),
                            child: TextButton.icon(
                              onPressed: () => setState(() => _stopsCtrl.add(TextEditingController())),
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 15, color: _blue),
                              label: Text('Add Stop',
                                  style: context.af(fontSize: 12.5, color: _blue, fontWeight: FontWeight.w700)),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0)),
                            ),
                          ),
                          // Dotted connector
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                            child: Row(children: [
                              Container(width: 2, height: 18,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(1),
                                  )),
                            ]),
                          ),
                          // To
                          _PlacesField(
                            controller: _destCtrl,
                            hint: 'e.g. Oklahoma City, OK',
                            label: 'To Address *',
                            icon: Icons.location_on_rounded,
                            iconColor: Colors.red,
                            onChanged: (_) => setState(() => _routeResult = null),
                          ),
                          const SizedBox(height: 14),
                          // ── Calculate Route ─────────────────────────────
                          Container(
                            width: double.infinity, height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _calcLoading
                                    ? [Colors.grey.shade400, Colors.grey.shade400]
                                    : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(color: _blue.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _calcLoading ? null : _calculateRoute,
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  _calcLoading
                                      ? const SizedBox(width: 18, height: 18,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Icon(Icons.route_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(_calcLoading ? 'Calculating…' : 'Calculate Route',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                                          color: Colors.white, letterSpacing: 0.3)),
                                ]),
                              ),
                            ),
                          ),
                          // Error
                          if (_calcError != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(children: [
                                Icon(Icons.error_outline_rounded, color: Colors.red.shade600, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_calcError!,
                                    style: context.af(fontSize: 12, color: Colors.red.shade700))),
                              ]),
                            ),
                          ],
                          // Route result card
                          if (_routeResult != null) ...[
                            const SizedBox(height: 14),
                            _RouteResult(
                              result: _routeResult!,
                              departureDt: _startDate != null
                                  ? DateTime(
                                      _startDate!.year, _startDate!.month, _startDate!.day,
                                      _startTime?.hour ?? 8, _startTime?.minute ?? 0,
                                    )
                                  : DateTime.now().copyWith(hour: 8, minute: 0, second: 0),
                            ),
                          ],
                        ]),

                        const SizedBox(height: 16),

                        // ════ Section 2: Schedule ══════════════════════════════
                        _sectionHeader(Icons.calendar_month_rounded, 'Schedule', const Color(0xFF7C3AED)),
                        const SizedBox(height: 10),
                        _card([
                          Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _fieldLabel('Departure Date *'),
                              const SizedBox(height: 6),
                              _DatePickerBtn(
                                label: _startDate != null
                                    ? DateFormat('MM/dd/yyyy').format(_startDate!) : 'mm/dd/yyyy',
                                icon: Icons.calendar_today_rounded,
                                onTap: _pickStartDate,
                              ),
                            ])),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _fieldLabel('Departure Time'),
                              const SizedBox(height: 6),
                              _DatePickerBtn(
                                label: _startTime != null ? _startTime!.format(context) : '08:00',
                                icon: Icons.access_time_rounded,
                                onTap: _pickStartTime,
                              ),
                            ])),
                          ]),
                          const SizedBox(height: 12),
                          _fieldLabel('End Date'),
                          const SizedBox(height: 6),
                          _DatePickerBtn(
                            label: _endDate != null
                                ? DateFormat('MM/dd/yyyy').format(_endDate!) : 'mm/dd/yyyy (optional)',
                            icon: Icons.event_rounded,
                            onTap: _pickEndDate,
                          ),
                        ]),

                        const SizedBox(height: 16),

                        // ════ Section 3: Assignment ════════════════════════════
                        _sectionHeader(Icons.people_alt_rounded, 'Assignment', const Color(0xFF0891B2)),
                        const SizedBox(height: 10),
                        if (_loadingDropdowns)
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2, color: _blue)),
                          )
                        else
                          _card([
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(child: _DropdownField(
                                label: 'Truck *',
                                hint: 'Select truck…',
                                items: _trucks.map((t) => DropdownMenuItem(
                                  value: t['id'] as int?,
                                  child: Text(t['unit_number']?.toString() ?? '—',
                                      overflow: TextOverflow.ellipsis),
                                )).toList(),
                                value: _selectedTruckId,
                                onChanged: (v) => setState(() => _selectedTruckId = v),
                              )),
                              const SizedBox(width: 12),
                              Expanded(child: _DropdownField(
                                label: 'Driver *',
                                hint: 'Select driver…',
                                items: _drivers.map((d) {
                                  final name = d['full_name']?.toString()
                                      ?? '${d['first_name'] ?? ''} ${d['last_name'] ?? ''}'.trim();
                                  return DropdownMenuItem(
                                    value: d['id'] as int?,
                                    child: Text(name.isEmpty ? '—' : name,
                                        overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                value: _selectedDriverId,
                                onChanged: (v) => setState(() => _selectedDriverId = v),
                              )),
                            ]),
                          ]),

                        const SizedBox(height: 16),

                        // ════ Section 4: Notes ════════════════════════════════
                        _sectionHeader(Icons.notes_rounded, 'Notes', const Color(0xFF059669)),
                        const SizedBox(height: 10),
                        _card([
                          TextFormField(
                            controller: _notesCtrl,
                            minLines: 3, maxLines: 5,
                            style: context.af(fontSize: 13, color: _navy),
                            decoration: InputDecoration(
                              hintText: 'Optional trip notes…',
                              hintStyle: context.af(fontSize: 13, color: _grey),
                              border: InputBorder.none,
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Sticky bottom Create Trip button ─────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(18),
                      blurRadius: 24, offset: const Offset(0, -6)),
                ],
              ),
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 12),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0F1F3D), Color(0xFF1E3A8A)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: _navy.withAlpha(80), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _submitting ? null : _submit,
                    child: Center(
                      child: _submitting
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text('Create Trip',
                                  style: context.af(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                            ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section header row with colored icon pill.
  Widget _sectionHeader(IconData icon, String title, Color color) => Row(children: [
    Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 15, color: color),
    ),
    const SizedBox(width: 10),
    Text(title,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.2)),
  ]);

  /// White rounded card container.
  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 16, offset: const Offset(0, 4)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(label, style: context.af(
        fontSize: 10, fontWeight: FontWeight.w800,
        color: _grey, letterSpacing: 0.8)),
  );

  Widget _fieldLabel(String label) => Text(label,
      style: context.af(fontSize: 12.5, color: _grey, fontWeight: FontWeight.w600));
}

// ── Places autocomplete field ─────────────────────────────────────────────────
class _PlacesField extends StatelessWidget {
  final TextEditingController controller;
  final String hint, label;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  const _PlacesField({
    required this.controller, required this.hint,
    required this.label, required this.icon, required this.iconColor,
    this.trailing, this.onChanged,
  });

  InputDecoration get _deco => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: _grey),
    prefixIcon: Padding(
      padding: const EdgeInsets.all(12),
      child: Icon(icon, size: 16, color: iconColor),
    ),
    suffixIcon: trailing,
    filled: true, fillColor: const Color(0xFFF8FAFF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _blue, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12.5, color: _grey, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TypeAheadField<String>(
        controller: controller,
        hideOnEmpty: true,
        hideOnLoading: true,
        builder: (ctx, ctrl, focus) => TextField(
          controller: ctrl,
          focusNode: focus,
          style: const TextStyle(fontSize: 13, color: _navy),
          textCapitalization: TextCapitalization.words,
          decoration: _deco,
          onChanged: onChanged,
        ),
        // Append a sentinel value so we can render the "powered by Google" footer
        // only when real suggestions are showing — not as a persistent overlay.
        suggestionsCallback: (query) async {
          if (query.length < 2) return [];
          final results = await ApiClient.placesAutocomplete(query);
          if (results.isNotEmpty) return [...results, '__FOOTER__'];
          return [];
        },
        itemBuilder: (ctx, suggestion) {
          if (suggestion == '__FOOTER__') {
            return Container(
              width: double.infinity,
              color: const Color(0xFFF8F8F8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('powered by Google',
                    style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic)),
              ),
            );
          }
          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on_outlined, size: 16, color: _grey),
            title: Text(suggestion,
                style: const TextStyle(fontSize: 13, color: _navy, fontWeight: FontWeight.w500)),
          );
        },
        onSelected: (suggestion) {
          if (suggestion == '__FOOTER__') return; // footer is not selectable
          controller.text = suggestion;
          onChanged?.call(suggestion);
        },
        emptyBuilder: (_) => const SizedBox.shrink(),
        decorationBuilder: (ctx, child) => Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          shadowColor: Colors.black26,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
        ),
      ),
    ],
  );
}

// ── Date picker button ────────────────────────────────────────────────────────
class _DatePickerBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DatePickerBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: _grey),
        const SizedBox(width: 8),
        Expanded(child: Text(label,
            style: context.af(fontSize: 12.5, color: _navy),
            overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}

// ── Dropdown field ────────────────────────────────────────────────────────────
class _DropdownField extends StatelessWidget {
  final String label, hint;
  final List<DropdownMenuItem<int?>> items;
  final int? value;
  final ValueChanged<int?> onChanged;
  const _DropdownField({
    required this.label, required this.hint,
    required this.items, required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: context.af(fontSize: 12.5, color: _grey, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      DropdownButtonFormField<int?>(
        value: value,
        items: items,
        onChanged: onChanged,
        hint: Text(hint, style: context.af(fontSize: 12.5, color: _grey)),
        style: context.af(fontSize: 13, color: _navy),
        menuMaxHeight: 240, // prevent going behind sticky bottom bar / navbar
        decoration: InputDecoration(
          filled: true, fillColor: _bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _blue, width: 1.5),
          ),
        ),
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _grey),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    ],
  );
}

// ── Route result card ─────────────────────────────────────────────────────────
class _RouteResult extends StatelessWidget {
  final Map<String, dynamic> result;
  final DateTime? departureDt;
  const _RouteResult({required this.result, this.departureDt});

  static const _fmcsaMaxDriveH   = 11.0;
  static const _fmcsaBreakAfterH =  8.0;
  static final _timeFmt = DateFormat('h:mm a');
  static final _dtFmt   = DateFormat('EEE, MMM d, h:mm a');

  @override
  Widget build(BuildContext context) {
    final totalMiles    = (result['total_miles'] ?? 0.0).toDouble();
    final milesState    = (result['miles_by_state'] as Map?)?.cast<String, dynamic>() ?? {};
    final duration      = result['duration_text'] as String? ?? '';
    final totalSecs     = ((result['duration_seconds'] ?? 0) as num).toInt();
    final totalH        = totalSecs / 3600.0;
    final departAt      = departureDt ?? DateTime.now();
    final arrivalDt     = departAt.add(Duration(seconds: totalSecs));
    final needsOvernightStop = totalH > _fmcsaMaxDriveH;
    final needsBreak30       = totalH > _fmcsaBreakAfterH;

    // FMCSA break time: 8h into drive
    final breakStartDt   = departAt.add(Duration(seconds: (_fmcsaBreakAfterH * 3600).toInt()));
    final breakEndDt     = breakStartDt.add(const Duration(minutes: 30));
    // Overnight stop: 11h into drive
    final stopDt         = departAt.add(Duration(seconds: (_fmcsaMaxDriveH * 3600).toInt()));
    final resumeDt       = stopDt.add(const Duration(hours: 10));
    final remainingSecs  = totalSecs - (_fmcsaMaxDriveH * 3600).toInt();
    final remainH        = remainingSecs ~/ 3600;
    final remainM        = (remainingSecs % 3600) ~/ 60;
    final stopPct        = totalMiles > 0
        ? ((_fmcsaMaxDriveH / totalH) * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFEFF6FF)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: total miles + duration ───────────────────────────────
          Row(children: [
            const Icon(Icons.check_circle_rounded, color: _green, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_fmt(totalMiles)} mi total',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _green),
              ),
            ),
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 14, color: _grey),
              const SizedBox(width: 4),
              Text(duration, style: const TextStyle(fontSize: 12.5, color: _grey, fontWeight: FontWeight.w600)),
            ]),
          ]),
          // ── Estimated arrival ────────────────────────────────────────────
          if (totalSecs > 0) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.flight_land_rounded, size: 14, color: _navy),
              const SizedBox(width: 6),
              Text('Est. Arrival: ', style: const TextStyle(fontSize: 12, color: _grey)),
              Text(_dtFmt.format(arrivalDt),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _navy)),
            ]),
          ],
          // ── Miles by state ───────────────────────────────────────────────
          if (milesState.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFBFDBFE)),
            const SizedBox(height: 8),
            const Text('MILES BY STATE (IFTA)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _grey, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: milesState.entries.map((e) {
                final m = (e.value as num).toDouble();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text('${e.key}  ${m.toStringAsFixed(0)} mi',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _navy)),
                );
              }).toList(),
            ),
          ],
          // ── FMCSA compliance block ───────────────────────────────────────
          if (needsBreak30 || needsOvernightStop) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded, size: 15, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        needsOvernightStop
                            ? 'Overnight Stop Required (FMCSA)'
                            : '30-Min Break Required (FMCSA)',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.red),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    needsOvernightStop
                        ? 'Drive time is $duration — exceeds the 11-hour daily driving limit. Driver must stop after 11 hours and take a 10-hour consecutive rest break.'
                        : 'Drive time is $duration — exceeds 8 hours. A 30-minute break is required.',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9F1239), height: 1.4),
                  ),
                  // 30-min break card
                  if (needsBreak30) ...[
                    const SizedBox(height: 10),
                    _fmcsaCard(
                      icon: '☕',
                      title: '30-Min Break (Day 1)',
                      body: 'After 8h driving at ${_timeFmt.format(breakStartDt)} · Resume ${_timeFmt.format(breakEndDt)}',
                      borderColor: const Color(0xFFFEF3C7),
                      bgColor: const Color(0xFFFFFBEB),
                    ),
                  ],
                  // Overnight stop card
                  if (needsOvernightStop) ...[
                    const SizedBox(height: 8),
                    _fmcsaCard(
                      icon: '🛌',
                      title: '~$stopPct% along the route',
                      body: 'Stop: ${_dtFmt.format(stopDt)} · 10-hour rest required\n'
                            'Resume: ${_dtFmt.format(resumeDt)} · Remaining: ${remainH}h ${remainM}m',
                      borderColor: const Color(0xFFFECACA),
                      bgColor: const Color(0xFFFFF1F2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(double v) {
    final n = NumberFormat('#,##0.##');
    return n.format(v);
  }

  Widget _fmcsaCard({
    required String icon, required String title, required String body,
    required Color borderColor, required Color bgColor,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 2),
              Text(body,
                  style: const TextStyle(fontSize: 11, color: _grey, height: 1.4)),
            ]),
          ),
        ]),
      );
}
