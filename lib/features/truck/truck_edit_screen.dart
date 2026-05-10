import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/font_ext.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _navy = Color(0xFF031634);
const _navy2 = Color(0xFF0D2952);
const _blue = Color(0xFF0453CD);
const _teal = Color(0xFF0891B2);
const _red  = Color(0xFFDC2626);
const _green = Color(0xFF16A34A);
const _surf = Color(0xFFF0F3FA);
const _bord = Color(0xFFDCE2F3);
const _grey = Color(0xFF64748B);

class TruckEditScreen extends StatefulWidget {
  /// Pass null for a new truck, or an existing map to edit.
  final Map? existing;
  const TruckEditScreen({super.key, this.existing});

  @override
  State<TruckEditScreen> createState() => _TruckEditScreenState();
}

class _TruckEditScreenState extends State<TruckEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _unit, _year, _make, _model,
      _vin, _plate, _state, _odo, _notes;
  String _fuelType = 'diesel';
  String _status   = 'active';
  bool   _saving   = false;
  bool   _decodingVin = false;
  bool   _vinDecoded  = false;

  static const _fuels    = ['diesel','gasoline','lng','cng','diesel_reefer'];
  static const _statuses = ['active','maintenance','inactive','retired'];

  // NHTSA fuel type mapping
  static const _nhtsaFuelMap = {
    'gasoline':      'gasoline',
    'gas':           'gasoline',
    'diesel':        'diesel',
    'natural gas':   'cng',
    'compressed natural gas': 'cng',
    'liquefied natural gas':  'lng',
    'electric':      'gasoline', // fallback
    'flex':          'gasoline',
  };

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _unit  = TextEditingController(text: e?['unit_number']       ?? '');
    _year  = TextEditingController(text: e?['year']?.toString()  ?? '');
    _make  = TextEditingController(text: e?['make']              ?? '');
    _model = TextEditingController(text: e?['model']             ?? '');
    _vin   = TextEditingController(text: e?['vin']               ?? '');
    _plate = TextEditingController(text: e?['license_plate']     ?? '');
    _state = TextEditingController(text: e?['license_state']     ?? '');
    _odo   = TextEditingController(text: e?['odometer_reading']?.toString() ?? '');
    _notes = TextEditingController(text: e?['notes']             ?? '');
    _fuelType = e?['fuel_type'] ?? 'diesel';
    _status   = e?['status']   ?? 'active';
  }

  @override
  void dispose() {
    for (final c in [_unit,_year,_make,_model,_vin,_plate,_state,_odo,_notes]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── NHTSA VIN Decoder ─────────────────────────────────────────────────────
  Future<void> _decodeVin() async {
    final vin = _vin.text.trim().toUpperCase();
    if (vin.length != 17) {
      _showSnack('VIN must be exactly 17 characters', isError: true);
      return;
    }

    setState(() => _decodingVin = true);
    try {
      final uri = Uri.parse(
          'https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/$vin?format=json');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('NHTSA API error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['Results'] as List?;
      if (results == null || results.isEmpty) throw Exception('No results');

      final v = results[0] as Map<String, dynamic>;

      final make      = (v['Make']        ?? '').toString().trim();
      final model     = (v['Model']       ?? '').toString().trim();
      final year      = (v['ModelYear']   ?? '').toString().trim();
      final fuelRaw   = (v['FuelTypePrimary'] ?? '').toString().toLowerCase().trim();
      final errorCode = (v['ErrorCode']   ?? '').toString();

      // ErrorCode "0" = success, "1" = valid VIN with minor issues
      if (errorCode != '0' && errorCode != '1' && make.isEmpty) {
        throw Exception('Could not decode this VIN');
      }

      // Map NHTSA fuel type to our internal values
      String mappedFuel = 'diesel';
      for (final entry in _nhtsaFuelMap.entries) {
        if (fuelRaw.contains(entry.key)) {
          mappedFuel = entry.value;
          break;
        }
      }

      setState(() {
        if (make.isNotEmpty)  _make.text  = make;
        if (model.isNotEmpty) _model.text = model;
        if (year.isNotEmpty)  _year.text  = year;
        _fuelType   = mappedFuel;
        _vinDecoded = true;
      });

      _showSnack('✓ VIN decoded: $year $make $model', isError: false);
    } catch (e) {
      _showSnack('Could not decode VIN. Check the number and try again.',
          isError: true);
    } finally {
      if (mounted) setState(() => _decodingVin = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: context.af(fontSize: 13)),
      backgroundColor: isError ? _red : _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: Duration(seconds: isError ? 4 : 3),
    ));
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'unit_number':    _unit.text.trim(),
      'year':           int.tryParse(_year.text.trim()) ?? 0,
      'make':           _make.text.trim(),
      'model':          _model.text.trim(),
      'vin':            _vin.text.trim(),
      'license_plate':  _plate.text.trim(),
      'license_state':  _state.text.trim().toUpperCase(),
      'fuel_type':      _fuelType,
      'status':         _status,
      if (_odo.text.trim().isNotEmpty)
        'odometer_reading': double.tryParse(_odo.text.trim()),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
    };
    try {
      if (_isEdit) {
        await ApiClient.updateTruck(widget.existing!['id'] as int, payload);
      } else {
        await ApiClient.createTruck(payload);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final s = context.read<LocaleProvider>().s;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.saveFailed, style: context.af()),
        backgroundColor: _red,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;

    final fuelDisplay = {
      'diesel':       'Diesel',
      'gasoline':     'Gasoline',
      'lng':          'LNG',
      'cng':          'CNG',
      'diesel_reefer':'Diesel Reefer',
    };
    final statusDisplay = {
      'active':      s.statusActive,
      'maintenance': s.statusMaintenance,
      'inactive':    s.statusInactive,
      'retired':     s.statusRetired,
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _surf,
        body: CustomScrollView(slivers: [
          // ── Header ────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context, false),
            ),
            title: Text(
              _isEdit ? s.editTruck : s.addNewTruck,
              style: context.af(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : TextButton(
                        onPressed: _save,
                        style: TextButton.styleFrom(
                          backgroundColor: _blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(s.save, style: context.af(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, _navy2]),
                ),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(
                        _isEdit ? s.updateTruckInfo : s.registerNewTruck,
                        style: context.af(fontSize: 12, color: Colors.white60),
                      ),
                      if (_isEdit)
                        Text(
                          '${widget.existing?['year'] ?? ''} '
                          '${widget.existing?['make'] ?? ''} '
                          '${widget.existing?['model'] ?? ''}',
                          style: context.af(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                    ]),
                  ]),
                )),
              ),
            ),
          ),

          // ── Form ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + 80 + MediaQuery.of(context).padding.bottom),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── VIN Smart Decoder ──────────────────────────────────────
                _VinSection(
                  vinCtrl: _vin,
                  decoding: _decodingVin,
                  decoded: _vinDecoded,
                  onDecode: _decodeVin,
                  onChanged: (_) => setState(() => _vinDecoded = false),
                ),

                const SizedBox(height: 16),

                // ── Auto-filled fields (greyed when decoded) ───────────────
                _Section(title: s.vehicleIdentity, children: [
                  Row(children: [
                    Expanded(child: _Field(ctrl: _unit, label: s.unitNumber,
                        hint: 'TRK-001', required: true, requiredMsg: s.requiredField)),
                    const SizedBox(width: 12),
                    Expanded(child: _Field(ctrl: _year, label: s.year,
                        hint: '2023', keyboardType: TextInputType.number,
                        required: true, requiredMsg: s.requiredField,
                        autoFilled: _vinDecoded)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _Field(ctrl: _make, label: s.make,
                        hint: 'Mack', required: true, requiredMsg: s.requiredField,
                        autoFilled: _vinDecoded)),
                    const SizedBox(width: 12),
                    Expanded(child: _Field(ctrl: _model, label: s.model,
                        hint: 'Anthem', required: true, requiredMsg: s.requiredField,
                        autoFilled: _vinDecoded)),
                  ]),
                ]),

                const SizedBox(height: 20),

                _Section(title: s.registration, children: [
                  Row(children: [
                    Expanded(child: _Field(ctrl: _plate, label: s.licensePlate,
                        hint: 'TX-8802', required: true, requiredMsg: s.requiredField)),
                    const SizedBox(width: 12),
                    SizedBox(width: 80, child: _Field(ctrl: _state, label: s.licenseState,
                        hint: 'TX', maxLength: 2, required: true, requiredMsg: s.requiredField)),
                  ]),
                ]),

                const SizedBox(height: 20),

                _Section(title: s.fuelAndStatus, children: [
                  _DropField(
                    label: s.fuelType,
                    value: _fuelType,
                    items: _fuels,
                    display: (v) => fuelDisplay[v] ?? v.replaceAll('_', ' ').toUpperCase(),
                    onChanged: (v) => setState(() => _fuelType = v!),
                  ),
                  const SizedBox(height: 12),
                  _DropField(
                    label: s.status,
                    value: _status,
                    items: _statuses,
                    display: (v) => statusDisplay[v] ?? '${v[0].toUpperCase()}${v.substring(1)}',
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ]),

                const SizedBox(height: 20),

                _Section(title: s.additionalInfo, children: [
                  _Field(ctrl: _odo, label: s.odometerMi, hint: '0',
                      keyboardType: TextInputType.number, requiredMsg: s.requiredField),
                  const SizedBox(height: 12),
                  _Field(ctrl: _notes, label: s.notesOptional,
                      hint: '…', maxLines: 3, requiredMsg: s.requiredField),
                ]),

              ]),
            ),
          )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIN Smart Decoder Card
