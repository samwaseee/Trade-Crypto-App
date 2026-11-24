import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:my_crypto/Model/coinModel.dart';
import 'package:my_crypto/View/selectCoin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/utils/format.dart';

class CoinTile extends StatelessWidget {
  final CoinModel coin;
  final int? rank;

  const CoinTile({super.key, required this.coin, this.rank});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isZero = coin.marketCapChangePercentage24H.abs() < 0.005;
    final isPositive = coin.marketCapChangePercentage24H >= 0;
    final changeColor = isZero
        ? colorScheme.onSurfaceVariant
        : (isPositive ? Colors.green : Colors.red);
    final changeBgColor = isZero
        ? colorScheme.surfaceContainerHighest
        : changeColor.withValues(alpha: 0.12);

    final sparklinePrices = coin.sparklineIn7D.price;
    final Color sparklineColor;
    if (sparklinePrices.length < 2) {
      sparklineColor = colorScheme.onSurfaceVariant;
    } else if (sparklinePrices.last >= sparklinePrices.first) {
      sparklineColor = Colors.green;
    } else {
      sparklineColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SelectCoin(selectItem: coin),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showSparkline = constraints.maxWidth >= 330 && sparklinePrices.isNotEmpty;

              return Row(
                children: [
                  if (rank != null) ...[
                    SizedBox(
                      width: 28,
                      child: Text(
                        '#$rank',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Image.network(
                      coin.image,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.currency_bitcoin, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                coin.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              coin.symbol.toUpperCase(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${formatUsd(coin.currentPrice)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showSparkline) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      height: 30,
                      child: Sparkline(
                        data: sparklinePrices,
                        lineWidth: 1.5,
                        lineColor: sparklineColor,
                        fillMode: FillMode.below,
                        fillGradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.7],
                          colors: [
                            sparklineColor,
                            sparklineColor.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ] else ...[
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: changeBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${isPositive && !isZero ? '+' : ''}${coin.marketCapChangePercentage24H.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
