import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';
import 'add_fuel_sheet.dart';

const _navy  = Color(0xFF031634);
const _navy2 = Color(0xFF0D2952);
const _blue  = Color(0xFF0453CD);
const _green = Color(0xFF16A34A);
const _surface = Color(0xFFF0F3FF);
const _border  = Color(0xFFDCE2F3);
const _grey    = Color(0xFF75777E);

/// Safely parse a value that may be String or num from the API.
double _n(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

String _fmt(dynamic v, int decimals) {
  final d = _n(v);
  return d.toStringAsFixed(decimals);
}

class DriverFuelScreen extends StatefulWidget {
  const DriverFuelScreen({super.key});
  @override
  State<DriverFuelScreen> createState() => _State();
}

class _State extends State<DriverFuelScreen> {
  List<Map> _logs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.getDriverData();
      setState(() => _logs = List<Map>.from(res.data['fuel_logs'] ?? []));
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  void _openAddSheet() => Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(builder: (_) => AddFuelSheet(onSaved: _load)),
  );

  double get _totalCost    => _logs.fold(0, (s, f) => s + _n(f['total_cost']));
  double get _totalGallons => _logs.fold(0, (s, f) => s + _n(f['gallons']));
  double get _avgPPG       => _logs.isEmpty ? 0 :
      _logs.fold(0.0, (s, f) => s + _n(f['price_per_gallon'])) / _logs.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: RefreshIndicator(
        onRefresh: _load, color: _blue,
        child: CustomScrollView(slivers: [
          // ── Pinned SliverAppBar header ────────────────────────────────────
          SliverAppBar(
            expandedHeight: 115,
            pinned: true,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            // ── Collapsed title (always pinned when scrolled) ───────────────
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Icon(Icons.local_gas_station_outlined,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                Text('Fuel Logs', style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.white)),
                const Spacer(),
                Text('${_logs.length} logs', style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white54)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openAddSheet,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.20)),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16)),
                ),
              ],
            ),
            // ── Expanded area: stats only (no title duplication) ────────────
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [_navy, _navy2],
                  ),
                ),
                child: Stack(children: [
                  Positioned(right: -30, top: -30, child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04)))),
                  Positioned(right: 40, top: 60, child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: _blue.withOpacity(0.18)))),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats row only — title is in SliverAppBar.title
                          Row(children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('TOTAL SPENT', style: GoogleFonts.inter(
                                  fontSize: 9, letterSpacing: 1.1,
                                  color: Colors.white54)),
                              const SizedBox(height: 2),
                              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('\$${_totalCost.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white, height: 1)),
                              ]),
                            ]),
                            const Spacer(),
                            // Mini stat pills
                            Row(children: [
                              _MiniPill(label: 'Gallons',
                                  value: _totalGallons.toStringAsFixed(1),
                                  icon: Icons.water_drop_outlined),
                              const SizedBox(width: 6),
                              _MiniPill(label: 'Stops',
                                  value: '${_logs.length}',
                                  icon: Icons.pin_drop_outlined),
                              const SizedBox(width: 6),
                              _MiniPill(label: 'Avg/gal',
                                  value: _avgPPG > 0
                                      ? '\$${_avgPPG.toStringAsFixed(2)}'
                                      : '—',
                                  icon: Icons.trending_up_rounded),
                            ]),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else ...[
            // Stats cards
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(children: [
                Expanded(child: _StatCard(icon: Icons.attach_money_rounded,
                  color: _green, label: 'Total Spend',
                  value: '\$${_totalCost.toStringAsFixed(2)}')),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(icon: Icons.water_drop_outlined,
                  color: _blue, label: 'Gallons',
                  value: '${_totalGallons.toStringAsFixed(1)}')),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(icon: Icons.pin_drop_outlined,
                  color: const Color(0xFF7C3AED), label: 'Stops',
                  value: '${_logs.length}')),
              ]),
            )),

            // Section label
            if (_logs.isNotEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text('FUEL LOG HISTORY', style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _grey, letterSpacing: 0.8)),
              )),

            // Empty state or list
            _logs.isEmpty
                ? SliverFillRemaining(child: _EmptyState(onAdd: _openAddSheet))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate(
                      (_, i) => _FuelCard(log: _logs[i],
                          onReceiptUpload: () => _uploadReceipt(_logs[i])),
                      childCount: _logs.length,
                    )),
                  ),
          ],
        ]),
      ),
    );
  }

  Future<void> _uploadReceipt(Map log) async {
    final id = log['id'] as int?;
    if (id == null) return;
    showModalBottomSheet(
      context: Navigator.of(context, rootNavigator: true).context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiptUploadSheet(fuelId: id, onDone: _load),
    );
  }
}

// ── Mini stat pill (matches trips _StatPill style) ────────────────────────────
class _MiniPill extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _MiniPill({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(0.12)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.white60),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
      Text(label, style: GoogleFonts.inter(fontSize: 8, color: Colors.white54)),
    ]),
  );
}


