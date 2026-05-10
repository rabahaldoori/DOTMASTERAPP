import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/font_ext.dart';

const _navy  = Color(0xFF031634);
const _navy2 = Color(0xFF0D2952);
const _blue  = Color(0xFF0453CD);
const _green = Color(0xFF16A34A);
const _grey  = Color(0xFF64748B);
const _bg    = Color(0xFFF0F3FF);
const _border = Color(0xFFDCE2F3);

double _n(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class FuelDetailScreen extends StatefulWidget {
  final Map<String, dynamic> fuel;
  const FuelDetailScreen({super.key, required this.fuel});

  @override
  State<FuelDetailScreen> createState() => _FuelDetailScreenState();
}

class _FuelDetailScreenState extends State<FuelDetailScreen> {
  bool _uploading = false;

  // ── Receipt upload ───────────────────────────────────────────────────────────
  Future<void> _uploadReceipt() async {
    final s = context.read<LocaleProvider>().s;
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            top: 8, bottom: MediaQuery.of(ctx).padding.bottom + 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              margin: const EdgeInsets.only(bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.camera_alt_outlined, color: _blue, size: 18)),
            title: Text(s.takePhoto,
                style: ctx.af(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.of(ctx, rootNavigator: true).pop(ImageSource.camera)),
          ListTile(
            leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.photo_library_outlined,
                  color: _green, size: 18)),
            title: Text(s.chooseFromGallery,
                style: ctx.af(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.of(ctx, rootNavigator: true).pop(ImageSource.gallery)),
        ]),
      ),
    );
    if (src == null) return;
    final picked = await ImagePicker().pickImage(source: src, imageQuality: 80);
    if (picked == null || !mounted) return;

    final id = int.tryParse(widget.fuel['id']?.toString() ?? '');
    if (id == null) return;

    setState(() => _uploading = true);
    try {
      await ApiClient.uploadFuelReceipt(id, picked.path);
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.receiptUploaded,
                style: context.af(color: Colors.white)),
            backgroundColor: _green,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.uploadFailed,
                style: context.af(color: Colors.white)),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s          = context.watch<LocaleProvider>().s;
    final fuel       = widget.fuel;
    final cost       = _n(fuel['total_cost']);
    final gallons    = _n(fuel['gallons']);
    final ppg        = _n(fuel['price_per_gallon']);
    final truckId    = fuel['truck']?.toString().toUpperCase() ?? '—';
    final station    = (fuel['vendor_name'] as String? ??
                        fuel['station_name'] as String? ?? s.fuelStop);
    final address    = fuel['vendor_address'] as String? ?? '';
    final jur        = fuel['state'] as String? ??
                       fuel['jurisdiction'] as String? ?? '—';
    final fuelType   = (fuel['fuel_type'] as String? ?? '').toUpperCase();
    final payment    = (fuel['payment_method'] as String? ?? '')
        .replaceAll('_', ' ').toUpperCase();
    final odometer   = fuel['odometer']?.toString() ?? '';
    final receiptNo  = fuel['receipt_number'] as String? ?? '';
    final hasReceipt = fuel['receipt_image'] != null ||
                       fuel['has_receipt'] == true;
    final receiptUrl = fuel['receipt_image'] as String?;
    final rawDate    = fuel['purchase_date'] as String? ?? '';
    final date       = rawDate.length >= 10
        ? DateFormat('MMMM dd, yyyy')
            .format(DateTime.tryParse(rawDate) ?? DateTime.now())
        : rawDate;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: _navy,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
            title: Text(s.fuelLogDetail, style: context.af(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: Colors.white)),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [_navy, _navy2],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 8, 20, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _green.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.local_gas_station_rounded,
                              color: _green, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Truck #$truckId', style: context.af(
                                fontSize: 18, fontWeight: FontWeight.w800,
                                color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(station, style: context.af(
                                fontSize: 12, color: Colors.white54)),
                          ],
                        )),
                        Column(crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Text('\$${cost.toStringAsFixed(2)}',
                              style: context.af(
                                  fontSize: 22, fontWeight: FontWeight.w900,
                                  color: _green)),
                          Text(date, style: context.af(
                              fontSize: 10, color: Colors.white38)),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, bottom + 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Fuel Details card ────────────────────────────────────────
                  _Section(
                    icon: Icons.water_drop_rounded,
                    title: s.fuelDetails,
                    iconColor: _blue,
                    rows: [
                      _DetailRow(s.gallons, '${gallons.toStringAsFixed(2)} gal',
                          icon: Icons.water_drop_outlined),
                      _DetailRow(s.pricePerGallon,
                          '\$${ppg.toStringAsFixed(3)}',
                          icon: Icons.attach_money_rounded),
                      _DetailRow(s.totalCost,
                          '\$${cost.toStringAsFixed(2)}',
                          icon: Icons.payments_outlined,
                          valueColor: _green,
                          bold: true),
                      if (fuelType.isNotEmpty)
                        _DetailRow(s.fuelType, fuelType,
                            icon: Icons.local_gas_station_outlined),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Location card ────────────────────────────────────────────
                  _Section(
                    icon: Icons.location_on_rounded,
                    title: s.location,
                    iconColor: const Color(0xFFE07B39),
                    rows: [
                      _DetailRow(s.station, station,
                          icon: Icons.storefront_rounded),
                      if (address.isNotEmpty)
                        _DetailRow(s.address, address,
                            icon: Icons.map_outlined),
                      _DetailRow(s.jurisdiction, jur,
                          icon: Icons.flag_outlined),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Payment card ─────────────────────────────────────────────
                  _Section(
                    icon: Icons.credit_card_rounded,
                    title: s.payment,
                    iconColor: const Color(0xFF7C3AED),
                    rows: [
                      if (payment.isNotEmpty)
                        _DetailRow(s.method, payment,
                            icon: Icons.credit_card_outlined),
                      if (receiptNo.isNotEmpty)
                        _DetailRow(s.receiptNumber, receiptNo,
                            icon: Icons.receipt_outlined),
                      if (odometer.isNotEmpty)
                        _DetailRow(s.odometer, '$odometer mi',
                            icon: Icons.speed_rounded),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Receipt card ─────────────────────────────────────────────
                  _SectionHeader(
                      icon: Icons.photo_camera_rounded,
                      title: s.receiptSection,
                      iconColor: hasReceipt ? _green : _grey),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: hasReceipt
                              ? _green.withOpacity(0.3)
                              : _border),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2))],
                    ),
                    child: hasReceipt && receiptUrl != null
                        ? Column(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                receiptUrl,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image_outlined,
                                        size: 40, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: _green, size: 16),
                              const SizedBox(width: 6),
                              Text(s.receiptAttached,
                                  style: context.af(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _green)),
                            ]),
                          ])
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 56, height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(14)),
                                child: const Icon(Icons.upload_file_outlined,
                                    size: 26,
                                    color: Colors.red)),
                              const SizedBox(height: 10),
                              Text(s.noReceiptAttached,
                                  style: context.af(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _grey)),
                              const SizedBox(height: 4),
                              Text(s.tapToUploadReceipt,
                                  style: context.af(
                                      fontSize: 12,
                                      color: Colors.grey.shade400)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom action button (only if no receipt yet) ─────────────────────────
      bottomNavigationBar: !hasReceipt
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _uploading ? null : _uploadReceipt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      disabledBackgroundColor: _navy.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: _uploading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.upload_rounded,
                            color: Colors.white, size: 20),
                    label: Text(
                        _uploading ? s.uploading : s.uploadReceipt,
                        style: context.af(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ── Section widget ─────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final List<Widget> rows;
  const _Section({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(icon: icon, title: title, iconColor: iconColor),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              Container(height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: const Color(0xFFF1F5F9)),
          ],
        ]),
      ),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  const _SectionHeader(
      {required this.icon, required this.title, required this.iconColor});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
            color: iconColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: iconColor)),
    const SizedBox(width: 8),
    Text(title, style: context.af(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: const Color(0xFF64748B), letterSpacing: 0.4)),
  ]);
}

// ── Detail row ──────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label, value;
  final IconData? icon;
  final Color? valueColor;
  final bool bold;
  const _DetailRow(this.label, this.value,
      {this.icon, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      if (icon != null) ...[
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: _grey)),
        const SizedBox(width: 12),
      ],
      Expanded(child: Text(label, style: context.af(
          fontSize: 13, color: _grey, fontWeight: FontWeight.w500))),
      Flexible(child: Text(value,
        textAlign: TextAlign.right,
        style: context.af(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? _navy))),
    ]),
  );
}
