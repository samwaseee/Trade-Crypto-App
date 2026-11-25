import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/Model/coinModel.dart';
import 'package:my_crypto/View/selectCoin.dart';
import 'package:my_crypto/theme/app_theme.dart';
import 'package:my_crypto/utils/format.dart';

/// Modern "Recommend to Buy" card.
///
/// Layout (top→bottom inside a 210 × 194 card):
///  ┌─ header ──────────────────────────────────────────┐
///  │  [coin logo]   [name · #rank]        [+5.4% pill] │
///  ├─ price row ───────────────────────────────────────┤
///  │  $62,340.00                 24h: ▲ $1,230         │
///  ├─ 7d sparkline ────────────────────────────────────┤
///  │  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~              │
///  ├─ stats row ───────────────────────────────────────┤
///  │  L $61k    H $65k    Vol $24B                     │
///  └───────────────────────────────────────────────────┘
class Item2 extends StatelessWidget {
  final CoinModel item;

  const Item2({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tc = theme.extension<TradingColors>()!;

    final pct = item.marketCapChangePercentage24H;
    final isPositive = pct >= 0;
    final changeColor = isPositive ? tc.gain : tc.loss;

    // 7-day sparkline
    final sparkPrices = item.sparklineIn7D.price;
    final hasSpark = sparkPrices.length >= 2;
    final sparkUp = hasSpark && sparkPrices.last >= sparkPrices.first;
    final sparkColor = hasSpark ? (sparkUp ? tc.gain : tc.loss) : changeColor;

    // High-low range bar fill (how far current price sits in the 24h range)
    final rangeFill = (item.high24H - item.low24H) == 0
        ? 0.5
        : ((item.currentPrice - item.low24H) / (item.high24H - item.low24H)).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SelectCoin(selectItem: item)),
      ),
      child: Container(
        width: 210,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sparkColor.withValues(alpha: 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: sparkColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.surfaceContainerHighest,
                    ),
                    child: ClipOval(
                      child: Image.network(
                        item.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.currency_bitcoin, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name + rank
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              item.symbol.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            if (item.marketCapRank > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${item.marketCapRank}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 24h % pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          size: 14,
                          color: changeColor,
                        ),
                        Text(
                          '${pct.abs().toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: changeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Current price + 24h absolute change ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '\$${formatUsd(item.currentPrice)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${item.priceChange24H >= 0 ? '+' : ''}\$${formatUsd(item.priceChange24H.abs())}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: changeColor,
                    ),
                  ),
                ],
              ),
            ),

            // ── 7-day sparkline ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
              child: hasSpark
                  ? SizedBox(
                      height: 44,
                      child: Sparkline(
                        data: sparkPrices,
                        lineWidth: 2.2,
                        lineColor: sparkColor,
                        pointsMode: PointsMode.last,
                        pointSize: 5.0,
                        pointColor: sparkColor,
                        useCubicSmoothing: true,
                        fillMode: FillMode.below,
                        fillGradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            sparkColor.withValues(alpha: 0.28),
                            sparkColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(height: 44),
            ),

            // ── Low / High range bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'L \$${_compact(item.low24H)}',
                        style: TextStyle(
                            fontSize: 10,
                            color: tc.loss,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '24h range',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'H \$${_compact(item.high24H)}',
                        style: TextStyle(
                            fontSize: 10,
                            color: tc.gain,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _RangeBar(fill: rangeFill, gainColor: tc.gain, lossColor: tc.loss),
                ],
              ),
            ),

            // ── Volume footer ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.bar_chart, size: 12, color: cs.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    'Vol  \$${_compact(item.totalVolume)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  const Spacer(),
                  // Tap hint arrow
                  Icon(Icons.chevron_right, size: 14, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact number formatter: 24,300,000 → "24.3M", 1,420 → "1.4K".
  static String _compact(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return formatUsd(v);
  }
}

// ── Gradient low-to-high range bar ───────────────────────────────────────────
class _RangeBar extends StatelessWidget {
  final double fill; // 0.0 (at low) → 1.0 (at high)
  final Color gainColor;
  final Color lossColor;

  const _RangeBar({
    required this.fill,
    required this.gainColor,
    required this.lossColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const barH = 5.0;
        const dotR = 5.0;

        return SizedBox(
          height: dotR * 2,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Track
              Container(
                height: barH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(barH / 2),
                  gradient: LinearGradient(
                    colors: [lossColor.withValues(alpha: 0.5), gainColor.withValues(alpha: 0.5)],
                  ),
                ),
              ),
              // Current-price dot
              Positioned(
                left: (w * fill - dotR).clamp(0.0, w - dotR * 2),
                child: Container(
                  width: dotR * 2,
                  height: dotR * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(lossColor, gainColor, fill)!,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