// ── Stat card ──────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon; final Color color;
  final String label, value;
  const _StatCard({required this.icon, required this.color,
    required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 17, color: color)),
      const SizedBox(height: 8),
      Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: _grey)),
    ]),
  );
}

// ── Fuel log card ──────────────────────────────────────────────────────────────
class _FuelCard extends StatelessWidget {
  final Map log;
  final VoidCallback onReceiptUpload;
  const _FuelCard({required this.log, required this.onReceiptUpload});
  @override
  Widget build(BuildContext context) {
    final cost    = _fmt(log['total_cost'], 2);
    final gallons = _fmt(log['gallons'], 2);
    final ppg     = _fmt(log['price_per_gallon'], 3);
    final date    = log['purchase_date'] as String? ?? '';
    final vendor  = log['vendor_name'] as String? ?? 'Fuel Stop';
    final city    = log['vendor_city'] as String? ?? '';
    final jur     = log['jurisdiction'] as String? ?? '—';
    final hasReceipt = log['has_receipt'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Container(width: 46, height: 46,
              decoration: BoxDecoration(color: _green.withOpacity(0.10),
                borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.local_gas_station_rounded,
                  color: _green, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(vendor, style: GoogleFonts.inter(fontSize: 14,
                  fontWeight: FontWeight.w700, color: _navy)),
              Text(city.isNotEmpty ? '$city • $jur' : jur,
                  style: GoogleFonts.inter(fontSize: 12, color: _grey)),
              const SizedBox(height: 6),
              Row(children: [
                _Chip('$gallons gal', _blue.withOpacity(0.08), _blue),
                const SizedBox(width: 6),
                _Chip('\$$ppg/gal', Colors.orange.withOpacity(0.08), Colors.orange.shade700),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\$$cost', style: GoogleFonts.inter(fontSize: 17,
                  fontWeight: FontWeight.w800, color: _green)),
              Text(date.length >= 10 ? date.substring(5, 10).replaceAll('-', '/') : date,
                  style: GoogleFonts.inter(fontSize: 11, color: _grey)),
            ]),
          ]),
          // Receipt row
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: hasReceipt ? null : onReceiptUpload,
            child: Row(children: [
              Icon(hasReceipt ? Icons.receipt_long_outlined : Icons.upload_file_outlined,
                  size: 15, color: hasReceipt ? _green : _grey),
              const SizedBox(width: 6),
              Text(hasReceipt ? 'Receipt attached' : 'Upload receipt',
                  style: GoogleFonts.inter(fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: hasReceipt ? _green : _grey)),
              if (!hasReceipt) ...[
                const Spacer(),
                const Icon(Icons.chevron_right, size: 16, color: _grey),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

Widget _Chip(String l, Color bg, Color text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
  child: Text(l, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: text)));

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 72, height: 72,
      decoration: BoxDecoration(color: _border,
        borderRadius: BorderRadius.circular(20)),
      child: Icon(Icons.local_gas_station_outlined,
          size: 34, color: Colors.grey.shade400)),
    const SizedBox(height: 14),
    Text('No fuel logs yet', style: GoogleFonts.inter(fontSize: 15,
        fontWeight: FontWeight.w600, color: _grey)),
    const SizedBox(height: 4),
    Text('Tap below to log your first fuel stop',
        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400)),
    const SizedBox(height: 20),
    ElevatedButton.icon(
      onPressed: onAdd,
      style: ElevatedButton.styleFrom(backgroundColor: _navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      icon: const Icon(Icons.add, color: Colors.white, size: 18),
      label: Text('Add Fuel Log', style: GoogleFonts.inter(
          fontWeight: FontWeight.w700, color: Colors.white)),
    ),
  ]));
}

// ── Quick receipt upload sheet ─────────────────────────────────────────────────
class _ReceiptUploadSheet extends StatefulWidget {
  final int fuelId;
  final VoidCallback onDone;
  const _ReceiptUploadSheet({required this.fuelId, required this.onDone});
  @override
  State<_ReceiptUploadSheet> createState() => _ReceiptUploadSheetState();
}

class _ReceiptUploadSheetState extends State<_ReceiptUploadSheet> {
  bool _uploading = false;

  Future<void> _pick(ImageSource src) async {
    final picked = await ImagePicker().pickImage(source: src, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await ApiClient.uploadFuelReceipt(widget.fuelId, picked.path);
      if (mounted) { Navigator.pop(context); widget.onDone(); }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: Color(0xFFF0F3FF),
      borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
    child: _uploading
        ? const Padding(padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()))
        : Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Upload Receipt', style: GoogleFonts.inter(fontSize: 17,
                fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 20),
            _UploadOption(icon: Icons.camera_alt_outlined,
              label: 'Take Photo', onTap: () => _pick(ImageSource.camera)),
            const SizedBox(height: 10),
            _UploadOption(icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery', onTap: () => _pick(ImageSource.gallery)),
          ]),
  );
}

class _UploadOption extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _UploadOption({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: _blue, size: 20),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(fontSize: 14,
            fontWeight: FontWeight.w600, color: _navy)),
      ]),
    ),
  );
}
