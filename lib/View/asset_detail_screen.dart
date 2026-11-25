import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../Model/chartModel.dart';
import '../Model/coinModel.dart';
import '../Services/market_repository.dart';
import '../Services/trade_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/pnl.dart';

const _liveLineColor = Colors.blue;
const _entryLineColor = Color(0xFFFFB300);

// ---------------------------------------------------------------------------
// Entry point – pass the coin + the user's open transaction for that coin
// ---------------------------------------------------------------------------
class AssetDetailScreen extends StatefulWidget {
  /// The live CoinModel (market data).
  final CoinModel coin;

  /// The Firestore transaction document for this open position.
  final Map<String, dynamic> transaction;

  const AssetDetailScreen({
    super.key,
    required this.coin,
    required this.transaction,
  });

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  // ── chart state ────────────────────────────────────────────────────────────
  List<ChartModel>? _chartData;
  bool _chartLoading = true;
  int _chartReq = 0;
  String? _chartErrorMessage;
  final List<String> _timeLabels = ['D', 'W', 'M', '3M', '6M', 'Y'];
  final List<int> _timeDays = [1, 7, 30, 90, 180, 365];
  int _selectedTimeIndex = 2; // default: 1M

  late TrackballBehavior _trackballBehavior;
  late ZoomPanBehavior _zoomPanBehavior;

  // ── live price stream ──────────────────────────────────────────────────────
  /// We re-read from Firestore every time a transaction snapshot comes in,
  /// and poll a fresh price to keep PnL live.
  double _livePrice = 0;
  bool _closingTrade = false;
  Timer? _priceTimer;

  // ── derived from transaction ───────────────────────────────────────────────
  late final String _txId;
  late final String _type;
  late final double _entryPrice;
  late final double _amount;
  late final double _cost;
  late final DateTime _openedAt;