// ─────────────────────────────────────────────────────────────────────────────
class _VinSection extends StatelessWidget {
  final TextEditingController vinCtrl;
  final bool decoding;
  final bool decoded;
  final VoidCallback onDecode;
  final ValueChanged<String> onChanged;

  const _VinSection({
    required this.vinCtrl,
    required this.decoding,
    required this.decoded,
    required this.onDecode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final vinLen = vinCtrl.text.trim().length;
    final canDecode = vinLen == 17;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: decoded ? _green.withOpacity(0.5) : _bord,
          width: decoded ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: decoded ? _green.withOpacity(0.1) : _teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              decoded ? Icons.verified_rounded : Icons.qr_code_scanner_rounded,
              size: 16,
              color: decoded ? _green : _teal,
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('VIN Decoder',
                style: context.af(fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
            Text(
              decoded
                  ? 'Vehicle data auto-filled ✓'
                  : 'Enter VIN to auto-fill make, model & year',
              style: context.af(fontSize: 10, color: _grey),
            ),
          ]),
        ]),

        const SizedBox(height: 14),

        // VIN input — full width
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('VIN Number',
              style: context.af(fontSize: 11, fontWeight: FontWeight.w700, color: _grey)),
          const SizedBox(height: 6),
          TextFormField(
            controller: vinCtrl,
            maxLength: 17,
            textCapitalization: TextCapitalization.characters,
            onChanged: onChanged,
            style: context.af(fontSize: 14, color: _navy, fontWeight: FontWeight.w600,
                letterSpacing: 1.8),
            decoration: InputDecoration(
              hintText: '1M2AX12C5PN123456',
              hintStyle: context.af(fontSize: 13, color: _grey.withOpacity(0.4), letterSpacing: 0),
              counterText: '${vinCtrl.text.trim().length}/17',
              counterStyle: context.af(
                  fontSize: 10,
                  color: canDecode ? _teal : _grey,
                  fontWeight: canDecode ? FontWeight.w700 : FontWeight.w400),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              filled: true,
              fillColor: decoded ? _green.withOpacity(0.04) : _surf,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _bord)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: decoded ? _green.withOpacity(0.4) : _bord)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _teal, width: 1.8)),
              suffixIcon: decoded
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.check_circle_rounded, color: _green, size: 22))
                  : null,
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Full-width Decode VIN button
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: canDecode && !decoded
                ? const LinearGradient(
                    colors: [Color(0xFF0891B2), Color(0xFF0453CD)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : decoded
                    ? LinearGradient(colors: [_green.withOpacity(0.85), const Color(0xFF059669)])
                    : LinearGradient(colors: [_grey.withOpacity(0.12), _grey.withOpacity(0.12)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: canDecode && !decoded
                ? [BoxShadow(color: _teal.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]
                : decoded
                    ? [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))]
                    : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: canDecode && !decoding && !decoded ? onDecode : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: decoding
                    ? const Center(
                        child: SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(
                          decoded ? Icons.verified_rounded : Icons.document_scanner_rounded,
                          color: canDecode || decoded ? Colors.white : _grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          decoded ? 'Vehicle Decoded Successfully' : 'Decode VIN',
                          style: context.af(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: canDecode || decoded ? Colors.white : _grey,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _bord),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: context.af(fontSize: 10, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.8)),
      const SizedBox(height: 14),
      ...children,
    ]),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final String requiredMsg;
  final bool required;
  final bool autoFilled;
  final int? maxLength, maxLines;
  final TextInputType? keyboardType;
  const _Field({
    required this.ctrl, required this.label, required this.hint,
    required this.requiredMsg,
    this.required = false, this.maxLength, this.maxLines = 1,
    this.keyboardType, this.autoFilled = false,
  });

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: context.af(fontSize: 11, fontWeight: FontWeight.w700, color: _grey)),
          if (autoFilled) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Auto', style: context.af(fontSize: 8, fontWeight: FontWeight.w700, color: _green)),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLength: maxLength,
          maxLines: maxLines,
          style: context.af(fontSize: 14, color: _navy, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.af(fontSize: 13, color: _grey.withOpacity(0.5)),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            filled: true,
            fillColor: autoFilled ? _green.withOpacity(0.04) : _surf,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _bord)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: autoFilled ? _green.withOpacity(0.4) : _bord)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _red)),
            suffixIcon: autoFilled
                ? const Padding(padding: EdgeInsets.all(12),
                    child: Icon(Icons.auto_awesome_rounded, size: 16, color: _green))
                : null,
          ),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? requiredMsg : null
              : null,
        ),
      ]);
}

class _DropField extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final String Function(String) display;
  final ValueChanged<String?> onChanged;
  const _DropField({
    required this.label, required this.value, required this.items,
    required this.display, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.af(fontSize: 11, fontWeight: FontWeight.w700, color: _grey)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          style: context.af(fontSize: 14, color: _navy, fontWeight: FontWeight.w600),
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            filled: true, fillColor: _surf,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _bord)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _bord)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 1.5)),
          ),
          items: items
              .map((v) => DropdownMenuItem(value: v, child: Text(display(v))))
              .toList(),
          onChanged: onChanged,
        ),
      ]);
}
