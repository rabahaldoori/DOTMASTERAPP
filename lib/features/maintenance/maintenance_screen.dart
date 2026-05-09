import 'package:flutter/material.dart';
import '../../core/api_client.dart';

// ── API helpers ───────────────────────────────────────────────────────────────
Future<List> _fetchRecords() async {
  final res = await ApiClient.dio.get('/api/maintenance/mobile/');
  final d = res.data;
  return d is List ? d : (d['results'] ?? []);
}

Future<List> _fetchTrucks() async {
  final res = await ApiClient.dio.get('/api/maintenance/trucks/');
  return res.data is List ? res.data : [];
}

Future<void> _saveRecord(Map payload, int? id) async {
  if (id != null) {
    await ApiClient.dio.patch('/api/maintenance/mobile/$id/', data: payload);
  } else {
    await ApiClient.dio.post('/api/maintenance/mobile/', data: payload);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});
  @override State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  List _records = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final data = await _fetchRecords(); setState(() => _records = data); }
    catch (e) { setState(() => _error = e.toString()); }
    finally { setState(() => _loading = false); }
  }

  Color _pri(String? p) => switch(p) { 'critical'=>Colors.red, 'high'=>Colors.orange, 'medium'=>Colors.amber, _=>Colors.green };
  Color _sts(String? s) => switch(s) { 'completed'=>Colors.green, 'in_progress'=>Colors.blue, 'cancelled'=>Colors.grey, _=>const Color(0xFF64748B) };

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F4F6),
    appBar: AppBar(
      title: const Text('Maintenance Records', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      backgroundColor: const Color(0xFF031634), foregroundColor: Colors.white, elevation: 0,
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _openForm(null)),
      ],
    ),
    body: _loading ? const Center(child: CircularProgressIndicator())
        : _error != null ? _buildError()
        : _records.isEmpty ? _buildEmpty()
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length,
              itemBuilder: (_, i) {
                final r = _records[i];
                return _RecordCard(record: r, priColor: _pri(r['priority']), stsColor: _sts(r['status']),
                  onTap: () => _openDetail(r));
              },
            ),
          ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _openForm(null),
      backgroundColor: const Color(0xFF031634), foregroundColor: Colors.white,
      icon: const Icon(Icons.add), label: const Text('Add Record'),
    ),
  );

  Widget _buildError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12),
    const Text('Failed to load', style: TextStyle(fontSize: 16)), const SizedBox(height: 8),
    ElevatedButton(onPressed: _load, child: const Text('Retry')),
  ]));

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.build_outlined, size: 64, color: Color(0xFFCBD5E1)), const SizedBox(height: 16),
    const Text('No maintenance records', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)), const SizedBox(height: 12),
    ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Record'),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF031634), foregroundColor: Colors.white),
      onPressed: () => _openForm(null)),
  ]));

  void _openDetail(Map r) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
      builder: (_, sc) => _DetailSheet(record: r, scrollController: sc, onEdit: () { Navigator.pop(context); _openForm(r); })),
  );

  void _openForm(Map? r) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(_).viewInsets.bottom),
      child: _MaintenanceForm(record: r, onSaved: () { Navigator.pop(context); _load(); }),
    ),
  );
}

// ── Card ──────────────────────────────────────────────────────────────────────
class _RecordCard extends StatelessWidget {
  final Map record; final Color priColor, stsColor; final VoidCallback onTap;
  const _RecordCard({required this.record, required this.priColor, required this.stsColor, required this.onTap});
  @override Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12), elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 4, height: 40, decoration: BoxDecoration(color: priColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(record['title'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B))),
          Text(record['truck_unit'] ?? '—', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: stsColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(record['status_display'] ?? record['status'] ?? '—', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: stsColor))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Icon(Icons.build_outlined, size: 13, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(record['maintenance_type_display'] ?? '—', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(width: 12),
        Icon(Icons.calendar_today_outlined, size: 13, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(record['date_performed'] ?? 'No date', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const Spacer(),
        if (record['cost'] != null) Text('\$${double.tryParse(record['cost'].toString())?.toStringAsFixed(2) ?? record['cost']}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF031634))),
      ]),
    ]))),
  );
}

