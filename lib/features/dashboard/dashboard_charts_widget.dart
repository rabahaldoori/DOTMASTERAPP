import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/api_client.dart';

/// Dark-themed dual area charts for the dashboard.
/// Drop this into DashboardScreen's body: `const DashboardChartsWidget()`
class DashboardChartsWidget extends StatefulWidget {
  const DashboardChartsWidget({super.key});

  @override
  State<DashboardChartsWidget> createState() => _DashboardChartsWidgetState();
}

class _DashboardChartsWidgetState extends State<DashboardChartsWidget> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _dailyTrips = [];
  List<Map<String, dynamic>> _dailyFuel  = [];

  int    _totalTrips   = 0;
  double _totalMiles   = 0;
  double _totalCost    = 0;
  double _totalGallons = 0;

  @override
  void initState() {
    super.initState();
    _loadCharts();
  }

  Future<void> _loadCharts() async {
    try {
      final res = await ApiClient.getDashboardCharts();
      final data = res.data as Map<String, dynamic>;

      final trips = (data['daily_trips'] as List).cast<Map<String, dynamic>>();
      final fuels = (data['daily_fuel']  as List).cast<Map<String, dynamic>>();

      int    tTrips = 0;
      double tMiles = 0, tCost = 0, tGal = 0;
      for (final r in trips) {
        tTrips += (r['count'] as num).toInt();
        tMiles += (r['miles'] as num).toDouble();
      }
      for (final r in fuels) {
        tCost += (r['cost']    as num).toDouble();
        tGal  += (r['gallons'] as num).toDouble();
      }

      if (!mounted) return;
      setState(() {
        _dailyTrips   = trips;
        _dailyFuel    = fuels;
        _totalTrips   = tTrips;
        _totalMiles   = tMiles;
        _totalCost    = tCost;
        _totalGallons = tGal;
        _loading      = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildSkeleton();
    if (_error != null) return const SizedBox.shrink();

    return Column(
      children: [
        _ChartCard(
          title: 'Trips Activity',
          subtitle: 'Last 30 Days',
          accentColor: const Color(0xFF60A5FA),
          secondColor: const Color(0xFF34D399),
          glowColor:   const Color(0xFF3B82F6),
          legend1: 'Trips',
          legend2: 'Miles',
          stat1Label: 'Total Trips',
          stat1Value: _totalTrips.toString(),
          stat1Color: const Color(0xFF60A5FA),
          stat2Label: 'Total Miles',
          stat2Value: '${_commas(_totalMiles.round())} mi',
          stat2Color: const Color(0xFF34D399),
          spots1: _normalize(_toSpots(_dailyTrips, 'count')),
          spots2: _normalize(_toSpots(_dailyTrips, 'miles')),
          labels: _dateLabels(_dailyTrips),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Fuel Expenses',
          subtitle: 'Last 30 Days',
          accentColor: const Color(0xFFFBBF24),
          secondColor: const Color(0xFFF87171),
          glowColor:   const Color(0xFFF59E0B),
          legend1: 'Cost (\$)',
          legend2: 'Gallons',
          stat1Label: 'Total Spent',
          stat1Value: '\$${_totalCost.toStringAsFixed(2)}',
          stat1Color: const Color(0xFFFBBF24),
          stat2Label: 'Gallons',
          stat2Value: '${_commas(_totalGallons.round())} gal',
          stat2Color: const Color(0xFFF87171),
          spots1: _normalize(_toSpots(_dailyFuel, 'cost')),
          spots2: _normalize(_toSpots(_dailyFuel, 'gallons')),
          labels: _dateLabels(_dailyFuel),
        ),
      ],
    );
  }

  List<FlSpot> _toSpots(List<Map<String, dynamic>> data, String key) =>
      List.generate(data.length, (i) =>
          FlSpot(i.toDouble(), (data[i][key] as num).toDouble()));

  /// Scale a series to 0–100 so two datasets with different magnitudes
  /// (e.g. trip counts 0–10 and miles 0–10 000) can share one Y axis.
  List<FlSpot> _normalize(List<FlSpot> spots) {
    if (spots.isEmpty) return spots;
    final maxVal = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return spots.map((s) => FlSpot(s.x, 0)).toList();
    return spots.map((s) => FlSpot(s.x, (s.y / maxVal) * 100)).toList();
  }

  List<String> _dateLabels(List<Map<String, dynamic>> data) =>
      data.map((r) {
        final p = (r['date'] as String).split('-');
        return _shortDate(DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])));
      }).toList();

  String _shortDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }

  String _commas(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _buildSkeleton() => Column(
    children: [
      _SkeletonCard(),
      const SizedBox(height: 16),
      _SkeletonCard(),
    ],
  );
}

