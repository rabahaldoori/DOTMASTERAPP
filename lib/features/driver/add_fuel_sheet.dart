import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';

const _navy  = Color(0xFF031634);
const _blue  = Color(0xFF0453CD);
const _sky   = Color(0xFF3B82F6);
const _green = Color(0xFF16A34A);
const _bg    = Color(0xFFF4F6FB);

class AddFuelSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const AddFuelSheet({super.key, required this.onSaved});
  @override
  State<AddFuelSheet> createState() => _AddFuelSheetState();
}

class _AddFuelSheetState extends State<AddFuelSheet> {
  final _form    = GlobalKey<FormState>();
  final _vendor  = TextEditingController();
  final _gallons = TextEditingController();
  final _ppg     = TextEditingController();
  final _odo     = TextEditingController();
  final _rcptNo  = TextEditingController();

  String   _fuelType = 'diesel';
  String   _payment  = 'fleet_card';
  DateTime _date     = DateTime.now();
  File?    _receipt;
  bool     _saving     = false;
  bool     _gpsLoading = false;
  double?  _lat, _lng;
  String?  _address; // human-readable reverse geocoded address
  List<Map> _trucks = [];
  int?      _truckId;

  @override
  void initState() { super.initState(); _fetchTrucks(); _getGPS(); }

  @override
  void dispose() {
    _vendor.dispose(); _gallons.dispose();
    _ppg.dispose(); _odo.dispose(); _rcptNo.dispose();
    super.dispose();
  }

  Future<void> _fetchTrucks() async {
    try {
      final r    = await ApiClient.getDriverData();
      final data = r.data as Map;
      final active = data['active_truck'];
      if (active != null && active is Map) {
        setState(() { _trucks = [active]; _truckId = active['id'] as int?; });
        return;
      }
      final trips = data['trips'] as List? ?? [];
      if (trips.isNotEmpty) {
        final t = trips.first as Map;
        final id = t['truck__id']; final unit = t['truck__unit_number'];
        if (id != null) {
          setState(() {
            _trucks  = [{'id': id, 'unit_number': unit ?? 'Truck'}];
            _truckId = id is int ? id : int.tryParse(id.toString());
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _getGPS() async {
    setState(() => _gpsLoading = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() { _lat = pos.latitude; _lng = pos.longitude; });

      // ── Reverse geocode for Location row (non-fatal) ───────────────────
      _reverseGeocodeIntoVendor(pos.latitude, pos.longitude);
    } catch (_) {} finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  /// Gets GPS fix + reverse geocodes, then fills the Vendor/Station field
  /// with the street address of the current location (the gas station).
  Future<void> _fillVendorFromGps() async {
    // If we already have coords, just reverse-geocode them into the vendor field
    if (_lat != null && _lng != null) {
      await _reverseGeocodeIntoVendor(_lat!, _lng!);
      return;
    }
    // Otherwise get location first
    setState(() => _gpsLoading = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() { _lat = pos.latitude; _lng = pos.longitude; });
      await _reverseGeocodeIntoVendor(pos.latitude, pos.longitude);
    } catch (_) {} finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _reverseGeocodeIntoVendor(double lat, double lng) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'User-Agent': 'IFTAtrack/1.0 (fuel-log)'},
      ));
      final res = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat.toStringAsFixed(6),
          'lon': lng.toStringAsFixed(6),
          'format': 'json',
          'addressdetails': 1,
        },
      );
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>? ?? {};

      // Build station-friendly label: shop/amenity name + road + city + state
      final name   = (data['name'] as String?)?.trim() ?? '';
      final road   = (addr['road'] as String?)?.trim() ?? '';
      final city   = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? '') as String;
      final state  = (addr['state'] as String?)?.trim() ?? '';

      final parts = <String>[
        if (name.isNotEmpty) name,
        if (road.isNotEmpty && road != name) road,
        if (city.toString().isNotEmpty) city.toString().trim(),
        if (state.isNotEmpty) state,
      ];
      final fullAddr = parts.where((s) => s.isNotEmpty).join(', ');

