import 'package:material_ui/material_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../Model/chartModel.dart';
import '../../theme/app_theme.dart';
import '../../utils/indicators.dart';
import '../../utils/trend_signal.dart';
import 'state_widgets.dart';

class OutlookCard extends StatelessWidget {
  const OutlookCard({
    super.key,
    required this.chartData,
    required this.isLoading,
    required this.hasError,
    required this.timeframe,
  });

  final List<ChartModel>? chartData;
  final bool isLoading;
  final bool hasError;
  final String timeframe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TradingColors>()!;
    final signal = computeTrendSignal(chartData ?? const []);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Technical outlook',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(timeframe),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Rule-based indicators on past prices. Not AI, not financial advice, no guarantee.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const _OutlookLoading()
            else if (hasError)
              _OutlookError(theme: theme)
            else if (signal.outlook == TrendOutlook.insufficientData)
              const SizedBox(
                height: 150,
                child: EmptyState(
                  message: 'Not enough price history for this timeframe',
                  icon: Icons.show_chart_rounded,
                ),
              )
            else ...[
              _OutlookGauge(signal: signal, colors: colors, theme: theme),
              const SizedBox(height: 16),
              for (final indicator in signal.indicators)
                _IndicatorRow(
                  indicator: indicator,
                  colors: colors,
                  theme: theme,
                ),
              const SizedBox(height: 12),
              _ChartLegend(colors: colors, theme: theme),
              const SizedBox(height: 4),
              SizedBox(
                height: 210,
                child: _OutlookChart(
                  chartData: chartData ?? const [],
                  colors: colors,
                  theme: theme,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutlookLoading extends StatelessWidget {
  const _OutlookLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonShimmer(height: 18),
        SizedBox(height: 12),
        SkeletonShimmer(height: 54, borderRadius: 12),
        SizedBox(height: 12),
        SkeletonShimmer(height: 160, borderRadius: 12),
      ],
    );
  }
}

class _OutlookError extends StatelessWidget {
  const _OutlookError({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
          const SizedBox(height: 8),
          Text(
            'Technical outlook unavailable',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _OutlookGauge extends StatelessWidget {
  const _OutlookGauge({
    required this.signal,
    required this.colors,
    required this.theme,
  });

  final TrendSignal signal;
  final TradingColors colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final direction = signal.bullishCount > signal.bearishCount
        ? Vote.bullish
        : signal.bearishCount > signal.bullishCount
            ? Vote.bearish
            : Vote.neutral;
    final color = _voteColor(direction, colors);
    final icon = _voteIcon(direction);
    final label = direction == Vote.bullish
        ? '${signal.bullishCount} of ${signal.validCount} indicators lean bullish'
        : direction == Vote.bearish
            ? '${signal.bearishCount} of ${signal.validCount} indicators lean bearish'
            : '${signal.bullishCount} bullish, ${signal.bearishCount} bearish of ${signal.validCount} indicators';
    final sentiment =
        (signal.bullishCount - signal.bearishCount) / signal.validCount;
    final position = (0.5 + sentiment / 2).clamp(0.04, 0.96);
    final signalLabel = _outlookLabel(signal.outlook);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$signalLabel · $label',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final markerLeft =
                (constraints.maxWidth - 20) * position.toDouble();
            return SizedBox(
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors.loss.withValues(alpha: 0.25),
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Container(
                          height: 12,
                          color: colors.warning.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors.gain.withValues(alpha: 0.25),
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    left: markerLeft,
                    top: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Icon(icon, size: 13, color: color),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _GaugeLabel(
                label: 'Bearish',
                color: colors.loss,
                alignment: TextAlign.left,
              ),
            ),
            Expanded(
              child: _GaugeLabel(
                label: 'Mixed',
                color: colors.warning,
                alignment: TextAlign.center,
              ),
            ),
            Expanded(
              child: _GaugeLabel(
                label: 'Bullish',
                color: colors.gain,
                alignment: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GaugeLabel extends StatelessWidget {
  const _GaugeLabel({
    required this.label,
    required this.color,
    required this.alignment,
  });

  final String label;
  final Color color;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: alignment,
      style: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow({
    required this.indicator,
    required this.colors,
    required this.theme,
  });

  final IndicatorResult indicator;
  final TradingColors colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final vote = indicator.vote;
    final label = vote == null
        ? 'Not enough data'
        : vote == Vote.bullish
            ? 'Bullish'
            : vote == Vote.bearish
                ? 'Bearish'
                : 'Neutral';
    final color = vote == null
        ? theme.colorScheme.onSurfaceVariant
        : _voteColor(vote, colors);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                indicator.name,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              _VoteChip(
                label: label,
                icon: vote == null ? Icons.help_outline : _voteIcon(vote),
                color: color,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            indicator.value,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _VoteChip extends StatelessWidget {
  const _VoteChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final Color color;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.colors, required this.theme});

  final TradingColors colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _LegendEntry(label: 'Close', color: theme.colorScheme.accent),
        _LegendEntry(label: 'SMA 10', color: colors.gain),
        _LegendEntry(label: 'SMA 30', color: colors.loss),
        _LegendEntry(label: 'Bollinger', color: colors.warning),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _OutlookChart extends StatelessWidget {
  const _OutlookChart({
    required this.chartData,
    required this.colors,
    required this.theme,
  });

  final List<ChartModel> chartData;
  final TradingColors colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final points = <_OutlookPoint>[];
    final closes = <double>[];
    final candles = chartData.where((candle) {
      final close = candle.close;
      return close != null && close.isFinite && close > 0;
    });

    for (final candle in candles) {
      final close = candle.close!;
      closes.add(close);
      points.add(
        _OutlookPoint(
          time: DateTime.fromMillisecondsSinceEpoch(candle.time),
          close: close,
          sma10: sma(closes, 10),
          sma30: sma(closes, 30),
          bands: bollinger(closes),
        ),
      );
    }

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      primaryXAxis: const DateTimeAxis(
        isVisible: false,
        majorGridLines: MajorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        isVisible: true,
        opposedPosition: true,
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        majorGridLines: MajorGridLines(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 0.5,
        ),
        labelStyle: theme.textTheme.labelSmall,
      ),
      series: <CartesianSeries<_OutlookPoint, DateTime>>[
        RangeAreaSeries<_OutlookPoint, DateTime>(
          dataSource: points,
          xValueMapper: (point, _) => point.time,
          lowValueMapper: (point, _) => point.bands?.lower,
          highValueMapper: (point, _) => point.bands?.upper,
          color: colors.warning.withValues(alpha: 0.10),
          borderColor: colors.warning.withValues(alpha: 0.35),
          borderWidth: 1,
          animationDuration: 0,
        ),
        LineSeries<_OutlookPoint, DateTime>(
          dataSource: points,
          xValueMapper: (point, _) => point.time,
          yValueMapper: (point, _) => point.sma30,
          color: colors.loss,
          width: 1.5,
          animationDuration: 0,
        ),
        LineSeries<_OutlookPoint, DateTime>(
          dataSource: points,
          xValueMapper: (point, _) => point.time,
          yValueMapper: (point, _) => point.sma10,
          color: colors.gain,
          width: 1.5,
          animationDuration: 0,
        ),
        LineSeries<_OutlookPoint, DateTime>(
          dataSource: points,
          xValueMapper: (point, _) => point.time,
          yValueMapper: (point, _) => point.close,
          color: theme.colorScheme.accent,
          width: 2,
          animationDuration: 0,
        ),
      ],
    );
  }
}

class _OutlookPoint {
  const _OutlookPoint({
    required this.time,
    required this.close,
    required this.sma10,
    required this.sma30,
    required this.bands,
  });

  final DateTime time;
  final double close;
  final double? sma10;
  final double? sma30;
  final BollingerBands? bands;
}

Color _voteColor(Vote vote, TradingColors colors) => switch (vote) {
      Vote.bullish => colors.gain,
      Vote.bearish => colors.loss,
      Vote.neutral => colors.warning,
    };

IconData _voteIcon(Vote vote) => switch (vote) {
      Vote.bullish => Icons.arrow_upward_rounded,
      Vote.bearish => Icons.arrow_downward_rounded,
      Vote.neutral => Icons.trending_flat_rounded,
    };

String _outlookLabel(TrendOutlook outlook) => switch (outlook) {
      TrendOutlook.strongBullish => 'Strongly bullish',
      TrendOutlook.bullish => 'Bullish',
      TrendOutlook.mixed => 'Mixed',
      TrendOutlook.bearish => 'Bearish',
      TrendOutlook.strongBearish => 'Strongly bearish',
      TrendOutlook.insufficientData => 'Insufficient data',
    };
