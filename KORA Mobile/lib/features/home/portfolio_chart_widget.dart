import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kora/core/services/portfolio_chart_service.dart';
import 'package:kora/core/state/providers/currency_provider.dart';
import 'package:kora/core/state/providers/portfolio_chart_provider.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';

class PortfolioChartWidget extends ConsumerStatefulWidget {
  const PortfolioChartWidget({super.key});

  @override
  ConsumerState<PortfolioChartWidget> createState() =>
      _PortfolioChartWidgetState();
}

class _PortfolioChartWidgetState extends ConsumerState<PortfolioChartWidget>
    with SingleTickerProviderStateMixin, ThemeAwareMixin {
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  // Touch state
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period    = ref.watch(chartPeriodProvider);
    final walletId  = ref.watch(currentWalletProvider).value?.id ?? '';
    final chartAsync = ref.watch(portfolioChartProvider((period, walletId)));
    final currency  = ref.watch(currencyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart body + tooltip overlay
        SizedBox(
          height: 120,
          child: chartAsync.when(
            loading: () => _buildSkeleton(),
            error:   (_, __) => _buildSkeleton(),
            data: (points) {
              if (points.isEmpty) {
                return _buildSkeleton();
              }
              // Show flat line when all values are zero
              if (points.every((p) => p.value == 0)) {
                return _buildFlatLineChart(points.length);
              }
              return Stack(
                children: [
                  _buildChart(points, currency, period),
                  // Tooltip — appears at top-center when a point is touched
                  if (_touchedIndex != null &&
                      _touchedIndex! < points.length)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildTooltip(
                        points[_touchedIndex!],
                        currency,
                        period,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Period selector
        _PeriodSelector(
          selected: period,
          onSelect: (p) {
            ref.read(chartPeriodProvider.notifier).state = p;
            setState(() { _touchedIndex = null; });
            _animCtrl.forward(from: 0);
          },
        ),
      ],
    );
  }

  Widget _buildTooltip(
      ChartPoint point, CurrencyState currency, ChartPeriod period) {
    final dateStr = _formatDate(point.time, period);
    final valueStr = currency.formatTotal(point.value);
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
              Text(
                dateStr,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                valueStr,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime time, ChartPeriod period) {
    switch (period) {
      case ChartPeriod.day:
        return DateFormat('HH:mm').format(time);
      case ChartPeriod.week:
        return DateFormat('EEE, MMM d').format(time);
      case ChartPeriod.month:
        return DateFormat('MMM d').format(time);
      case ChartPeriod.sixMonths:
        return DateFormat('MMM d').format(time);
      case ChartPeriod.year:
        return DateFormat('MMM yyyy').format(time);
    }
  }

  Widget _buildChart(
      List<ChartPoint> points, CurrencyState currency, ChartPeriod period) {
    final values   = points.map((p) => p.value).toList();
    final minY     = values.reduce((a, b) => a < b ? a : b);
    final maxY     = values.reduce((a, b) => a > b ? a : b);
    final range    = (maxY - minY).clamp(0.01, double.infinity);
    final paddingY = range * 0.15;

    final isUp      = values.last >= values.first;
    final chartColor = isUp ? AppColors.positive : AppColors.negative;

    final spots = List.generate(
        points.length, (i) => FlSpot(i.toDouble(), values[i]));

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final cutoff = (_anim.value * spots.length)
            .round()
            .clamp(2, spots.length);
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
              // Hide fl_chart's own tooltip — we render our own overlay
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
                      getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(
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

  Widget _buildFlatLineChart(int pointCount) {
    // Create a flat line at y=0 for zero balance
    final spots = List.generate(
      pointCount.clamp(2, 170),
      (i) => FlSpot(i.toDouble(), 0),
    );

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final cutoff = (_anim.value * spots.length)
            .round()
            .clamp(2, spots.length);
        final visibleSpots = spots.sublist(0, cutoff);

        return LineChart(
          LineChartData(
            minX: 0,
            maxX: (spots.length - 1).toDouble(),
            minY: -0.1,
            maxY: 0.1,
            clipData: const FlClipData.all(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: visibleSpots,
                isCurved: false,
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.textSecondary.withValues(alpha: 0.08),
                      AppColors.textSecondary.withValues(alpha: 0.0),
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

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: CustomPaint(
        size: const Size(double.infinity, 120),
        painter: _SkeletonPainter(AppColors.surface),
      ),
    );
  }
}

// ─── Period Selector ─────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelect});
  final ChartPeriod selected;
  final ValueChanged<ChartPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ChartPeriod.values.map((p) {
        final isSelected = p == selected;
        return AnimatedTap(
          onTap: () => onSelect(p),
          pressScale: 0.88,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              p.label,
              style: TextStyle(
                color: isSelected ? AppColors.background : AppColors.textSecondary,
                fontSize: 13,
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
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const segments = 8;
    final w = size.width / segments;

    // Draw a static flat wave as placeholder
    path.moveTo(0, size.height * 0.6);
    for (int i = 0; i <= segments; i++) {
      final x = i * w;
      final y = size.height * (0.5 + 0.1 * (i % 2 == 0 ? 1 : -1));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint..color = color.withValues(alpha: 0.4));
  }

  @override
  bool shouldRepaint(_) => false;
}