  @override
  void initState() {
    super.initState();

    _txId = widget.transaction['id'] as String;
    _type = widget.transaction['type'] as String;
    _entryPrice = (widget.transaction['price'] as num).toDouble();
    _amount = (widget.transaction['amount'] as num).toDouble();
    _cost = (widget.transaction['cost'] as num? ?? (_entryPrice * _amount)).toDouble();
    _openedAt = DateTime.tryParse(widget.transaction['date'] as String? ?? '') ?? DateTime.now();

    _livePrice = widget.coin.currentPrice;

    _trackballBehavior = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
    );
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      zoomMode: ZoomMode.x,
    );

    _priceTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshLivePrice());

    _loadChart();
    _refreshLivePrice();
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    super.dispose();
  }

  // ── data ───────────────────────────────────────────────────────────────────

  Future<void> _loadChart() async {
    final reqToken = ++_chartReq;
    setState(() => _chartLoading = true);
    final days = _timeDays[_selectedTimeIndex];
    try {
      final data = await MarketRepository.instance.getOhlc(widget.coin.id, days);
      if (!mounted || reqToken != _chartReq) return;
      setState(() {
        _chartData = data;
        _chartErrorMessage = null;
      });
    } catch (e) {
      if (!mounted || reqToken != _chartReq) return;
      setState(() {
        _chartData = null;
        _chartErrorMessage = e is MarketException
            ? e.message
            : 'Chart unavailable. Try again in a few seconds.';
      });
    } finally {
      if (mounted && reqToken == _chartReq) setState(() => _chartLoading = false);
    }
  }

  Future<void> _refreshLivePrice() async {
    try {
      final fresh = await MarketRepository.instance.getFreshPrice(widget.coin.id);
      if (mounted) setState(() => _livePrice = fresh);
    } catch (_) {}
  }

  // ── computed helpers ───────────────────────────────────────────────────────

  double get _pnl => computePnl(
        type: _type,
        entryPrice: _entryPrice,
        currentPrice: _livePrice,
        amount: _amount,
      );

  double get _pnlPct => _cost == 0 ? 0 : (_pnl / _cost) * 100;

  bool get _isLong => _type == 'Buy';

  Duration get _heldFor => DateTime.now().difference(_openedAt);

  String _formatDuration(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }

  // ── close trade ────────────────────────────────────────────────────────────

  Future<void> _closeTrade() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Position'),
        content: Text(
          'Close your ${tradeLabel(_type)} of $_amount ${widget.coin.symbol.toUpperCase()} at '
          '\$${formatUsd(_livePrice)}?\n\n'
          'Est. PnL: ${formatSignedUsd(_pnl)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close Trade'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _closingTrade = true);
    try {
      await _refreshLivePrice();
      await TradeService().closeTrade(
        userId: userId,
        transactionId: _txId,
        currentPrice: _livePrice,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Position closed at \$${formatUsd(_livePrice)}')),
      );
      Navigator.pop(context);
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^(Exception|Invalid argument\(s\)):\s*'), '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $msg')),
      );
    } finally {
      if (mounted) setState(() => _closingTrade = false);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tc = theme.extension<TradingColors>()!;

    final pnl = _pnl;
    final pnlPct = _pnlPct;
    final isProfit = pnl >= 0;
    final pnlColor = pnl.abs() < 0.005 ? cs.onSurfaceVariant : (isProfit ? tc.gain : tc.loss);
    final positionColor = _isLong ? tc.gain : tc.loss;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Image.network(
                widget.coin.image,
                errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.coin.name),
            const SizedBox(width: 6),
            Text(
              widget.coin.symbol.toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh price',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLivePrice,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Position badge + live price ──────────────────────────
                    _PriceBanner(
                      livePrice: _livePrice,
                      positionType: tradeLabel(_type),
                      positionColor: positionColor,
                      coin: widget.coin,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),

                    // ── PnL hero card ────────────────────────────────────────
                    _PnLCard(
                      pnl: pnl,
                      pnlPct: pnlPct,
                      pnlColor: pnlColor,
                      isProfit: isProfit,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),

                    // ── Position details ─────────────────────────────────────
                    _PositionStatsCard(
                      entryPrice: _entryPrice,
                      livePrice: _livePrice,
                      amount: _amount,
                      cost: _cost,
                      heldFor: _formatDuration(_heldFor),
                      openedAt: _openedAt,
                      theme: theme,
                      tc: tc,
                      isLong: _isLong,
                    ),
                    const SizedBox(height: 12),

                    // ── Candlestick chart with entry-price line ──────────────
                    _ChartCard(
                      chartData: _chartData,
                      errorMessage: _chartErrorMessage,
                      loading: _chartLoading,
                      entryPrice: _entryPrice,
                      livePrice: _livePrice,
                      isLong: _isLong,
                      timeLabels: _timeLabels,
                      selectedIndex: _selectedTimeIndex,
                      trackball: _trackballBehavior,
                      zoom: _zoomPanBehavior,
                      tc: tc,
                      theme: theme,
                      onTimeSelected: (i) {
                        setState(() => _selectedTimeIndex = i);
                        _loadChart();
                      },
                    ),
                    const SizedBox(height: 12),

                    // ── Trade trend indicator ────────────────────────────────
                    _TrendCard(
                      coin: widget.coin,
                      isLong: _isLong,
                      entryPrice: _entryPrice,
                      livePrice: _livePrice,
                      pnlPct: pnlPct,
                      theme: theme,
                      tc: tc,
                    ),
                    const SizedBox(height: 12),

                    // ── 24h market stats ─────────────────────────────────────
                    _MarketStatsCard(coin: widget.coin, theme: theme),
                    const SizedBox(height: 80), // room for bottom bar
                  ],
                ),
              ),
            ),

            // ── Bottom action bar ────────────────────────────────────────────
            _BottomBar(
              pnl: pnl,
              pnlColor: pnlColor,
              isProfit: isProfit,
              isClosing: _closingTrade,
              positionColor: positionColor,
              isLong: _isLong,
              onClose: _closeTrade,
              theme: theme,
              tc: tc,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Sub-widgets
// ============================================================================

// ── Price banner ──────────────────────────────────────────────────────────────
class _PriceBanner extends StatelessWidget {
  final double livePrice;
  final String positionType;
  final Color positionColor;
  final CoinModel coin;
  final ThemeData theme;

  const _PriceBanner({
    required this.livePrice,
    required this.positionType,
    required this.positionColor,
    required this.coin,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final isPositive = coin.marketCapChangePercentage24H >= 0;
    final tc = theme.extension<TradingColors>()!;
    final changeColor = isPositive ? tc.gain : tc.loss;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live Price', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  '\$${formatUsd(livePrice)}',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: changeColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${isPositive ? '+' : ''}${coin.marketCapChangePercentage24H.toStringAsFixed(2)}% (24h)',
                      style: TextStyle(fontSize: 12, color: changeColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: positionColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: positionColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    positionType == 'Long' ? Icons.trending_up : Icons.trending_down,
                    color: positionColor,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    positionType.toUpperCase(),
                    style: TextStyle(color: positionColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PnL hero ──────────────────────────────────────────────────────────────────
class _PnLCard extends StatelessWidget {
  final double pnl;
  final double pnlPct;
  final Color pnlColor;
  final bool isProfit;
  final ThemeData theme;

  const _PnLCard({
    required this.pnl,
    required this.pnlPct,
    required this.pnlColor,
    required this.isProfit,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: pnlColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: pnlColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Unrealized P&L',
              style: theme.textTheme.bodySmall?.copyWith(color: pnlColor),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatSignedUsd(pnl),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: pnlColor,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pnlColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${isProfit ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                      style: TextStyle(color: pnlColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
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

// ── Position stats ────────────────────────────────────────────────────────────
class _PositionStatsCard extends StatelessWidget {
  final double entryPrice;
  final double livePrice;
  final double amount;
  final double cost;
  final String heldFor;
  final DateTime openedAt;
  final ThemeData theme;
  final TradingColors tc;
  final bool isLong;

  const _PositionStatsCard({
    required this.entryPrice,
    required this.livePrice,
    required this.amount,
    required this.cost,
    required this.heldFor,
    required this.openedAt,
    required this.theme,
    required this.tc,
    required this.isLong,
  });

  Widget _stat(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final liquidated = isLong
        ? false
        : isLiquidated(
            type: 'Sell',
            entryPrice: entryPrice,
            currentPrice: livePrice,
            amount: amount,
            cost: cost,
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Position Details',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _stat('Entry Price', '\$${formatUsd(entryPrice)}')),
                Expanded(child: _stat('Current Price', '\$${formatUsd(livePrice)}')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _stat('Size', amount.toStringAsFixed(4))),
                Expanded(child: _stat('Collateral', '\$${formatUsd(cost)}')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _stat('Held For', heldFor)),
                Expanded(
                  child: _stat(
                    'Opened',
                    DateFormat('MMM d, HH:mm').format(openedAt),
                  ),
                ),
              ],
            ),
            if (liquidated) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tc.loss.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tc.loss),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: tc.loss, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Position equity at or below zero — close immediately.',
                        style: TextStyle(color: tc.loss, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Chart card ────────────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final List<ChartModel>? chartData;
  final String? errorMessage;
  final bool loading;
  final double entryPrice;
  final double livePrice;
  final bool isLong;
  final List<String> timeLabels;
  final int selectedIndex;
  final TrackballBehavior trackball;
  final ZoomPanBehavior zoom;
  final TradingColors tc;
  final ThemeData theme;
  final ValueChanged<int> onTimeSelected;

  const _ChartCard({
    required this.chartData,
    this.errorMessage,
    required this.loading,
    required this.entryPrice,
    required this.livePrice,
    required this.isLong,
    required this.timeLabels,
    required this.selectedIndex,
    required this.trackball,
    required this.zoom,
    required this.tc,
    required this.theme,
    required this.onTimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Price Chart',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: _buildChart(),
            ),
            const SizedBox(height: 8),
            // time selector
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: timeLabels.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(timeLabels[i]),
                    selected: selectedIndex == i,
                    onSelected: (_) => onTimeSelected(i),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _legendDot(_entryLineColor),
                  const SizedBox(width: 4),
                  Text('Entry \$${formatUsd(entryPrice)}',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(width: 16),
                  _legendDot(_liveLineColor),
                  const SizedBox(width: 4),
                  Text('Live \$${formatUsd(livePrice)}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (chartData == null || chartData!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            errorMessage ?? 'Chart unavailable — API rate limit reached.\nTry again in a few seconds.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final minClose = chartData!.map((c) => c.low ?? double.infinity).reduce(min);
    final maxClose = chartData!.map((c) => c.high ?? double.negativeInfinity).reduce(max);
    final minY = min(minClose, min(entryPrice, livePrice)) * 0.998;
    final maxY = max(maxClose, max(entryPrice, livePrice)) * 1.002;

    return SfCartesianChart(
      trackballBehavior: trackball,
      zoomPanBehavior: zoom,
      margin: const EdgeInsets.only(right: 8),
      primaryXAxis: const DateTimeAxis(isVisible: true),
      primaryYAxis: NumericAxis(
        minimum: minY,
        maximum: maxY,
        numberFormat: NumberFormat.compactSimpleCurrency(),
      ),
      series: <CartesianSeries>[
        // Candlestick OHLC
        CandleSeries<ChartModel, DateTime>(
          enableSolidCandles: true,
          enableTooltip: true,
          bullColor: tc.gain,
          bearColor: tc.loss,
          dataSource: chartData!,
          xValueMapper: (c, _) => DateTime.fromMillisecondsSinceEpoch(c.time),
          lowValueMapper: (c, _) => c.low,
          highValueMapper: (c, _) => c.high,
          openValueMapper: (c, _) => c.open,
          closeValueMapper: (c, _) => c.close,
          animationDuration: 400,
        ),
        // ── Entry-price horizontal line ─────────────────────────────────────
        LineSeries<ChartModel, DateTime>(
          name: 'Entry',
          dataSource: [chartData!.first, chartData!.last],
          xValueMapper: (c, _) => DateTime.fromMillisecondsSinceEpoch(c.time),
          yValueMapper: (_, __) => entryPrice,
          color: _entryLineColor,
          width: 1.6,
          dashArray: const <double>[6, 4],
          enableTooltip: false,
          markerSettings: const MarkerSettings(isVisible: false),
        ),
        // ── Live-price horizontal line ──────────────────────────────────────
        LineSeries<ChartModel, DateTime>(
          name: 'Live',
          dataSource: [chartData!.first, chartData!.last],
          xValueMapper: (c, _) => DateTime.fromMillisecondsSinceEpoch(c.time),
          yValueMapper: (_, __) => livePrice,
          color: _liveLineColor,
          width: 1.4,
          dashArray: const <double>[4, 4],
          enableTooltip: false,
          markerSettings: const MarkerSettings(isVisible: false),
        ),
      ],
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// ── Trade trend ───────────────────────────────────────────────────────────────
class _TrendCard extends StatelessWidget {
  final CoinModel coin;
  final bool isLong;
  final double entryPrice;
  final double livePrice;
  final double pnlPct;
  final ThemeData theme;
  final TradingColors tc;

  const _TrendCard({
    required this.coin,
    required this.isLong,
    required this.entryPrice,
    required this.livePrice,
    required this.pnlPct,
    required this.theme,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    final marketMove = coin.marketCapChangePercentage24H; // 24h % change

    // Trend vs position direction
    final marketFavorable = isLong ? marketMove >= 0 : marketMove <= 0;
    final trendColor = marketFavorable ? tc.gain : tc.loss;
    final trendLabel = marketFavorable ? 'Favorable' : 'Adverse';
    final trendIcon = marketFavorable ? Icons.thumb_up_outlined : Icons.thumb_down_outlined;

    // Distance to entry as a rough volatility gauge
    final moveFromEntry = livePrice == 0 ? 0.0 : ((livePrice - entryPrice) / entryPrice * 100).abs();

    String strength() {
      if (moveFromEntry < 1) return 'Minimal move';
      if (moveFromEntry < 3) return 'Moderate move';
      if (moveFromEntry < 7) return 'Significant move';
      return 'Large move';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trade Trend',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Market direction pill
            Row(
              children: [
                Icon(
                  coin.marketCapChangePercentage24H >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: coin.marketCapChangePercentage24H >= 0 ? tc.gain : tc.loss,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('24h Market Move',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      Text(
                        '${coin.marketCapChangePercentage24H >= 0 ? '+' : ''}${coin.marketCapChangePercentage24H.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: coin.marketCapChangePercentage24H >= 0 ? tc.gain : tc.loss,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendIcon, color: trendColor, size: 14),
                      const SizedBox(width: 4),
                      Text(trendLabel,
                          style: TextStyle(
                              color: trendColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            // Move from entry
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Move from Entry',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    Text(
                      '${moveFromEntry.toStringAsFixed(2)}%  — ${strength()}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Simple progress bar showing gain %
            _PnLProgressBar(pnlPct: pnlPct, tc: tc),
          ],
        ),
      ),
    );
  }
}

class _PnLProgressBar extends StatelessWidget {
  final double pnlPct;
  final TradingColors tc;

  const _PnLProgressBar({required this.pnlPct, required this.tc});

  @override
  Widget build(BuildContext context) {
    // Map pnlPct → 0..1 for the bar. Cap at ±50 %
    final clamped = pnlPct.clamp(-50.0, 50.0);
    final barValue = (clamped + 50) / 100; // 0 = -50%, 0.5 = 0%, 1 = +50%
    final barColor = pnlPct >= 0 ? tc.gain : tc.loss;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('-50%', style: TextStyle(fontSize: 10, color: tc.loss)),
            Text('P&L', style: const TextStyle(fontSize: 10)),
            Text('+50%', style: TextStyle(fontSize: 10, color: tc.gain)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: barValue,
            minHeight: 8,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
            style: TextStyle(fontSize: 12, color: barColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// ── 24h market stats ──────────────────────────────────────────────────────────
class _MarketStatsCard extends StatelessWidget {
  final CoinModel coin;
  final ThemeData theme;

  const _MarketStatsCard({required this.coin, required this.theme});

  Widget _stat(String label, String value) => Column(
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('24h Market Stats',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Low', '\$${formatUsd(coin.low24H)}'),
                _stat('High', '\$${formatUsd(coin.high24H)}'),
                _stat('Volume', '\$${formatUsd(coin.totalVolume)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final double pnl;
  final Color pnlColor;
  final bool isProfit;
  final bool isClosing;
  final Color positionColor;
  final bool isLong;
  final VoidCallback onClose;
  final ThemeData theme;
  final TradingColors tc;

  const _BottomBar({
    required this.pnl,
    required this.pnlColor,
    required this.isProfit,
    required this.isClosing,
    required this.positionColor,
    required this.isLong,
    required this.onClose,
    required this.theme,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Est. P&L',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  Text(
                    formatSignedUsd(pnl),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: pnlColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: tc.loss,
                  foregroundColor: tc.onLoss,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: isClosing ? null : onClose,
                icon: isClosing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isLong ? Icons.sell : Icons.close),
                label: Text(isClosing ? 'Closing…' : 'Close Position'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
