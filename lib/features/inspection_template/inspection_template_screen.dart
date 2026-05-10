import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _navy   = Color(0xFF031634);
const _blue   = Color(0xFF0453CD);
const _cyan   = Color(0xFF06B6D4);
const _surface = Color(0xFFF0F4FA);
const _white  = Colors.white;
const _grey   = Color(0xFF64748B);
const _border = Color(0xFFDCE2F3);

class InspectionTemplateScreen extends StatefulWidget {
  const InspectionTemplateScreen({super.key});
  @override
  State<InspectionTemplateScreen> createState() => _State();
}

class _State extends State<InspectionTemplateScreen> {
  List<_TplCategory> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.getInspectionTemplate();
      if (res.statusCode == 200 && mounted) {
        final List raw = res.data as List? ?? [];
        setState(() {
          _categories = raw.map((c) => _TplCategory.fromJson(c)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load template.'; _loading = false; });
    }
  }

  // ── Category CRUD ────────────────────────────────────────────────────────────
  Future<void> _addCategory() async {
    final result = await _showCategoryDialog(context);
    if (result == null) return;
    try {
      final res = await ApiClient.createInspectionCategory({
        'name': result['name'], 'icon': result['icon'],
      });
      if (res.statusCode == 201 && mounted) {
        _showSnack('Category added ✓');
        _load();
      }
    } catch (_) { _showSnack('Failed to add category', error: true); }
  }

  Future<void> _editCategory(_TplCategory cat) async {
    final result = await _showCategoryDialog(context, initial: cat);
    if (result == null) return;
    try {
      await ApiClient.updateInspectionCategory(cat.id,
          {'name': result['name'], 'icon': result['icon']});
      _showSnack('Category updated ✓');
      _load();
    } catch (_) { _showSnack('Failed to update', error: true); }
  }

  Future<void> _deleteCategory(_TplCategory cat) async {
    final confirmed = await _showConfirm(
        'Delete "${cat.name}"?\nAll items in this category will be removed.');
    if (!confirmed) return;
    try {
      await ApiClient.deleteInspectionCategory(cat.id);
      _showSnack('Deleted');
      _load();
    } catch (_) { _showSnack('Failed to delete', error: true); }
  }

  // ── Item CRUD ────────────────────────────────────────────────────────────────
  Future<void> _addItem(_TplCategory cat) async {
    final label = await _showItemDialog(context);
    if (label == null || label.trim().isEmpty) return;
    try {
      await ApiClient.createInspectionItem({
        'category': cat.id, 'label': label.trim(),
      });
      _showSnack('Item added ✓');
      _load();
    } catch (_) { _showSnack('Failed to add item', error: true); }
  }

  Future<void> _editItem(_TplItem item) async {
    final label = await _showItemDialog(context, initial: item.label);
    if (label == null || label.trim().isEmpty) return;
    try {
      await ApiClient.updateInspectionItem(item.id, {'label': label.trim()});
      _showSnack('Item updated ✓');
      _load();
    } catch (_) { _showSnack('Failed to update', error: true); }
  }

  Future<void> _deleteItem(_TplItem item) async {
    final confirmed = await _showConfirm('Remove "${item.label}"?');
    if (!confirmed) return;
    try {
      await ApiClient.deleteInspectionItem(item.id);
      _showSnack('Removed');
      _load();
    } catch (_) { _showSnack('Failed to delete', error: true); }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: _white)),
      backgroundColor: error ? Colors.red.shade700 : const Color(0xFF15803D),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<bool> _showConfirm(String msg) async {
    return await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Confirm', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: Text(msg, style: GoogleFonts.inter(fontSize: 14, color: _grey)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: _grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Delete', style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w700)),
        ),
      ],
    )) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _blue)))
          else if (_error != null)
            SliverFillRemaining(child: _buildError())
          else if (_categories.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((_, i) =>
                    _CategoryCard(
                      cat: _categories[i],
                      onEdit: () => _editCategory(_categories[i]),
                      onDelete: () => _deleteCategory(_categories[i]),
                      onAddItem: () => _addItem(_categories[i]),
                      onEditItem: _editItem,
                      onDeleteItem: _deleteItem,
                    ),
                  childCount: _categories.length,
                ),
              ),
            ),
        ],
      ),

    );
  }

  Widget _buildAppBar() {
    final totalItems = _categories.fold<int>(0, (s, c) => s + c.items.length);
    return SliverAppBar(
      pinned: true,
      expandedHeight: 170,
      backgroundColor: const Color(0xFF020D1F),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _white, size: 16)),
        ),
      ),
      actions: [
        // History button
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: GestureDetector(
            onTap: () => context.push('/inspection-history'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.history_rounded, color: _white, size: 18)),
          ),
        ),
        const SizedBox(width: 8),
        // Add category button
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16),
          child: GestureDetector(
            onTap: _addCategory,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0672F5), Color(0xFF06B6D4)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(
                  color: _blue.withOpacity(0.35),
                  blurRadius: 8, offset: const Offset(0, 3))]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, color: _white, size: 16),
                const SizedBox(width: 5),
                Text('Add', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _white)),
              ]),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF020D1F), Color(0xFF051E45), Color(0xFF0453CD)],
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Stack(children: [
            // Decorative orbs
            Positioned(right: -30, top: -30,
              child: Container(width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _cyan.withOpacity(0.06)))),
            Positioned(left: -20, bottom: -20,
              child: Container(width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _blue.withOpacity(0.08)))),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _blue.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _blue.withOpacity(0.35))),
                      child: const Icon(Icons.fact_check_rounded, color: _white, size: 22)),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Inspection Templates',
                        style: GoogleFonts.inter(fontSize: 20,
                            fontWeight: FontWeight.w900, color: _white,
                            letterSpacing: -0.3)),
                      Text('Vehicle safety checklist builder',
                        style: GoogleFonts.inter(fontSize: 12,
                            color: Colors.white.withOpacity(0.55))),
                    ]),
                  ]),
                  const SizedBox(height: 14),
                  // Stats row
                  Row(children: [
                    _HeaderChip(Icons.category_rounded,
                        '${_categories.length} Categories', _cyan),
                    const SizedBox(width: 10),
                    _HeaderChip(Icons.checklist_rounded,
                        '$totalItems Items', const Color(0xFF818CF8)),
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 12),
      Text(_error!, style: GoogleFonts.inter(color: _grey)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _load,
          child: Text('Retry', style: GoogleFonts.inter())),
    ]),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(
          color: _blue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.checklist_rounded, size: 36, color: _blue)),
      const SizedBox(height: 16),
      Text('No categories yet',
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: _navy)),
      const SizedBox(height: 6),
      Text('Tap "Add Category" to build your checklist',
          style: GoogleFonts.inter(fontSize: 13, color: _grey)),
    ]),
  );
}

