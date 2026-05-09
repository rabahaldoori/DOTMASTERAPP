import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';

// ── Notification model ────────────────────────────────────────────────────────
class _Notif {
  final String id;
  final String type;    // 'trip' | 'hos' | 'cdl' | 'bol' | 'system'
  final String title;
  final String body;
  final DateTime createdAt;
  bool isRead;

  _Notif({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  factory _Notif.fromJson(Map j) => _Notif(
    id:        j['id']?.toString() ?? UniqueKey().toString(),
    type:      j['type'] as String? ?? 'system',
    title:     j['title'] as String? ?? 'Notification',
    body:      j['body'] ?? j['message'] as String? ?? '',
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    isRead:    j['is_read'] as bool? ?? false,
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class DriverNotificationsScreen extends StatefulWidget {
  const DriverNotificationsScreen({super.key});
  @override
  State<DriverNotificationsScreen> createState() => _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends State<DriverNotificationsScreen>
    with SingleTickerProviderStateMixin {

  List<_Notif> _notifs = [];
  bool _loading = true;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500))..forward();
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Try to fetch from backend
      final res = await ApiClient.getDriverData();
      final d = res.data as Map<String, dynamic>;
      final raw = d['notifications'] as List? ?? [];
      final fetched = raw.map((n) => _Notif.fromJson(n as Map)).toList();

      // Also generate smart local alerts from driver data
      final localAlerts = _buildLocalAlerts(d);

      setState(() {
        _notifs = [...localAlerts, ...fetched];
        _loading = false;
      });
    } catch (_) {
      setState(() { _loading = false; });
    }
    _fadeCtrl.reset();
    _fadeCtrl.forward();
  }

  /// Build smart local alerts from driver profile + trips
  List<_Notif> _buildLocalAlerts(Map<String, dynamic> d) {
    final list = <_Notif>[];
    final profile = d['profile'] as Map<String, dynamic>?;
    final trips   = List<Map>.from(d['trips'] ?? []);

    // CDL expiry
    final cdlStr = profile?['cdl_expiry'] as String?;
    if (cdlStr != null) {
      try {
        final diff = DateTime.parse(cdlStr).difference(DateTime.now()).inDays;
        if (diff <= 90) {
          list.add(_Notif(
            id: 'cdl_expiry',
            type: 'cdl',
            title: diff <= 0 ? '🚨 CDL Expired' : '⚠️ CDL Expiring Soon',
            body: diff <= 0
                ? 'Your CDL has expired. You may not drive until renewed.'
                : 'Your CDL expires in $diff days. Renew it before your next trip.',
            createdAt: DateTime.now(),
            isRead: false,
          ));
        }
      } catch (_) {}
    }

    // Trips missing BOL
    final inProgress = trips.where((t) =>
        (t['status'] as String? ?? '') == 'in_progress' &&
        t['bol_file'] == null).toList();
    for (final t in inProgress.take(3)) {
      list.add(_Notif(
        id: 'bol_${t['id']}',
        type: 'bol',
        title: '📄 BOL Missing',
        body: 'Trip ${t['reference_number'] ?? '#${t['id']}'} has no Bill of Lading. Upload it now.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
      ));
    }

    // Active trip reminder
    final active = trips.where((t) =>
        (t['status'] as String? ?? '') == 'in_progress').toList();
    if (active.isNotEmpty) {
      final t = active.first;
      list.add(_Notif(
        id: 'active_trip_${t['id']}',
        type: 'trip',
        title: '🚛 Trip In Progress',
        body: 'You have an active trip to ${t['destination_address'] ?? 'your destination'}. Stay safe!',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        isRead: true,
      ));
    }

    return list;
  }

  void _markAllRead() {
    setState(() {
      for (final n in _notifs) { n.isRead = true; }
    });
  }

  void _dismiss(String id) {
    setState(() => _notifs.removeWhere((n) => n.id == id));
  }

  int get _unreadCount => _notifs.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3FF),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            backgroundColor: const Color(0xFF031634),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(width: 32), // account for back button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notifications',
                          style: GoogleFonts.inter(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      if (_unreadCount > 0)
                        Text('$_unreadCount unread',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.white54)),
                    ],
                  ),
                  const Spacer(),
                  if (_unreadCount > 0)
                    GestureDetector(
                      onTap: _markAllRead,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text('Mark all read',
                            style: GoogleFonts.inter(
                                fontSize: 10, fontWeight: FontWeight.w600,
                                color: Colors.white70)),
                      ),
                    ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF031634), Color(0xFF0D2952)],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white70, size: 20),
                onPressed: _load,
                tooltip: 'Refresh',
              ),
            ],
          ),

          // ── Content ─────────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_notifs.isEmpty)
            SliverFillRemaining(child: _emptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final n = _notifs[i];
                    return FadeTransition(
                      opacity: _fadeCtrl,
                      child: _NotifCard(
                        notif: n,
                        onTap: () => setState(() => n.isRead = true),
                        onDismiss: () => _dismiss(n.id),
                      ),
                    );
                  },
                  childCount: _notifs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F3FF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD1D9F5)),
          ),
          child: const Icon(Icons.notifications_none_rounded,
              size: 36, color: Color(0xFF0453CD)),
        ),
        const SizedBox(height: 20),
        Text('All caught up!',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B))),
        const SizedBox(height: 8),
        Text('No notifications right now.\nCheck back after your next trip.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500],
                height: 1.5)),
      ],
    ),
  );
}

// ── Notification card ─────────────────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final _Notif notif;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _NotifCard({
    required this.notif,
    required this.onTap,
    required this.onDismiss,
  });

  Color get _accentColor => switch (notif.type) {
    'trip'   => const Color(0xFF0453CD),
    'hos'    => const Color(0xFFDC2626),
    'cdl'    => const Color(0xFFF97316),
    'bol'    => const Color(0xFF7C3AED),
    _        => const Color(0xFF64748B),
  };

  IconData get _icon => switch (notif.type) {
    'trip'   => Icons.local_shipping_outlined,
    'hos'    => Icons.schedule_rounded,
    'cdl'    => Icons.badge_outlined,
    'bol'    => Icons.description_outlined,
    _        => Icons.info_outline_rounded,
  };

  String get _timeLabel {
    final diff = DateTime.now().difference(notif.createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(notif.createdAt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead ? Colors.white : const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notif.isRead
                  ? const Color(0xFFE2E8F0)
                  : _accentColor.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(notif.isRead ? 0.03 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon badge
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: _accentColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(notif.title,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: notif.isRead
                              ? FontWeight.w600 : FontWeight.w800,
                          color: const Color(0xFF1E293B)))),
                  if (!notif.isRead)
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(notif.body,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[600], height: 1.4),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.access_time_rounded,
                      size: 11, color: Colors.grey[400]),
                  const SizedBox(width: 3),
                  Text(_timeLabel,
                      style: GoogleFonts.inter(
                          fontSize: 10, color: Colors.grey[400])),
                  const Spacer(),
                  // Type chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(notif.type.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: _accentColor, letterSpacing: 0.4)),
                  ),
                ]),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}
