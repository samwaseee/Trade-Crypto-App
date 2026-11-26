import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/Services/portfolio_repository.dart';
import 'package:my_crypto/View/Components/state_widgets.dart';
import 'package:my_crypto/theme/app_theme.dart';
import 'package:my_crypto/utils/format.dart';
import 'package:my_crypto/utils/pnl.dart';
import 'package:my_crypto/utils/trade_history.dart';

class TradeHistoryScreen extends StatefulWidget {
  const TradeHistoryScreen({
    super.key,
    required this.userId,
    this.repository,
  });

  final String userId;
  final PortfolioRepository? repository;

  @override
  State<TradeHistoryScreen> createState() => _TradeHistoryScreenState();
}

class _TradeHistoryScreenState extends State<TradeHistoryScreen> {
  late Stream<List<ClosedTrade>> _closedTrades;

  PortfolioRepository get _repository =>
      widget.repository ?? PortfolioRepository.instance;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _closedTrades = _repository.closedTradesStream(widget.userId);
  }

  void _retry() {
    setState(_subscribe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trade History')),
      body: StreamBuilder<List<ClosedTrade>>(
        stream: _closedTrades,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CoinListSkeleton();
          }
          if (snapshot.hasError) {
            return ErrorState(error: snapshot.error, onRetry: _retry);
          }
          if (!snapshot.hasData) {
            return const CoinListSkeleton();
          }

          final trades = snapshot.data!;
          final summary = summarizeClosedTrades(trades);
          if (trades.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _ClosedTradeSummaryCard(summary: summary),
                const SizedBox(height: 8),
                const SizedBox(
                  height: 200,
                  child: EmptyState(
                    message: 'No closed trades yet.',
                    icon: Icons.history,
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: trades.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ClosedTradeSummaryCard(summary: summary);
              }
              return _ClosedTradeCard(trade: trades[index - 1]);
            },
          );
        },
      ),
    );
  }
}

class _ClosedTradeSummaryCard extends StatelessWidget {
  const _ClosedTradeSummaryCard({required this.summary});

  final ClosedTradeSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TradingColors>()!;
    final pnlColor = summary.totalRealizedPnl >= 0 ? colors.gain : colors.loss;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total realized P&L',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatSignedPnl(summary.totalRealizedPnl),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: pnlColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Closed trades',
                    value: '${summary.tradeCount}',
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Win rate',
                    value: '${(summary.winRate * 100).toStringAsFixed(1)}%',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ClosedTradeCard extends StatelessWidget {
  const _ClosedTradeCard({required this.trade});

  final ClosedTrade trade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TradingColors>()!;
    final colorScheme = theme.colorScheme;
    final positionColor = trade.type == 'Buy' ? colors.gain : colors.loss;
    final pnlColor = trade.realizedPnl > 0
        ? colors.gain
        : trade.realizedPnl < 0
            ? colors.loss
            : colorScheme.onSurfaceVariant;
    final realizedPercent =
        trade.cost > 0 ? trade.realizedPnl / trade.cost * 100 : 0.0;
    final closedAtLabel = trade.closedAt.millisecondsSinceEpoch == 0
        ? 'Closed just now'
        : 'Closed ${DateFormat('MMM d, yyyy h:mm a').format(trade.closedAt.toLocal())}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: trade.coinImage.isEmpty
                        ? ColoredBox(
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.currency_exchange,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Image.network(
                            trade.coinImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.currency_exchange,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trade.coinName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        trade.coinSymbol.toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _HistoryChip(
                  label: tradeLabel(trade.type).toUpperCase(),
                  color: positionColor,
                ),
              ],
            ),
            if (trade.closeReason == 'liquidated') ...[
              const SizedBox(height: 10),
              _HistoryChip(label: 'Liquidated', color: colors.warning),
            ],
            const SizedBox(height: 12),
            Text('Quantity: ${formatQuantity(trade.amount)}'),
            const SizedBox(height: 3),
            Text(
              'Entry \$${formatUsd(trade.entryPrice)}  →  Exit \$${formatUsd(trade.exitPrice)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Realized ${_formatSignedPnl(trade.realizedPnl)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: pnlColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatSignedPercent(realizedPercent),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pnlColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              closedAtLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

String _formatSignedPnl(double value) {
  if (value.abs() < 0.005) {
    return '${value.isNegative ? '-' : '+'}\$${formatUsd(0)}';
  }
  return formatSignedUsd(value);
}

String _formatSignedPercent(double value) =>
    '${value.isNegative ? '-' : '+'}${value.abs().toStringAsFixed(2)}%';