// ── Detail sheet ──────────────────────────────────────────────────────────────
class _DetailSheet extends StatelessWidget {
  final Map record; final ScrollController scrollController; final VoidCallback onEdit;
  const _DetailSheet({required this.record, required this.scrollController, required this.onEdit});
  Widget _row(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 160, child: Text(l, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600))),
      Expanded(child: Text(v, style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.w500))),
    ]));
  @override Widget build(BuildContext context) => Column(children: [
    Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
      Expanded(child: Text(record['title'] ?? 'Detail', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF031634)))),
      IconButton(icon: const Icon(Icons.edit_outlined), color: const Color(0xFF031634), onPressed: onEdit),
    ])),
    const Divider(),
    Expanded(child: ListView(controller: scrollController, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), children: [
      _row('Truck', record['truck_label'] ?? record['truck_unit'] ?? '—'),
      _row('Type', record['maintenance_type_display'] ?? '—'),
      _row('Priority', record['priority_display'] ?? record['priority'] ?? '—'),
      _row('Status', record['status_display'] ?? record['status'] ?? '—'),
      _row('Date Performed', record['date_performed'] ?? '—'),
      _row('Odometer', record['mileage_at_service'] != null ? '${record['mileage_at_service']} mi' : '—'),
      _row('Cost', record['cost'] != null ? '\$${double.tryParse(record['cost'].toString())?.toStringAsFixed(2)}' : '—'),
      _row('Vendor', record['vendor_name']?.isNotEmpty == true ? record['vendor_name'] : '—'),
      _row('Next Service Date', record['next_service_date'] ?? '—'),
      _row('Submitted By', record['submitted_by_name'] ?? '—'),
      if ((record['description'] ?? '').isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text('Description', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(record['description'], style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B))),
      ],
    ])),
  ]);
}

// ── Form sheet ────────────────────────────────────────────────────────────────
class _MaintenanceForm extends StatefulWidget {
  final Map? record; final VoidCallback onSaved;
  const _MaintenanceForm({this.record, required this.onSaved});
  @override State<_MaintenanceForm> createState() => _MaintenanceFormState();
}

class _MaintenanceFormState extends State<_MaintenanceForm> {
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _costCtrl   = TextEditingController();
  final _mileCtrl   = TextEditingController();
  final _vendorCtrl = TextEditingController();
  String _type = 'oil_change', _priority = 'medium', _status = 'pending';
  String? _truckId, _date;
  List _trucks = [];
  bool _saving = false; String? _error;

  @override void initState() {
    super.initState();
    _fetchTrucks().then((t) => setState(() => _trucks = t));
    final r = widget.record;
    if (r != null) {
      _titleCtrl.text = r['title'] ?? ''; _descCtrl.text = r['description'] ?? '';
      _costCtrl.text = r['cost']?.toString() ?? ''; _mileCtrl.text = r['mileage_at_service']?.toString() ?? '';
      _vendorCtrl.text = r['vendor_name'] ?? '';
      _type = r['maintenance_type'] ?? 'oil_change'; _priority = r['priority'] ?? 'medium';
      _status = r['status'] ?? 'pending'; _truckId = r['truck']?.toString(); _date = r['date_performed'];
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _truckId == null) { setState(() => _error = 'Truck and Title are required.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final payload = {
        'truck': int.parse(_truckId!), 'maintenance_type': _type, 'title': _titleCtrl.text.trim(),
        'priority': _priority, 'status': _status, 'description': _descCtrl.text.trim(),
        if (_date != null) 'date_performed': _date,
        if (_costCtrl.text.isNotEmpty) 'cost': double.tryParse(_costCtrl.text),
        if (_mileCtrl.text.isNotEmpty) 'mileage_at_service': double.tryParse(_mileCtrl.text),
        if (_vendorCtrl.text.isNotEmpty) 'vendor_name': _vendorCtrl.text.trim(),
      };
      await _saveRecord(payload, widget.record != null ? widget.record!['id'] as int? : null);
      widget.onSaved();
    } catch (e) { setState(() => _error = e.toString()); }
    finally { setState(() => _saving = false); }
  }

