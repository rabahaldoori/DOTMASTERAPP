import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../../core/api_client.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/font_ext.dart';

class DriverMaintenanceFormScreen extends StatefulWidget {
  /// Pass an existing record map to pre-fill (edit mode), or null for new.
  final Map? record;
  /// Where to navigate after a successful save. Defaults to driver maintenance.
  final String returnRoute;
  const DriverMaintenanceFormScreen({
    super.key,
    this.record,
    this.returnRoute = '/driver-maintenance',
  });

  @override
  State<DriverMaintenanceFormScreen> createState() =>
      _DriverMaintenanceFormScreenState();
}

class _DriverMaintenanceFormScreenState
    extends State<DriverMaintenanceFormScreen> {
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _costCtrl   = TextEditingController();
  final _mileCtrl   = TextEditingController();
  final _vendorCtrl = TextEditingController();

  String  _type     = 'oil_change';
  String  _priority = 'medium';
  String  _status   = 'pending';
  String? _truckId;
  String? _date;
  List    _trucks      = [];
  bool    _saving      = false;
  String? _error;
  File?   _invoiceFile;
  String? _existingInvoiceUrl;

  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    _fetchTrucks();
    final r = widget.record;
    if (r != null) {
      _titleCtrl.text  = r['title']             ?? '';
      _descCtrl.text   = r['description']        ?? '';
      _costCtrl.text   = r['cost']?.toString()   ?? '';
      _mileCtrl.text   = r['mileage_at_service']?.toString() ?? '';
      _vendorCtrl.text = r['vendor_name']        ?? '';
      _type     = r['maintenance_type'] ?? 'oil_change';
      _priority = r['priority']         ?? 'medium';
      _status   = r['status']           ?? 'pending';
      _truckId           = r['truck']?.toString();
      _date              = r['date_performed'];
      _existingInvoiceUrl = r['invoice_url'] as String?;
    }
  }

  Future<void> _fetchTrucks() async {
    try {
      final res = await ApiClient.dio.get('/api/maintenance/trucks/');
      final data = res.data;
      if (mounted) setState(() => _trucks = data is List ? data : []);
    } catch (_) {}
  }

  // ── Invoice picker ─────────────────────────────────────────────────────────
  Future<void> _pickInvoice(String source) async {
    File? file;
    if (source == 'camera') {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.camera, imageQuality: 85);
      if (picked != null) file = File(picked.path);
    } else if (source == 'gallery') {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) file = File(picked.path);
    } else {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
      if (result != null && result.files.single.path != null) {
        file = File(result.files.single.path!);
      }
    }
    if (file != null && mounted) setState(() => _invoiceFile = file);
  }

  void _showInvoicePicker() {
    final s = context.read<LocaleProvider>().s;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2))),
          _InvoiceOption(
              icon: Icons.camera_alt_rounded,
              label: s.takeAPhoto,
              onTap: () { Navigator.pop(context); _pickInvoice('camera'); }),
          _InvoiceOption(
              icon: Icons.photo_library_rounded,
              label: s.chooseFromGallery,
              onTap: () { Navigator.pop(context); _pickInvoice('gallery'); }),
          _InvoiceOption(
              icon: Icons.insert_drive_file_rounded,
              label: s.browseFilesPdfImage,
              onTap: () { Navigator.pop(context); _pickInvoice('file'); }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    final s = context.read<LocaleProvider>().s;
    if (_titleCtrl.text.trim().isEmpty || _truckId == null) {
      setState(() => _error = s.truckAndTitleRequired);
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final form = FormData.fromMap({
        'truck':            _truckId!,
        'maintenance_type': _type,
        'title':            _titleCtrl.text.trim(),
        'priority':         _priority,
        'status':           _status,
        'description':      _descCtrl.text.trim(),
        if (_date != null)               'date_performed':     _date,
        if (_costCtrl.text.isNotEmpty)   'cost':               _costCtrl.text.trim(),
        if (_mileCtrl.text.isNotEmpty)   'mileage_at_service': _mileCtrl.text.trim(),
        if (_vendorCtrl.text.isNotEmpty) 'vendor_name':        _vendorCtrl.text.trim(),
        if (_invoiceFile != null)
          'invoice_file': await MultipartFile.fromFile(
              _invoiceFile!.path,
              filename: p.basename(_invoiceFile!.path)),
      });

      final id = widget.record?['id'] as int?;
      if (id != null) {
        await ApiClient.dio.patch('/api/maintenance/mobile/$id/',
            data: form,
            options: Options(contentType: 'multipart/form-data'));
      } else {
        await ApiClient.dio.post('/api/maintenance/mobile/',
            data: form,
            options: Options(contentType: 'multipart/form-data'));
      }

      if (mounted) context.go(widget.returnRoute);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: context.af(color: const Color(0xFFCBD5E1), fontSize: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0A2550), width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white,
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: context.af(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
                letterSpacing: 0.6)),
      );

  Widget _field(String label, Widget input) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_label(label), input, const SizedBox(height: 18)],
      );

  @override
  Widget build(BuildContext context) {
    final s   = context.read<LocaleProvider>().s;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3FF),
      // ── Sticky submit button ──────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF031634).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4))
          ],
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF031634),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    _isEdit ? s.updateRecord : s.submitReport,
                    style: context.af(
                        fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Top Bar ─────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
                top: top + 12, left: 8, right: 16, bottom: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A2550),
                  Color(0xFF031634),
                  Color(0xFF0D3A6B),
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => context.go(widget.returnRoute),
                ),
                Expanded(
                  child: Text(
                    _isEdit ? s.editRecord : s.reportMaintenance,
                    style: context.af(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // ── Form Body ───────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error banner
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200)),
                      child: Row(children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!,
                                style: context.af(
                                    color: Colors.red, fontSize: 13))),
                      ]),
                    ),
                  ],

                  // Truck + Type
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          s.typeTruck,
                          DropdownButtonFormField<String>(
                            value: _truckId,
                            decoration: _dec(s.selectTruckHint),
                            isExpanded: true,
                            items: _trucks
                                .map<DropdownMenuItem<String>>((t) =>
                                    DropdownMenuItem(
                                        value: t['id'].toString(),
                                        child: Text(t['label'],
                                            overflow: TextOverflow.ellipsis,
                                            style: context.af(fontSize: 13))))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _truckId = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          s.typeLabel,
                          DropdownButtonFormField<String>(
                            value: _type,
                            decoration: _dec(''),
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(value: 'oil_change',      child: Text(s.oilChange,          style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'tire_rotation',   child: Text(s.typeTires,          style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'brake_service',   child: Text(s.typeBrakes,         style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'engine',          child: Text(s.typeEngine,         style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'transmission',    child: Text(s.typeTransmission,   style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'electrical',      child: Text(s.typeElectrical,     style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'hvac',            child: Text(s.typeHvac,           style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'suspension',      child: Text(s.typeSuspension,     style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'lights',          child: Text(s.typeLights,         style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'windshield',      child: Text(s.typeWindshield,     style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'inspection_prep', child: Text(s.typeDotPrep,        style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'other',           child: Text(s.typeOther,          style: context.af(fontSize: 13))),
                            ],
                            onChanged: (v) =>
                                setState(() => _type = v!),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Title
                  _field(s.titleRequired,
                      TextField(controller: _titleCtrl, decoration: _dec(s.titleHint))),

                  // Priority + Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          s.priority,
                          DropdownButtonFormField<String>(
                            value: _priority,
                            decoration: _dec(''),
                            items: [
                              DropdownMenuItem(value: 'low',      child: Text(s.priorityLow,    style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'medium',   child: Text(s.priorityMedium, style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'high',     child: Text(s.priorityHigh,   style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'critical', child: Text(s.critical,       style: context.af(fontSize: 13))),
                            ],
                            onChanged: (v) =>
                                setState(() => _priority = v!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          s.status,
                          DropdownButtonFormField<String>(
                            value: _status,
                            decoration: _dec(''),
                            items: [
                              DropdownMenuItem(value: 'pending',     child: Text(s.pending,         style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'in_progress', child: Text(s.inProgress,      style: context.af(fontSize: 13))),
                              DropdownMenuItem(value: 'completed',   child: Text(s.statusCompleted, style: context.af(fontSize: 13))),
                            ],
                            onChanged: (v) =>
                                setState(() => _status = v!),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Date
                  _field(
                    s.datePerformed,
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && mounted) {
                          setState(() => _date =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 16, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 10),
                          Text(
                            _date ?? s.selectDateHint,
                            style: context.af(
                              fontSize: 14,
                              color: _date != null
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),

                  // Cost + Odometer
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _field(s.costDollar,
                              TextField(
                                  controller: _costCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _dec('0.00')))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _field(s.odometerMi,
                              TextField(
                                  controller: _mileCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _dec(s.miles)))),
                    ],
                  ),

                  // Vendor
                  _field(s.vendorShop,
                      TextField(controller: _vendorCtrl, decoration: _dec(s.vendorShopHint))),

                  // Description
                  _field(s.description,
                      TextField(
                          controller: _descCtrl,
                          maxLines: 4,
                          decoration: _dec(s.descriptionHint))),

                  // Invoice Upload
                  _label(s.invoiceReceipt),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _showInvoicePicker,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _invoiceFile != null
                            ? const Color(0xFF031634).withValues(alpha: 0.04)
                            : Colors.white,
                        border: Border.all(
                            color: _invoiceFile != null
                                ? const Color(0xFF031634)
                                : const Color(0xFFE2E8F0),
                            width: _invoiceFile != null ? 1.5 : 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _invoiceFile != null
                          ? Row(children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF031634).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.insert_drive_file_rounded,
                                    color: Color(0xFF031634), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.basename(_invoiceFile!.path),
                                          overflow: TextOverflow.ellipsis,
                                          style: context.af(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF1E293B))),
                                      Text(s.tapToChange,
                                          style: context.af(
                                              fontSize: 11,
                                              color: const Color(0xFF94A3B8))),
                                    ]),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () =>
                                    setState(() => _invoiceFile = null),
                              ),
                            ])
                          : Column(mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                              const Icon(Icons.upload_file_rounded,
                                  size: 32, color: Color(0xFFCBD5E1)),
                              const SizedBox(height: 8),
                              Text(s.tapAttachInvoice,
                                  style: context.af(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF94A3B8))),
                              const SizedBox(height: 4),
                              Text(s.pdfJpgPng,
                                  style: context.af(
                                      fontSize: 11,
                                      color: const Color(0xFFCBD5E1))),
                            ]),
                    ),
                  ),
                  if (_existingInvoiceUrl != null && _invoiceFile == null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 14, color: Color(0xFF22C55E)),
                      const SizedBox(width: 6),
                      Text(s.existingInvoiceOnFile,
                          style: context.af(
                              fontSize: 12, color: const Color(0xFF22C55E))),
                    ]),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────
class _InvoiceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _InvoiceOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: const Color(0xFF031634).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF031634), size: 22),
        ),
        title: Text(label,
            style: context.af(
                fontWeight: FontWeight.w600, fontSize: 14,
                color: const Color(0xFF1E293B))),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: Color(0xFFCBD5E1)),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      );
}