// ── Category card widget ──────────────────────────────────────────────────────
class _CategoryCard extends StatefulWidget {
  final _TplCategory cat;
  final VoidCallback onEdit, onDelete, onAddItem;
  final ValueChanged<_TplItem> onEditItem, onDeleteItem;
  const _CategoryCard({required this.cat, required this.onEdit,
      required this.onDelete, required this.onAddItem,
      required this.onEditItem, required this.onDeleteItem});
  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _open = false;

  // Accent colours cycling per card index (use hashCode for determinism)
  static const _accents = [
    Color(0xFF0453CD), Color(0xFF06B6D4), Color(0xFF7C3AED),
    Color(0xFF059669), Color(0xFFD97706), Color(0xFFDB2777),
  ];

  Color get _accent => _accents[widget.cat.id % _accents.length];

  @override
  Widget build(BuildContext context) {
    final cat = widget.cat;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: (_open ? _accent : Colors.black).withOpacity(_open ? 0.12 : 0.04),
          blurRadius: _open ? 18 : 8,
          offset: const Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────
          InkWell(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _open = !_open); },
            child: Container(
              decoration: BoxDecoration(
                gradient: _open
                  ? LinearGradient(
                      colors: [_accent.withOpacity(0.08), _white],
                      begin: Alignment.centerLeft, end: Alignment.centerRight)
                  : null,
                color: _open ? null : _white,
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Coloured left accent bar
                Container(width: 4, height: 64, color: _accent),
                const SizedBox(width: 14),
                // Icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(13)),
                  child: Icon(Icons.category_outlined, size: 22, color: _accent)),
                const SizedBox(width: 12),
                // Name + count
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cat.name, style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: _open ? _accent : _navy)),
                  const SizedBox(height: 2),
                  Text('${cat.items.length} item${cat.items.length == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(fontSize: 12,
                        color: _grey, fontWeight: FontWeight.w500)),
                ])),
                // Edit
                _ActionBtn(Icons.edit_outlined, _grey,
                    onTap: widget.onEdit),
                // Delete
                _ActionBtn(Icons.delete_outline,
                    const Color(0xFFEF4444), onTap: widget.onDelete),
                // Expand
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: _open ? _accent : _grey, size: 22)),
                ),
              ]),
            ),
          ),
          // ── Expanded items ───────────────────────────────────────────────
          if (_open) ...[
            Container(height: 1, color: _accent.withOpacity(0.15)),
            ...cat.items.asMap().entries.map((e) => _ItemRow(
                item: e.value,
                accent: _accent,
                onEdit: () => widget.onEditItem(e.value),
                onDelete: () => widget.onDeleteItem(e.value),
                index: e.key,
                isLast: e.key == cat.items.length - 1)),
            // Add item
            InkWell(
              onTap: widget.onAddItem,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.04)),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.add_rounded, size: 16, color: _accent)),
                  const SizedBox(width: 12),
                  Text('Add item', style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _accent)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Single item row ───────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final _TplItem item;
  final Color accent;
  final VoidCallback onEdit, onDelete;
  final bool isLast;
  final int index;
  const _ItemRow({required this.item, required this.accent,
      required this.onEdit, required this.onDelete,
      required this.isLast, required this.index});

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
      child: Row(children: [
        // Number badge
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(7)),
          child: Center(child: Text('${index + 1}',
            style: GoogleFonts.inter(fontSize: 11,
                fontWeight: FontWeight.w800, color: accent))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(item.label, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w500, color: _navy))),
        _ActionBtn(Icons.edit_outlined, _grey, onTap: onEdit, size: 16),
        _ActionBtn(Icons.remove_circle_outline,
            const Color(0xFFEF4444), onTap: onDelete, size: 16),
      ]),
    ),
    if (!isLast)
      Container(height: 1,
          margin: const EdgeInsets.only(left: 56, right: 16),
          color: _border),
  ]);
}

