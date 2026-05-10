import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/font_ext.dart';

const _navy = Color(0xFF031634);
const _navy2 = Color(0xFF0D2952);
const _blue = Color(0xFF0453CD);
const _red  = Color(0xFFDC2626);
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

  static const _fuels    = ['diesel','gasoline','lng','cng','diesel_reefer'];
  static const _statuses = ['active','maintenance','inactive','retired'];

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

    // localized fuel & status display maps
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

    return Scaffold(
      backgroundColor: _surf,
      body: CustomScrollView(slivers: [
        // ── Header ──────────────────────────────────────────────────────────
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

        // ── Form ────────────────────────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + 80 + MediaQuery.of(context).padding.bottom),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              _Section(title: s.vehicleIdentity, children: [
                Row(children: [
                  Expanded(child: _Field(ctrl: _unit, label: s.unitNumber,
                      hint: 'TRK-001', required: true, requiredMsg: s.requiredField)),
                  const SizedBox(width: 12),
                  Expanded(child: _Field(ctrl: _year, label: s.year,
                      hint: '2023', keyboardType: TextInputType.number,
                      required: true, requiredMsg: s.requiredField)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _Field(ctrl: _make, label: s.make,
                      hint: 'Mack', required: true, requiredMsg: s.requiredField)),
                  const SizedBox(width: 12),
                  Expanded(child: _Field(ctrl: _model, label: s.model,
                      hint: 'Anthem', required: true, requiredMsg: s.requiredField)),
                ]),
                const SizedBox(height: 12),
                _Field(ctrl: _vin, label: s.vinLabel, hint: '1M2AX12C5PN123456', maxLength: 17,
                    requiredMsg: s.requiredField),
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
  final int? maxLength, maxLines;
  final TextInputType? keyboardType;
  const _Field({
    required this.ctrl, required this.label, required this.hint,
    required this.requiredMsg,
    this.required = false, this.maxLength, this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.af(fontSize: 11, fontWeight: FontWeight.w700, color: _grey)),
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
            filled: true, fillColor: _surf,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _bord)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _bord)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _red)),
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