  InputDecoration _dec(String h) => InputDecoration(hintText: h, hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF031634), width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), filled: true, fillColor: Colors.white);

  Widget _label(String t, Widget child) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)), const SizedBox(height: 6), child]));

  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
    child: Column(children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 16),
      Text(widget.record != null ? 'Edit Record' : 'Add Maintenance Record', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF031634))),
      const SizedBox(height: 16),
      if (_error != null) Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
        child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
      Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('TRUCK *', DropdownButtonFormField<String>(value: _truckId, decoration: _dec('Select truck…'),
          items: _trucks.map<DropdownMenuItem<String>>((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['label'], style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: (v) => setState(() => _truckId = v))),
        _label('MAINTENANCE TYPE', DropdownButtonFormField<String>(value: _type, decoration: _dec(''),
          items: const [
            DropdownMenuItem(value:'oil_change', child:Text('Oil Change')),
            DropdownMenuItem(value:'tire_rotation', child:Text('Tire Rotation / Replacement')),
            DropdownMenuItem(value:'brake_service', child:Text('Brake Service')),
            DropdownMenuItem(value:'engine', child:Text('Engine Repair')),
            DropdownMenuItem(value:'transmission', child:Text('Transmission')),
            DropdownMenuItem(value:'electrical', child:Text('Electrical')),
            DropdownMenuItem(value:'lights', child:Text('Lights / Signals')),
            DropdownMenuItem(value:'inspection_prep', child:Text('DOT Inspection Prep')),
            DropdownMenuItem(value:'other', child:Text('Other')),
          ], onChanged: (v) => setState(() => _type = v!))),
        _label('TITLE *', TextField(controller: _titleCtrl, decoration: _dec('e.g. Oil change at 150,000 miles'))),
        Row(children: [
          Expanded(child: _label('PRIORITY', DropdownButtonFormField<String>(value: _priority, decoration: _dec(''),
            items: const [DropdownMenuItem(value:'low',child:Text('Low')),DropdownMenuItem(value:'medium',child:Text('Medium')),DropdownMenuItem(value:'high',child:Text('High')),DropdownMenuItem(value:'critical',child:Text('Critical'))],
            onChanged: (v) => setState(() => _priority = v!)))),
          const SizedBox(width: 12),
          Expanded(child: _label('STATUS', DropdownButtonFormField<String>(value: _status, decoration: _dec(''),
            items: const [DropdownMenuItem(value:'pending',child:Text('Pending')),DropdownMenuItem(value:'in_progress',child:Text('In Progress')),DropdownMenuItem(value:'completed',child:Text('Completed')),DropdownMenuItem(value:'cancelled',child:Text('Cancelled'))],
            onChanged: (v) => setState(() => _status = v!)))),
        ]),
        _label('DATE PERFORMED', GestureDetector(onTap: () async {
          final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (d != null) setState(() => _date = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}');
        }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10), color: Colors.white),
          child: Row(children: [const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF94A3B8)), const SizedBox(width: 8),
            Text(_date ?? 'Select date…', style: TextStyle(color: _date != null ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)))])))),
        Row(children: [
          Expanded(child: _label('COST (\$)', TextField(controller: _costCtrl, keyboardType: TextInputType.number, decoration: _dec('0.00')))),
          const SizedBox(width: 12),
          Expanded(child: _label('ODOMETER (mi)', TextField(controller: _mileCtrl, keyboardType: TextInputType.number, decoration: _dec('miles')))),
        ]),
        _label('VENDOR / SHOP', TextField(controller: _vendorCtrl, decoration: _dec("Joe's Auto Shop"))),
        _label('DESCRIPTION', TextField(controller: _descCtrl, maxLines: 3, decoration: _dec('Details…'))),
      ]))),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF031634), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(widget.record != null ? 'Update Record' : 'Save Record', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      )),
    ]),
  );
}
