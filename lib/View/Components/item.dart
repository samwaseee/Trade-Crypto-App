import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/theme/app_theme.dart';
import 'package:my_crypto/utils/format.dart';
import 'package:my_crypto/utils/pnl.dart';

class Item extends StatelessWidget {
  final dynamic item;
  final dynamic transaction;

  const Item({super.key, this.item, this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tradingColors = theme.extension<TradingColors>()!;

    final type = transaction['type'];
    if (type != 'Buy' && type != 'Sell') {
      return const SizedBox.shrink();
    }

    final entryPrice = (transaction['price'] as num?)?.toDouble() ?? 0.0;
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final currentPrice = (item.currentPrice as num?)?.toDouble() ?? 0.0;

    final profit = computePnl(
      type: type as String,
      entryPrice: entryPrice,
      currentPrice: currentPrice,
      amount: amount,
    );
    final positionCost =
        (transaction['cost'] as num?)?.toDouble() ?? (entryPrice * amount);
    final plPercent = positionCost == 0.0 ? 0.0 : (profit / positionCost) * 100;
    final isPlPositive = plPercent >= 0;
    final plPercentStr =
        '${isPlPositive ? '+' : ''}${plPercent.toStringAsFixed(2)}%';

    final isZero = profit.abs() < 0.005;
    final isPositive = profit >= 0;

    final profitColor = isZero
        ? colorScheme.onSurfaceVariant
        : (isPositive ? tradingColors.gain : tradingColors.loss);
    final profitBgColor = isZero
        ? colorScheme.surfaceContainerHighest
        : profitColor.withValues(alpha: 0.12);
    final profitMarker = isZero
        ? '• '
        : isPositive
            ? '▲ '
            : '▼ ';
    final percentMarker = isZero
        ? '• '
        : isPlPositive
            ? '▲ '
            : '▼ ';

    return Semantics(
      excludeSemantics: true,
      label:
          '${item.name}, ${tradeLabel(type)}, P/L ${formatSignedUsd(profit)}, $plPercentStr',
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Image.network(
                  item.image,
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.symbol.toUpperCase(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tradeLabel(type),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${transaction['amount'].toStringAsFixed(2)} @ \$${formatUsd(transaction['price'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: profitBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$profitMarker${formatSignedUsd(profit)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: profitColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '\$${formatUsd(item.currentPrice)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: profitBgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$percentMarker$plPercentStr',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: profitColor,
                          ),
                        ),
                      ),
                    ],
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
