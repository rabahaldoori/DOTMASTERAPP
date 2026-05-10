import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/font_ext.dart';

const _navy  = Color(0xFF0B1D3A);
const _blue  = Color(0xFF1D6AF5);
const _cyan  = Color(0xFF06B6D4);
const _slate = Color(0xFF64748B);
const _bg    = Color(0xFFF1F5FB);

class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({super.key});
  @override
  State<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _first       = TextEditingController();
  final _last        = TextEditingController();
  final _email       = TextEditingController();
  final _phone       = TextEditingController();
  final _pass        = TextEditingController();
  final _passConfirm = TextEditingController();
  final _cdlNum      = TextEditingController();
  final _cdlState    = TextEditingController();

  DateTime? _cdlExpiry;
  DateTime? _hireDate;
  int?      _assignedTruckId;

  List<Map<String, dynamic>> _trucks = [];
  bool _loadingTrucks = false;
  bool _submitting    = false;
  bool _obscurePass   = true;
  bool _obscureConf   = true;

  @override
  void initState() { super.initState(); _loadTrucks(); }

  Future<void> _loadTrucks() async {
    setState(() => _loadingTrucks = true);
    try {
      final res  = await ApiClient.getTrucks();
      final list = (res.data is List)
          ? List<Map<String, dynamic>>.from(res.data as List)
          : List<Map<String, dynamic>>.from(
              (res.data as Map)['results'] as List? ?? []);
      setState(() { _trucks = list; _loadingTrucks = false; });
    } catch (_) { setState(() => _loadingTrucks = false); }
  }

  @override
  void dispose() {
    _first.dispose(); _last.dispose(); _email.dispose(); _phone.dispose();
    _pass.dispose();  _passConfirm.dispose();
    _cdlNum.dispose(); _cdlState.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isCdl) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isCdl ? (_cdlExpiry ?? now.add(const Duration(days: 365))) : (_hireDate ?? now),
      firstDate: isCdl ? now : DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _blue, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() { if (isCdl) _cdlExpiry = picked; else _hireDate = picked; });
  }

  String _fmt(DateTime? d) => d == null
      ? ''
      : '${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}/${d.year}';

  Future<void> _submit() async {
    final s = context.read<LocaleProvider>().s;
    if (!_formKey.currentState!.validate()) return;
    if (_pass.text != _passConfirm.text) {
      _showErr(s.passwordsDoNotMatch); return;
    }
    setState(() => _submitting = true);
    try {
      await ApiClient.hireDriver({
        'first_name': _first.text.trim(),
        'last_name':  _last.text.trim(),
        'password':   _pass.text.trim(),
        if (_email.text.trim().isNotEmpty)    'email':      _email.text.trim(),
        if (_phone.text.trim().isNotEmpty)    'phone':      _phone.text.trim(),
        if (_cdlNum.text.trim().isNotEmpty)   'cdl_number': _cdlNum.text.trim(),
        if (_cdlState.text.trim().isNotEmpty) 'cdl_state':  _cdlState.text.trim(),
        if (_cdlExpiry != null) 'cdl_expiry':
          '${_cdlExpiry!.year}-${_cdlExpiry!.month.toString().padLeft(2,'0')}-${_cdlExpiry!.day.toString().padLeft(2,'0')}',
        if (_hireDate != null) 'hire_date':
          '${_hireDate!.year}-${_hireDate!.month.toString().padLeft(2,'0')}-${_hireDate!.day.toString().padLeft(2,'0')}',
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) { setState(() => _submitting = false); _showErr(e.toString()); }
  }

  void _showErr(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: context.af(fontWeight: FontWeight.w500, color: Colors.white)),
    backgroundColor: const Color(0xFFEF4444),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
  ));

  // ─── Input decoration ─────────────────────────────────────────────────────
  InputDecoration _deco(String label, {String? hint, Widget? suffix, Widget? prefix}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      labelStyle: context.af(fontSize: 13, color: _slate),
      hintStyle: context.af(fontSize: 13, color: const Color(0xFFBDC7D4)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8EEF6))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8EEF6))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _blue, width: 1.8)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );

  Widget _text(TextEditingController ctrl, String label, {
    String? hint, bool req = false, TextInputType kb = TextInputType.text,
    bool obs = false, Widget? suffix, Widget? prefix,
    TextInputAction action = TextInputAction.next,
    String? Function(String?)? validator,
  }) {
    final s = context.read<LocaleProvider>().s;
    return TextFormField(
      controller: ctrl, obscureText: obs, keyboardType: kb,
      textInputAction: action,
      style: context.af(fontSize: 14, color: const Color(0xFF1E293B)),
      decoration: _deco(label, hint: hint, suffix: suffix, prefix: prefix),
      validator: validator ?? (req ? (v) => (v == null || v.trim().isEmpty) ? s.required : null : null),
    );
  }

  Widget _datePicker(String label, DateTime? val, bool isCdl, {bool req = false}) {
    final s = context.read<LocaleProvider>().s;
    return GestureDetector(
      onTap: () => _pickDate(isCdl),
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: _fmt(val)),
          style: context.af(fontSize: 14, color: const Color(0xFF1E293B)),
          decoration: _deco(label, hint: 'mm/dd/yyyy',
            suffix: const Icon(Icons.calendar_month_rounded, size: 18, color: _slate)),
          validator: req ? (_) => val == null ? s.selectADate : null : null,
        ),
      ),
    );
  }

  Widget _row(Widget a, Widget b) => Row(children: [
    Expanded(child: a), const SizedBox(width: 12), Expanded(child: b),
  ]);

  Widget _section(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 14, top: 4),
    child: Row(children: [
      Container(width: 30, height: 30,
        decoration: BoxDecoration(
          color: _blue.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: _blue)),
      const SizedBox(width: 10),
      Text(title, style: context.af(
          fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: const Color(0xFFE8EEF6))),
    ]),
  );

  Widget _card(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Column(children: children),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().s;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        // ── Premium header ─────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0B1D3A), Color(0xFF0F3260)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(children: [
              Positioned(top: -20, right: -20,
                child: Container(width: 100, height: 100,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _blue.withOpacity(0.12)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.hireNewDriver,
                        style: context.af(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    Text(s.enterDriverDetails,
                        style: context.af(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.55))),
                  ])),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_blue, _cyan],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        color: Colors.white, size: 22)),
                ]),
              ),
            ]),
          ),
        ),

        // ── Form ───────────────────────────────────────────────────────────
        Expanded(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Personal ────────────────────────────────────────────
                _section(s.personalInfo, Icons.person_outline_rounded),
                _card([
                  _row(
                    _text(_last,  s.lastName,  hint: 'Doe',  req: true),
                    _text(_first, s.firstName, hint: 'John', req: true),
                  ),
                  const SizedBox(height: 12),
                  _row(
                    _text(_email, s.email, hint: 'driver@company.com',
                        kb: TextInputType.emailAddress,
                        prefix: const Icon(Icons.email_outlined, size: 17, color: _slate)),
                    _text(_phone, s.phone, hint: '+1 555-000-1234',
                        kb: TextInputType.phone,
                        prefix: const Icon(Icons.phone_outlined, size: 17, color: _slate)),
                  ),
                ]),

                // ── CDL ─────────────────────────────────────────────────
                _section(s.cdlInformation, Icons.badge_outlined),
                _card([
                  _row(
                    _text(_cdlState, s.cdlState,  hint: 'e.g. TX', req: true),
                    _text(_cdlNum,   s.cdlNumber, hint: 'TX-49201-992', req: true),
                  ),
                  const SizedBox(height: 12),
                  _row(
                    _datePicker(s.hireDateLabel,         _hireDate,  false, req: true),
                    _datePicker(s.cdlExpirationLabel,    _cdlExpiry, true,  req: true),
                  ),
                ]),

                // ── Assignment ──────────────────────────────────────────
                _section(s.truckAssignment, Icons.local_shipping_outlined),
                _card([
                  DropdownButtonFormField<int?>(
                    value: _assignedTruckId,
                    isExpanded: true,
                    menuMaxHeight: 220,
                    decoration: _deco(s.assignedTruck,
                        prefix: const Icon(Icons.local_shipping_outlined,
                            size: 17, color: _slate)),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _slate, size: 20),
                    style: context.af(fontSize: 14, color: const Color(0xFF1E293B)),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(s.noTruckAssignedOption,
                            style: context.af(fontSize: 14, color: _slate)),
                      ),
                      ..._trucks.map((t) => DropdownMenuItem<int?>(
                        value: t['id'] as int?,
                        child: Text(
                          (t['unit_number'] ?? t['id'].toString()).toString(),
                          style: context.af(fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (v) => setState(() => _assignedTruckId = v),
                  ),
                ]),

                // ── Password ─────────────────────────────────────────────
                _section(s.accountCredentials, Icons.lock_outline_rounded),
                _card([
                  _text(_pass, s.appPassword, hint: s.minEightChars,
                    req: true, obs: _obscurePass,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return s.required;
                      if (v.length < 8) return s.minEightChars;
                      return null;
                    },
                    suffix: IconButton(
                      icon: Icon(_obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                          color: _slate, size: 18),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass)),
                  ),
                  const SizedBox(height: 12),
                  _text(_passConfirm, s.confirmPassword, hint: s.reEnterPassword,
                    req: true, obs: _obscureConf, action: TextInputAction.done,
                    suffix: IconButton(
                      icon: Icon(_obscureConf
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                          color: _slate, size: 18),
                      onPressed: () => setState(() => _obscureConf = !_obscureConf)),
                  ),
                ]),

                const SizedBox(height: 8),
              ]),
            ),
          ),
        ),

        // ── Action bar ─────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12, offset: const Offset(0, -3))],
          ),
          padding: EdgeInsets.fromLTRB(
              16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
          child: Row(children: [
            // Cancel
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _slate,
                  side: const BorderSide(color: Color(0xFFDDE3ED), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(s.cancel,
                    style: context.af(
                        fontSize: 15, fontWeight: FontWeight.w600, color: _slate)),
              ),
            ),
            const SizedBox(width: 12),
            // Hire Driver
            Expanded(
              flex: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_navy, Color(0xFF1D4ED8)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: _navy.withOpacity(0.30),
                      blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.person_add_alt_1_rounded,
                          color: Colors.white, size: 18),
                  label: Text(s.hireDriver,
                      style: context.af(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