      if (fullAddr.isNotEmpty) {
        setState(() => _address = fullAddr);
        if (_vendor.text.trim().isEmpty) {
          _vendor.text = fullAddr;
        }
      }
    } on DioException catch (e) {
      debugPrint('Nominatim error: ${e.message}');
    } catch (e) {
      debugPrint('Geocode error: $e');
    }
  }


  Future<void> _pickReceipt() async {

    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(bottom: 8), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.camera_alt_outlined, color: _blue, size: 18)),
            title: Text('Take Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(
            leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _sky.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.photo_library_outlined, color: _sky, size: 18)),
            title: Text('Choose from Gallery',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      )),
    );
    if (src == null) return;
    final picked = await ImagePicker().pickImage(source: src, imageQuality: 80);
    if (picked != null && mounted) setState(() => _receipt = File(picked.path));
  }

  double get _total {
    final g = double.tryParse(_gallons.text) ?? 0;
    final p = double.tryParse(_ppg.text) ?? 0;
    return g * p;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_truckId == null) { _err('No truck assigned to your account.'); return; }
    setState(() => _saving = true);
    try {
      final res = await ApiClient.logFuelFromDevice({
        'truck_id':         _truckId,
        'purchase_date':    _date.toIso8601String().substring(0, 10),
        'gallons':          double.parse(_gallons.text),
        'price_per_gallon': double.parse(_ppg.text),
        'fuel_type':        _fuelType,
        'vendor_name':      _vendor.text.trim(),
        'vendor_address':   _address ?? '',
        'payment_method':   _payment,
        'receipt_number':   _rcptNo.text.trim(),
        if (_odo.text.isNotEmpty) 'odometer': int.tryParse(_odo.text),
        if (_lat != null) 'lat': _lat,
        if (_lng != null) 'lng': _lng,
      });

      final newId = res.data['id'] as int?;
      if (_receipt != null && newId != null) {
        try { await ApiClient.uploadFuelReceipt(newId, _receipt!.path); } catch (_) {}
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        HapticFeedback.lightImpact();
      }
    } catch (_) {
      _err('Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _err(String msg) {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Oops!', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      content: Text(msg, style: GoogleFonts.inter()),
      actions: [TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('OK', style: GoogleFonts.inter(color: _blue, fontWeight: FontWeight.w700)))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasTotal = _total > 0;
    return Scaffold(
      backgroundColor: _bg,
      // ── Pinned Save button ─────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                disabledBackgroundColor: _navy.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: _saving
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Icon(Icons.save_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text('Save Fuel Log', style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 0.3)),
                    ]),
            ),
          ),
        ),
      ),
      // ── AppBar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Log Fuel Stop', style: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        actions: [
          GestureDetector(
            onTap: _gpsLoading ? null : _getGPS,
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (_lat != null ? _green : Colors.orange).withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: (_lat != null ? _green : Colors.orange).withOpacity(0.5)),
              ),
              child: _gpsLoading
                  ? const SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.gps_fixed_rounded, size: 12,
                        color: _lat != null ? _green : Colors.orange),
                      const SizedBox(width: 4),
                      Text(_lat != null ? 'GPS ✓' : 'No GPS',
                        style: GoogleFonts.inter(fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _lat != null ? _green : Colors.orange)),
                    ]),
            ),
          ),
        ],
      ),
      // ── Body ────────────────────────────────────────────────────────────
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 90),
          children: [

            // Total banner
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasTotal
                      ? [const Color(0xFF16A34A), const Color(0xFF22C55E)]
                      : [_navy, const Color(0xFF0A2347)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                  color: (hasTotal ? _green : _navy).withOpacity(0.30),
                  blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.local_gas_station_rounded,
                    color: Colors.white, size: 26)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Amount', style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white60,
                    fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(hasTotal ? '\$${_total.toStringAsFixed(2)}'
                      : '\$ Auto-calculated',
                    style: GoogleFonts.inter(fontSize: 26,
                      fontWeight: FontWeight.w900, color: Colors.white)),
                  if (hasTotal)
                    Text('${_gallons.text} gal × \$${_ppg.text}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.white60)),
                ])),
              ]),
            ),

            const SizedBox(height: 24),

            // Section: Trip Info
            _SectionHeader(icon: Icons.calendar_today_rounded, label: 'Trip Info'),
            const SizedBox(height: 10),
            _Card(children: [
              _CardRow(
                icon: Icons.event_rounded, iconColor: _blue,
                label: 'Purchase Date',
                trailing: Text(
                  '${_date.month}/${_date.day}/${_date.year}',
                  style: GoogleFonts.inter(fontSize: 14,
                    fontWeight: FontWeight.w600, color: _navy)),
                onTap: () async {
                  final d = await showDatePicker(context: context,
                    initialDate: _date, firstDate: DateTime(2020),
                    lastDate: DateTime.now());
                  if (d != null) setState(() => _date = d);
                },
              ),
              const _CDivider(),
              _CardRow(
                icon: Icons.local_shipping_rounded, iconColor: _blue,
                label: 'Truck',
                trailing: Text(
                  _trucks.isEmpty ? 'No truck assigned'
                      : _trucks.first['unit_number']?.toString() ?? 'Truck',
                  style: GoogleFonts.inter(fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _trucks.isEmpty ? Colors.grey : _navy)),
                onTap: null,
              ),
              const _CDivider(),
              _CardRow(
                icon: Icons.location_on_rounded,
                iconColor: _lat != null ? _green : Colors.orange,
                label: 'Location',
                trailing: _gpsLoading
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2,
                              color: Color(0xFF0453CD))),
                        const SizedBox(width: 6),
                        Text('Locating...', style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey)),
                      ])
                    : Flexible(child: Text(
                        _address ?? (_lat != null
                            ? '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'
                            : 'Tap to get location'),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _lat != null ? _green : Colors.orange))),
                onTap: _gpsLoading ? null : _getGPS,
              ),
            ]),

            const SizedBox(height: 20),

            // Section: Fuel Details
            _SectionHeader(icon: Icons.water_drop_rounded, label: 'Fuel Details'),
            const SizedBox(height: 10),
            _Card(children: [
              _InlineField(
                icon: Icons.storefront_rounded, iconColor: _blue,
                label: 'Vendor / Station',
                ctrl: _vendor, hint: 'e.g. Pilot #402',
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                suffix: GestureDetector(
                  onTap: _fillVendorFromGps,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (_lat != null ? _green : Colors.orange).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _gpsLoading
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF0453CD)))
                        : Icon(Icons.my_location_rounded, size: 16,
                            color: _lat != null ? _green : Colors.orange),
                  ),
                ),
              ),
              const _CDivider(),
              Row(children: [
                Expanded(child: _InlineField(
                  icon: Icons.water_drop_outlined, iconColor: _sky,
                  label: 'Gallons', ctrl: _gallons, hint: '120.5',
                  type: TextInputType.number, compact: true,
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? '!' : null,
                  onChanged: (_) => setState(() {}),
                )),
                Container(width: 1, height: 56,
                    color: const Color(0xFFEEF0F5)),
                Expanded(child: _InlineField(
                  icon: Icons.attach_money_rounded, iconColor: _sky,
                  label: 'Price / Gal', ctrl: _ppg, hint: '3.859',
                  type: TextInputType.number, compact: true,
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? '!' : null,
                  onChanged: (_) => setState(() {}),
                )),
              ]),
              const _CDivider(),
              _DropRow<String>(
                icon: Icons.local_gas_station_outlined, iconColor: _blue,
                label: 'Fuel Type', value: _fuelType,
                items: const {
                  'diesel': 'Diesel', 'gasoline': 'Gasoline',
                  'lng': 'LNG', 'cng': 'CNG', 'reefer': 'Reefer Diesel',
                },
                onChanged: (v) => setState(() => _fuelType = v!),
              ),
            ]),

            const SizedBox(height: 20),

            // Section: Payment
            _SectionHeader(icon: Icons.credit_card_rounded, label: 'Payment'),
            const SizedBox(height: 10),
            _Card(children: [
              _DropRow<String>(
                icon: Icons.credit_card_outlined, iconColor: _blue,
                label: 'Payment Method', value: _payment,
                items: const {
                  'fleet_card': 'Fleet Card', 'cash': 'Cash',
                  'card': 'Credit/Debit', 'check': 'Check', 'other': 'Other',
                },
                onChanged: (v) => setState(() => _payment = v!),
              ),
              const _CDivider(),
              Row(children: [
                Expanded(child: _InlineField(
                  icon: Icons.speed_rounded, iconColor: _sky,
                  label: 'Odometer', ctrl: _odo, hint: '145200',
                  type: TextInputType.number, compact: true,
                )),
                Container(width: 1, height: 56,
                    color: const Color(0xFFEEF0F5)),
                Expanded(child: _InlineField(
                  icon: Icons.receipt_long_rounded, iconColor: _sky,
                  label: 'Receipt #', ctrl: _rcptNo,
                  hint: 'TXN-001', compact: true,
                )),
              ]),
            ]),

            const SizedBox(height: 20),

            // Section: Receipt
            _SectionHeader(icon: Icons.photo_camera_rounded, label: 'Receipt'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickReceipt,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 90,
                decoration: BoxDecoration(
                  color: _receipt != null
                      ? _green.withOpacity(0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _receipt != null
                        ? _green.withOpacity(0.4)
                        : const Color(0xFFE2E8F0)),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: _receipt != null
                    ? Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        ClipRRect(borderRadius: BorderRadius.circular(10),
                          child: Image.file(_receipt!,
                              width: 64, height: 64, fit: BoxFit.cover)),
                        const SizedBox(width: 14),
                        Column(mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Text('Receipt attached', style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: _green)),
                          const SizedBox(height: 2),
                          Text('Tap to change', style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.grey)),
                        ]),
                      ])
                    : Column(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Icon(Icons.cloud_upload_outlined,
                            size: 28, color: Colors.grey.shade400),
                        const SizedBox(height: 6),
                        Text('Tap to upload receipt (JPG, PNG, PDF)',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey.shade500)),
                      ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon; final String label;
  const _SectionHeader({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 28, height: 28,
      decoration: BoxDecoration(
        color: _blue.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 15, color: _blue)),
    const SizedBox(width: 8),
    Text(label, style: GoogleFonts.inter(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: const Color(0xFF64748B), letterSpacing: 0.4)),
  ]);
}

