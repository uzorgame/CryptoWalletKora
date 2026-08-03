import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kora/core/services/price_chart_service.dart';
import 'package:kora/core/state/providers/price_chart_provider.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/widgets/animated_tap.dart';

class TokenPriceChartWidget extends ConsumerStatefulWidget {
  const TokenPriceChartWidget({super.key, required this.symbol});
  final String symbol;

  @override
  ConsumerState<TokenPriceChartWidget> createState() =>
      _TokenPriceChartWidgetState();
}

class _TokenPriceChartWidgetState extends ConsumerState<TokenPriceChartWidget>
    with SingleTickerProviderStateMixin, ThemeAwareMixin {
  late AnimationController _animCtrl;
  late Animation<double> _anim;
  int? _touchedIndex;
  PriceChartPeriod _selectedPeriod = PriceChartPeriod.oneMonth;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (always visible, tappable)
          GestureDetector(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              if (_isExpanded) _animCtrl.forward(from: 0);
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(Icons.show_chart_rounded,
                    color: AppColors.textSecondary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Price History',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Expandable chart content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? _buildExpandedContent()
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    final chartAsync = ref.watch(
        tokenPriceChartProvider((widget.symbol, _selectedPeriod)));

    return Column(
      children: [
        const SizedBox(height: 12),

        // Chart body
        SizedBox(
          height: 140,
          child: chartAsync.when(
            loading: () => _buildSkeleton(),
            error: (_, __) => _buildSkeleton(),
            data: (points) {
              if (points.isEmpty) return _buildEmpty();
              return Stack(
                children: [
                  _buildChart(points),
                  if (_touchedIndex != null && _touchedIndex! < points.length)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildTooltip(points[_touchedIndex!]),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Period selector
        _PriceChartPeriodSelector(
          selected: _selectedPeriod,
          onSelect: (p) {
            setState(() {
              _selectedPeriod = p;
              _touchedIndex = null;
            });
            _animCtrl.forward(from: 0);
          },
        ),
      ],
    );
  }

  Widget _buildTooltip(PricePoint point) {
    final dateStr = _formatDate(point.timestamp, _selectedPeriod);
    final priceStr = _formatPrice(point.priceUsd);
    return Center(
      child: AnimatedOpacity(
        opacity: _touchedIndex != null ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dateStr,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400)),
              const SizedBox(width: 8),
              Text(priceStr,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime time, PriceChartPeriod period) {
    switch (period) {
      case PriceChartPeriod.oneWeek:
        return DateFormat('EEE, MMM d HH:mm').format(time);
      case PriceChartPeriod.oneMonth:
      case PriceChartPeriod.sixMonths:
        return DateFormat('MMM d').format(time);
      case PriceChartPeriod.oneYear:
        return DateFormat('MMM yyyy').format(time);
    }
  }

  String _formatPrice(double price) {
    if (price >= 1000) return '\$${NumberFormat('#,##0.00').format(price)}';
    if (price >= 1) return '\$${price.toStringAsFixed(2)}';
    if (price >= 0.01) return '\$${price.toStringAsFixed(4)}';
    return '\$${price.toStringAsFixed(6)}';
  }

  Widget _buildChart(List<PricePoint> points) {
    final values = points.map((p) => p.priceUsd).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).clamp(0.0001, double.infinity);
    final paddingY = range * 0.15;

    final isUp = values.last >= values.first;
    final chartColor = isUp ? AppColors.positive : AppColors.negative;

    final spots =
        List.generate(points.length, (i) => FlSpot(i.toDouble(), values[i]));

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final cutoff =
            (_anim.value * spots.length).round().clamp(2, spots.length);
        final visibleSpots = spots.sublist(0, cutoff);

        return LineChart(
          LineChartData(
            minX: 0,
            maxX: (spots.length - 1).toDouble(),
            minY: minY - paddingY,
            maxY: maxY + paddingY,
            clipData: const FlClipData.all(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: LineTouchData(
              enabled: true,
              touchCallback: (event, response) {
                final idx = response?.lineBarSpots?.firstOrNull?.spotIndex;
                if (event is FlTapUpEvent ||
                    event is FlLongPressEnd ||
                    event is FlPanEndEvent) {
                  setState(() => _touchedIndex = null);
                } else if (idx != null) {
                  setState(() => _touchedIndex = idx);
                }
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.transparent,
                tooltipPadding: EdgeInsets.zero,
                tooltipMargin: 0,
                getTooltipItems: (spots) => spots
                    .map((_) => const LineTooltipItem('', TextStyle()))
                    .toList(),
              ),
              getTouchedSpotIndicator: (barData, indices) {
                return indices.map((i) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: chartColor.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [4, 3],
                    ),
                    FlDotData(
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: chartColor,
                        strokeWidth: 2,
                        strokeColor: AppColors.card,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
            lineBarsData: [
              LineChartBarData(
                spots: visibleSpots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: chartColor,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      chartColor.withValues(alpha: 0.25),
                      chartColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: Duration.zero,
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart_rounded,
              color: AppColors.textTertiary, size: 32),
          const SizedBox(height: 8),
          Text('No price data available',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: CustomPaint(
        size: const Size(double.infinity, 140),
        painter: _SkeletonPainter(AppColors.surface),
      ),
    );
  }
}

// ─── Period Selector ──────────────────────────────────────────────────────────

class _PriceChartPeriodSelector extends StatelessWidget {
  const _PriceChartPeriodSelector(
      {required this.selected, required this.onSelect});
  final PriceChartPeriod selected;
  final ValueChanged<PriceChartPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: PriceChartPeriod.values.map((p) {
        final isSelected = p == selected;
        return AnimatedTap(
          onTap: () => onSelect(p),
          pressScale: 0.88,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              p.label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.background
                    : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Skeleton Painter ─────────────────────────────────────────────────────────

class _SkeletonPainter extends CustomPainter {
  final Color color;
  _SkeletonPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const segments = 8;
    final w = size.width / segments;

    for (int i = 0; i <= segments; i++) {
      final x = i * w;
      final y = size.height * (0.5 + 0.1 * (i % 2 == 0 ? 1 : -1));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