// ── Reusable small action button ──────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  const _ActionBtn(this.icon, this.color,
      {required this.onTap, this.size = 18});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Icon(icon, size: size, color: color)),
  );
}

// ── Header stat chip ──────────────────────────────────────────────────────────
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _HeaderChip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.30))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

// ── Dialogs ───────────────────────────────────────────────────────────────────
Future<Map<String, String>?> _showCategoryDialog(BuildContext context,
    {_TplCategory? initial}) async {
  final nameCtrl = TextEditingController(text: initial?.name ?? '');
  String selectedIcon = initial?.icon ?? 'checklist_rounded';
  final icons = <String, IconData>{
    'checklist_rounded':           Icons.checklist_rounded,
    'tire_repair':                 Icons.tire_repair,
    'wb_sunny_outlined':           Icons.wb_sunny_outlined,
    'settings_outlined':           Icons.settings_outlined,
    'directions_bus_outlined':     Icons.directions_bus_outlined,
    'airline_seat_recline_normal': Icons.airline_seat_recline_normal,
    'local_shipping_rounded':      Icons.local_shipping_rounded,
    'warning_amber_rounded':       Icons.warning_amber_rounded,
    'fire_extinguisher':           Icons.fire_extinguisher,
    'build_outlined':              Icons.build_outlined,
    'electrical_services':         Icons.electrical_services,
    'water_damage_outlined':       Icons.water_damage_outlined,
  };

  return await showDialog<Map<String, String>?>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(initial == null ? 'Add Category' : 'Edit Category',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _navy)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: 'Category name',
            labelStyle: GoogleFonts.inter(color: _grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _blue, width: 2)),
          ),
        ),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerLeft,
          child: Text('Icon', style: GoogleFonts.inter(fontSize: 12,
              fontWeight: FontWeight.w600, color: _grey))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: icons.entries.map((e) =>
          GestureDetector(
            onTap: () => setS(() => selectedIcon = e.key),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: selectedIcon == e.key ? _blue.withOpacity(0.12) : _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selectedIcon == e.key ? _blue : _border,
                  width: selectedIcon == e.key ? 2 : 1)),
              child: Icon(e.value, size: 22,
                  color: selectedIcon == e.key ? _blue : _grey),
            ),
          )).toList()),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: _grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            if (nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(ctx, {'name': nameCtrl.text.trim(), 'icon': selectedIcon});
          },
          child: Text('Save', style: GoogleFonts.inter(
              fontWeight: FontWeight.w700, color: _white)),
        ),
      ],
    )),
  );
}

Future<String?> _showItemDialog(BuildContext context, {String? initial}) async {
  final ctrl = TextEditingController(text: initial ?? '');
  return await showDialog<String?>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(initial == null ? 'Add Item' : 'Edit Item',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _navy)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Item label',
          labelStyle: GoogleFonts.inter(color: _grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _blue, width: 2)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: _grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: Text('Save', style: GoogleFonts.inter(
              fontWeight: FontWeight.w700, color: _white)),
        ),
      ],
    ),
  );
}

// ── Data models ───────────────────────────────────────────────────────────────
class _TplCategory {
  final int id;
  final String name;
  final String icon;
  final List<_TplItem> items;
  _TplCategory({required this.id, required this.name,
      required this.icon, required this.items});
  factory _TplCategory.fromJson(Map j) => _TplCategory(
    id: j['id'] as int,
    name: j['name'] as String? ?? '',
    icon: j['icon'] as String? ?? 'checklist_rounded',
    items: (j['items'] as List? ?? []).map((i) => _TplItem.fromJson(i)).toList(),
  );
}

class _TplItem {
  final int id;
  final String label;
  _TplItem({required this.id, required this.label});
  factory _TplItem.fromJson(Map j) =>
      _TplItem(id: j['id'] as int, label: j['label'] as String? ?? '');
}