// ── Chart Card ───────────────────────────────────────────────────────────────
class _ChartCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String legend1;
  final String legend2;
  final String stat1Label;
  final String stat1Value;
  final String stat2Label;
  final String stat2Value;
  final Color  accentColor;
  final Color  secondColor;
  final Color  glowColor;
  final Color  stat1Color;
  final Color  stat2Color;
  final List<FlSpot> spots1;
  final List<FlSpot> spots2;
  final List<String> labels;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.legend1,
    required this.legend2,
    required this.stat1Label,
    required this.stat1Value,
    required this.stat2Label,
    required this.stat2Value,
    required this.accentColor,
    required this.secondColor,
    required this.glowColor,
    required this.stat1Color,
    required this.stat2Color,
    required this.spots1,
    required this.spots2,
    required this.labels,
  });

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  // Spots are pre-normalized to 0-100, so Y axis is always fixed.
  static const double _maxY = 100;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020F25), Color(0xFF031634), Color(0xFF071E45)],
            stops: [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: widget.glowColor.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.title, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14,
                      )),
                      const SizedBox(height: 2),
                      Text(widget.subtitle, style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 11,
                      )),
                    ]),
                    Row(children: [
                      _Legend(color: widget.accentColor, label: widget.legend1),
                      const SizedBox(width: 12),
                      _Legend(color: widget.secondColor, label: widget.legend2),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // ── Chart ────────────────────────────────────────────────────
              SizedBox(
                height: 160,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: _maxY / 4,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.white.withOpacity(0.05), strokeWidth: 1,
                        ),
                        drawVerticalLine: false,
                      ),
                      titlesData: FlTitlesData(
                        // Y labels hidden — values are normalized 0-100; real numbers shown below.
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true,
                          interval: (widget.labels.length / 6).ceilToDouble(),
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= widget.labels.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(widget.labels[i],
                                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9)),
                            );
                          },
                        )),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF020F25).withOpacity(0.95),
                          tooltipRoundedRadius: 10,
                        ),
                      ),
                      lineBarsData: [
                        _line(widget.spots1, widget.accentColor),
                        _line(widget.spots2, widget.secondColor),
                      ],
                      minY: 0,
                      maxY: _maxY,
                    ),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
              // ── Stats ────────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(children: [
                  Expanded(child: _Stat(
                    label: widget.stat1Label,
                    value: widget.stat1Value,
                    color: widget.stat1Color,
                  )),
                  Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
                  Expanded(child: _Stat(
                    label: widget.stat2Label,
                    value: widget.stat2Value,
                    color: widget.stat2Color,
                  )),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots,
    isCurved: true,
    curveSmoothness: 0.35,
    color: color,
    barWidth: 2,
    isStrokeCapRound: true,
    dotData: FlDotData(
      show: true,
      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
        radius: 3, color: color, strokeWidth: 0, strokeColor: Colors.transparent,
      ),
    ),
    belowBarData: BarAreaData(
      show: true,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.30), color.withOpacity(0.00)],
      ),
    ),
  );


}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 2, decoration: BoxDecoration(
      color: color, borderRadius: BorderRadius.circular(2),
    )),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  ]);
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 3),
    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
  ]);
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 270,
    decoration: BoxDecoration(
      color: const Color(0xFF020F25),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
  );
}