// ── Card container ────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 12, offset: const Offset(0, 3))],
    ),
    child: Column(children: children),
  );
}

// ── Tap row ───────────────────────────────────────────────────────────────────
class _CardRow extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String label; final Widget trailing; final VoidCallback? onTap;
  const _CardRow({required this.icon, required this.iconColor,
    required this.label, required this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 16, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500,
          color: const Color(0xFF64748B)))),
        trailing,
        if (onTap != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 18,
              color: Colors.grey.shade400)],
      ]),
    ),
  );
}

// ── Inline text field ─────────────────────────────────────────────────────────
class _InlineField extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String label; final TextEditingController ctrl; final String hint;
  final TextInputType type; final bool compact;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? suffix;
  const _InlineField({required this.icon, required this.iconColor,
    required this.label, required this.ctrl, required this.hint,
    this.type = TextInputType.text, this.compact = false,
    this.validator, this.onChanged, this.suffix});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16, vertical: compact ? 10 : 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(width: 30, height: 30,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: iconColor)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11,
          fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
        TextFormField(
          controller: ctrl, keyboardType: type,
          validator: validator, onChanged: onChanged,
          style: GoogleFonts.inter(fontSize: 14,
            fontWeight: FontWeight.w600, color: _navy),
          decoration: InputDecoration(
            hintText: hint, isDense: true,
            contentPadding: const EdgeInsets.only(top: 4),
            hintStyle: GoogleFonts.inter(fontSize: 13,
              color: const Color(0xFFCBD5E1)),
            border: InputBorder.none, focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none, errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
        ),
      ])),
      if (suffix != null) ...[const SizedBox(width: 6), suffix!],
    ]),
  );
}

// ── Dropdown row ──────────────────────────────────────────────────────────────
class _DropRow<T> extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String label; final T value;
  final Map<T, String> items; final void Function(T?) onChanged;
  const _DropRow({required this.icon, required this.iconColor,
    required this.label, required this.value,
    required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 16, color: iconColor)),
      const SizedBox(width: 12),
      Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<T>(
        value: value, isExpanded: true,
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            color: Colors.grey.shade400),
        items: items.entries.map((e) => DropdownMenuItem(
          value: e.key,
          child: Text(e.value, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
        )).toList(),
        onChanged: onChanged,
      ))),
    ]),
  );
}

// ── Thin card divider ─────────────────────────────────────────────────────────
class _CDivider extends StatelessWidget {
  const _CDivider();
  @override
  Widget build(BuildContext context) => Container(
    height: 1, margin: const EdgeInsets.symmetric(horizontal: 16),
    color: const Color(0xFFF1F5F9));
}
