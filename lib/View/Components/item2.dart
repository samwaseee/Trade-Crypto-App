import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/View/selectCoin.dart';
import 'package:my_crypto/utils/format.dart';

class Item2 extends StatelessWidget {
  final dynamic item;
  const Item2({super.key, this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = item.marketCapChangePercentage24H >= 0;
    final changeColor = isPositive ? Colors.green : Colors.red;

    final sparklinePrices = (item.sparklineIn7D?.price as List<num>?)?.map((e) => e.toDouble()).toList() ?? [];
    final Color sparklineColor;
    if (sparklinePrices.length < 2) {
      sparklineColor = changeColor;
    } else if (sparklinePrices.last >= sparklinePrices.first) {
      sparklineColor = Colors.green;
    } else {
      sparklineColor = Colors.red;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SelectCoin(selectItem: item)),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Container(
          width: 165,
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Image.network(
                      item.image,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.currency_bitcoin, size: 28),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive ? Icons.trending_up : Icons.trending_down,
                          size: 12,
                          color: changeColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${isPositive ? '+' : ''}${item.marketCapChangePercentage24H.toStringAsFixed(1)}%',
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
              const SizedBox(height: 4),
              if (sparklinePrices.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: sparklineColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sparklineColor.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '7d trend',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            sparklinePrices.last >= sparklinePrices.first ? '▲ High' : '▼ Low',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: sparklineColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 28,
                        child: Sparkline(
                          data: sparklinePrices,
                          lineWidth: 2.0,
                          lineColor: sparklineColor,
                          pointsMode: PointsMode.last,
                          pointSize: 4.0,
                          pointColor: sparklineColor,
                          useCubicSmoothing: true,
                          fillMode: FillMode.below,
                          fillGradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.9],
                            colors: [
                              sparklineColor.withValues(alpha: 0.25),
                              sparklineColor.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name ?? item.id,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${formatUsd(item.currentPrice)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
