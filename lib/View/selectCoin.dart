import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Model/article.dart';
import '../Model/chartModel.dart';
import '../Model/coinModel.dart';
import '../Model/watchlist_coin.dart';
import '../Services/market_repository.dart';
import '../Services/news_service.dart';
import '../Services/trade_service.dart';
import '../Services/watchlist_repository.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/pnl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SelectCoin — Individual Coin Trading & Analytics Page
// ─────────────────────────────────────────────────────────────────────────────
class SelectCoin extends StatefulWidget {
  final CoinModel selectItem;
  const SelectCoin({super.key, required this.selectItem});

  @override
  State<SelectCoin> createState() => _SelectCoinState();
}

class _SelectCoinState extends State<SelectCoin> {
  late CoinModel _coin;
  late double _livePrice;

  // ── chart ──────────────────────────────────────────────────────────────────
  late TrackballBehavior _trackball;
  late ZoomPanBehavior _zoom;
  List<ChartModel>? _chart;
  bool _chartLoading = true;
  bool _chartError = false;
  int _chartReq = 0;
  bool _useLineChart = false;

  static const _timeLabels = ['1D', '7D', '1M', '3M', '6M', '1Y'];
  static const _timeDays = [1, 7, 30, 90, 180, 365];
  int _timeIdx = 2; // default: 1M

  // ── watchlist / favorite ───────────────────────────────────────────────────
  bool _isFavorite = false;
  bool _watchlistLoading = true;
  bool _watchlistPending = false;
  Object? _watchlistError;
  StreamSubscription<List<WatchlistCoin>>? _watchlistSubscription;

  // ── trade panel ───────────────────────────────────────────────────────────
  double _amount = 1.0;
  bool _amountInvalid = false;
  bool _submitting = false;
  final TextEditingController _amountCtrl = TextEditingController();

  // ── news & streams ────────────────────────────────────────────────────────
  late Future<NewsResponse> _newsFuture;
  User? _user;
  Stream<DocumentSnapshot>? _userDocStream;
  Stream<QuerySnapshot>? _transactionsStream;

  @override
  void initState() {
    super.initState();
    _coin = widget.selectItem;
    _livePrice = _coin.currentPrice;

    _trackball = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipSettings: const InteractiveTooltip(
        enable: true,
        borderRadius: 8,
      ),
    );
    _zoom = ZoomPanBehavior(enablePinching: true, zoomMode: ZoomMode.x);

    _amountCtrl.text = _amount.toStringAsFixed(2);
    _newsFuture = NewsService().fetchNews(_coin.id);

    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _userDocStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .snapshots();
      _transactionsStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('transactions')
          .snapshots();
      _subscribeToWatchlist();
    } else {
      _watchlistLoading = false;
    }

    _loadChart();
    _refreshLivePrice();
  }

  @override
  void dispose() {
    unawaited(_watchlistSubscription?.cancel());
    _amountCtrl.dispose();
    super.dispose();
  }

  // ── Data & Refresh ─────────────────────────────────────────────────────────

  Future<void> _refreshLivePrice() async {
    try {
      final fresh = await MarketRepository.instance.getFreshPrice(_coin.id);
      if (mounted && fresh > 0) {
        setState(() => _livePrice = fresh);
      }
    } catch (_) {}
  }

  Future<void> _loadChart() async {
    if (!mounted) return;
    final req = ++_chartReq;
    setState(() {
      _chartLoading = true;
      _chartError = false;
    });
    final days = _timeDays[_timeIdx];
    try {
      final data = await MarketRepository.instance.getOhlc(_coin.id, days);
      if (!mounted || req != _chartReq) return;
      setState(() {
        _chart = data;
        _chartError = false;
        _chartLoading = false;
      });
    } catch (_) {
      if (!mounted || req != _chartReq) return;
      setState(() {
        _chartError = true;
        _chartLoading = false;
      });
    }
  }

  List<ChartModel> _buildSparklineFallback() {
    final prices = _coin.sparklineIn7D.price;
    if (prices.isEmpty) return [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final interval =
        (7 * 24 * 3600 * 1000) ~/ (prices.length > 1 ? prices.length - 1 : 1);
    final start = now - (7 * 24 * 3600 * 1000);
    return List.generate(prices.length, (i) {
      final p = prices[i];
      return ChartModel(
        time: start + (i * interval),
        open: p,
        high: p,
        low: p,
        close: p,
      );
    });
  }

  Future<void> _handlePullToRefresh() async {
    HapticFeedback.lightImpact();
    await Future.wait([
      _refreshLivePrice(),
      _loadChart(),
    ]);
  }

  void _subscribeToWatchlist() {
    final userId = _user?.uid;
    if (userId == null) return;
    unawaited(_watchlistSubscription?.cancel());
    _watchlistSubscription = WatchlistRepository.instance
        .watchlistStream(userId)
        .listen(
      (coins) {
        if (!mounted) return;
        setState(() {
          _isFavorite = coins.any((coin) => coin.id == _coin.id);
          _watchlistLoading = false;
          _watchlistError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _watchlistLoading = false;
          _watchlistError = error;
        });
      },
    );
  }

  Future<void> _toggleFavorite() async {
    final user = _user;
    if (user == null) {
      _snack('Please sign in to manage your watchlist');
      return;
    }
    if (_watchlistLoading || _watchlistPending) return;
    if (_watchlistError != null) {
      _snack('Could not load your watchlist. Check your Firestore permissions.');
      return;
    }

    final shouldBeWatchlisted = !_isFavorite;
    final watchlistCoin = WatchlistCoin(
      id: _coin.id,
      name: _coin.name,
      symbol: _coin.symbol,
      image: _coin.image,
    );
    setState(() {
      _isFavorite = shouldBeWatchlisted;
      _watchlistPending = true;
    });
    HapticFeedback.selectionClick();

    try {
      final update = shouldBeWatchlisted
          ? WatchlistRepository.instance.addCoin(user.uid, watchlistCoin)
          : WatchlistRepository.instance.removeCoin(user.uid, _coin.id);
      await update.timeout(const Duration(seconds: 2));
      _snack(shouldBeWatchlisted
          ? '${_coin.name} added to Watchlist'
          : '${_coin.name} removed from Watchlist');
    } on TimeoutException {
      // The write may still complete after Firestore reconnects.
    } catch (error) {
      if (mounted) {
        setState(() => _isFavorite = !shouldBeWatchlisted);
        _snack('Could not update your watchlist. Check your connection and retry. ($error)');
      }
    } finally {
      if (mounted) setState(() => _watchlistPending = false);
    }
  }

  // ── Trade Actions ──────────────────────────────────────────────────────────

  Future<void> _openTrade(String type, double availableWallet) async {
    if (_submitting) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Please sign in to trade');
      return;
    }

    final normalized = _amountCtrl.text.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (_amountInvalid || parsed == null || parsed <= 0 || parsed > 1000000.0) {
      _snack('Enter a valid amount between 0.00000001 and 1,000,000');
      return;
    }

    final reqCost = parsed * _livePrice;
    if (reqCost > availableWallet) {
      _snack(
          'Insufficient funds. Cost is \$${formatUsd(reqCost)}, wallet has \$${formatUsd(availableWallet)}');
      return;
    }

    _amount = roundTo(parsed, 8);
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      final freshPrice =
          await MarketRepository.instance.getFreshPrice(_coin.id);
      await TradeService().openTrade(
        userId: user.uid,
        coinId: _coin.id,
        type: type,
        amount: _amount,
        price: freshPrice,
      );
      final label = type == 'Buy' ? 'Long' : 'Short';
      _snack(
          '$label opened: $_amount ${_coin.symbol.toUpperCase()} @ \$${formatUsd(freshPrice)}');
    } catch (e) {
      final msg = e
          .toString()
          .replaceFirst(RegExp(r'^(Exception|Invalid argument\(s\)):\s*'), '');
      _snack('Error: $msg');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _closePosition(
      String txId, double currentPrice) async {
    if (_user == null) return;
    HapticFeedback.mediumImpact();
    try {
      await TradeService().closeTrade(
        userId: _user!.uid,
        transactionId: txId,
        currentPrice: currentPrice,
      );
      _snack('Position closed successfully');
    } catch (e) {
      _snack('Failed to close position: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtAmount(double v) {
    var s = v.toStringAsFixed(8);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s.isEmpty ? '0' : s;
  }

  void _increaseAmount() {
    setState(() {
      _amountInvalid = false;
      final step = _coin.currentPrice > 1000 ? 0.01 : 1.0;
      _amount = roundTo((_amount + step).clamp(0.00000001, 1000000.0), 8);
      _amountCtrl.text = _fmtAmount(_amount);
    });
  }

  void _decreaseAmount() {
    setState(() {
      _amountInvalid = false;
      final step = _coin.currentPrice > 1000 ? 0.01 : 1.0;
      _amount = roundTo((_amount - step).clamp(0.00000001, 1000000.0), 8);
      _amountCtrl.text = _fmtAmount(_amount);
    });
  }

  void _setPercentageAmount(double fraction, double availableWallet) {
    if (_livePrice <= 0 || availableWallet <= 0) return;
    final f = fraction >= 1.0 ? 0.995 : fraction;
    final maxCost = availableWallet * f;
    final calcAmount = (maxCost / _livePrice * 1000000).floorToDouble() / 1000000;
    setState(() {
      _amount = calcAmount.clamp(0.000001, 1000000.0);
      _amountCtrl.text = _fmtAmount(_amount);
      _amountInvalid = false;
    });
    HapticFeedback.selectionClick();
  }

  void _setUsdAmount(double usdVal) {
    if (_livePrice <= 0) return;
    final calcAmount = (usdVal / _livePrice * 1000000).floorToDouble() / 1000000;
    setState(() {
      _amount = calcAmount.clamp(0.000001, 1000000.0);
      _amountCtrl.text = _fmtAmount(_amount);
      _amountInvalid = false;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _launchURL(String url) async {
    if (url.isNotEmpty && !await launchUrl(Uri.parse(url))) {
      _snack('Could not open article link');
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tc = theme.extension<TradingColors>()!;

    final pct = _coin.marketCapChangePercentage24H;
    final isUp = pct >= 0;
    final changeColor = isUp ? tc.gain : tc.loss;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _coin.image,
                width: 26,
                height: 26,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.currency_bitcoin, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _coin.symbol.toUpperCase(),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: changeColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${isUp ? '+' : ''}${pct.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: changeColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _watchlistError != null
                ? 'Watchlist unavailable'
                : _isFavorite
                    ? 'Remove from watchlist'
                    : 'Add to watchlist',
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isFavorite ? const Color(0xFFFFB300) : cs.onSurface,
            ),
            onPressed: _watchlistLoading || _watchlistPending
                ? null
                : _toggleFavorite,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userDocStream,
        builder: (context, userSnap) {
          final userData = (userSnap.hasData && userSnap.data != null && userSnap.data!.exists)
              ? userSnap.data!.data() as Map<String, dynamic>?
              : null;
          final rawWallet = userData?['wallet'];
          final availableWallet = (rawWallet is num) ? rawWallet.toDouble() : 0.0;

          final cost = _amount * _livePrice;

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _handlePullToRefresh,
                    color: cs.accent,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Hero Price Header ────────────────────────────
                          _HeroSection(
                            coin: _coin,
                            livePrice: _livePrice,
                            tc: tc,
                            theme: theme,
                          ),

                          // ── User Active Positions (if any) ───────────────
                          if (_transactionsStream != null)
                            StreamBuilder<QuerySnapshot>(
                              stream: _transactionsStream,
                              builder: (context, txSnap) {
                                if (!txSnap.hasData || txSnap.data == null) return const SizedBox();
                                final docs = txSnap.data!.docs.where((d) {
                                  final data = d.data() as Map<String, dynamic>?;
                                  return data != null && data['coinId'] == _coin.id;
                                }).toList();

                                if (docs.isEmpty) return const SizedBox();

                                return _ActivePositionsSection(
                                  docs: docs,
                                  livePrice: _livePrice,
                                  tc: tc,
                                  theme: theme,
                                  onClose: _closePosition,
                                );
                              },
                            ),

                          // ── Interactive Chart Section ────────────────────
                          _ChartSection(
                            chart: _chart,
                            loading: _chartLoading,
                            error: _chartError,
                            sparklineFallback: _buildSparklineFallback(),
                            timeIdx: _timeIdx,
                            timeLabels: _timeLabels,
                            useLineChart: _useLineChart,
                            trackball: _trackball,
                            zoom: _zoom,
                            tc: tc,
                            theme: theme,
                            onTimeSelected: (i) {
                              setState(() => _timeIdx = i);
                              _loadChart();
                            },
                            onToggleChartType: () {
                              setState(() => _useLineChart = !_useLineChart);
                            },
                            onRetry: _loadChart,
                          ),

                          // ── Market Stats Grid ────────────────────────────
                          _StatsGrid(
                            coin: _coin,
                            livePrice: _livePrice,
                            tc: tc,
                            theme: theme,
                          ),

                          // ── Related News ──────────────────────────────────
                          _NewsSection(
                            future: _newsFuture,
                            theme: theme,
                            onTap: _launchURL,
                          ),

                          const SizedBox(height: 140),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Sticky Bottom Trade Bar ─────────────────────────────────
                _TradeBar(
                  amount: _amount,
                  cost: cost,
                  livePrice: _livePrice,
                  availableWallet: availableWallet,
                  amountInvalid: _amountInvalid,
                  submitting: _submitting,
                  controller: _amountCtrl,
                  coinSymbol: _coin.symbol,
                  tc: tc,
                  theme: theme,
                  onIncrease: _increaseAmount,
                  onDecrease: _decreaseAmount,
                  onPresetPercent: (frac) =>
                      _setPercentageAmount(frac, availableWallet),
                  onPresetUsd: _setUsdAmount,
                  onChanged: (val) {
                    final norm = val.replaceAll(',', '.');
                    final parsed = double.tryParse(norm);
                    setState(() {
                      _amountInvalid = parsed == null ||
                          parsed <= 0 ||
                          parsed > 1000000.0;
                      if (!_amountInvalid && parsed != null) _amount = roundTo(parsed, 8);
                    });
                  },
                  onBuy: () => _openTrade('Buy', availableWallet),
                  onShort: () => _openTrade('Sell', availableWallet),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// SUB-WIDGETS & SECTIONS
// =============================================================================

// ── Hero Price Section ────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final CoinModel coin;
  final double livePrice;
  final TradingColors tc;
  final ThemeData theme;

  const _HeroSection({
    required this.coin,
    required this.livePrice,
    required this.tc,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final pct = coin.marketCapChangePercentage24H;
    final isUp = pct >= 0;
    final changeColor = isUp ? tc.gain : tc.loss;
    final priceChange = coin.priceChange24H;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                coin.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              if (coin.marketCapRank > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Rank #${coin.marketCapRank}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Big Price Display
          Text(
            '\$${formatUsd(livePrice)}',
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: changeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isUp ? '+' : ''}${pct.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${priceChange >= 0 ? '+' : ''}\$${formatUsd(priceChange.abs())} 24h',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Active User Positions Section ─────────────────────────────────────────────
class _ActivePositionsSection extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final double livePrice;
  final TradingColors tc;
  final ThemeData theme;
  final Future<void> Function(String txId, double currentPrice) onClose;

  const _ActivePositionsSection({
    required this.docs,
    required this.livePrice,
    required this.tc,
    required this.theme,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  size: 18, color: cs.accent),
              const SizedBox(width: 8),
              Text(
                'Your Active Position (${docs.length})',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final type = (data['type'] ?? 'Buy') as String;
            final entryPrice = (data['price'] ?? 0.0) is num
                ? (data['price'] as num).toDouble()
                : 0.0;
            final amount = (data['amount'] ?? 0.0) is num
                ? (data['amount'] as num).toDouble()
                : 0.0;
            final cost = (data['cost'] ?? (entryPrice * amount)) is num
                ? (data['cost'] as num).toDouble()
                : entryPrice * amount;

            final pnl = computePnl(
              type: type,
              entryPrice: entryPrice,
              currentPrice: livePrice,
              amount: amount,
            );
            final pnlPct = cost > 0 ? (pnl / cost) * 100 : 0.0;
            final isProfit = pnl >= 0;
            final pnlColor = isProfit ? tc.gain : tc.loss;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (type == 'Buy' ? tc.gain : tc.loss)
                          .withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      type == 'Buy' ? 'LONG' : 'SHORT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: type == 'Buy' ? tc.gain : tc.loss,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$amount @ \$${formatUsd(entryPrice)}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PnL: ${formatSignedUsd(pnl)} (${isProfit ? '+' : ''}${pnlPct.toStringAsFixed(2)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: pnlColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tc.loss,
                      foregroundColor: tc.onLoss,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => onClose(doc.id, livePrice),
                    child: const Text('Close',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Interactive Chart Section ─────────────────────────────────────────────────
class _ChartSection extends StatelessWidget {
  final List<ChartModel>? chart;
  final bool loading;
  final bool error;
  final List<ChartModel> sparklineFallback;
  final int timeIdx;
  final List<String> timeLabels;
  final bool useLineChart;
  final TrackballBehavior trackball;
  final ZoomPanBehavior zoom;
  final TradingColors tc;
  final ThemeData theme;
  final ValueChanged<int> onTimeSelected;
  final VoidCallback onToggleChartType;
  final VoidCallback onRetry;

  const _ChartSection({
    required this.chart,
    required this.loading,
    required this.error,
    required this.sparklineFallback,
    required this.timeIdx,
    required this.timeLabels,
    required this.useLineChart,
    required this.trackball,
    required this.zoom,
    required this.tc,
    required this.theme,
    required this.onTimeSelected,
    required this.onToggleChartType,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final chartData = (chart != null && chart!.isNotEmpty)
        ? chart!
        : sparklineFallback;

    final isPositive = chartData.length >= 2
        ? (chartData.last.close ?? 0) >= (chartData.first.open ?? 0)
        : true;
    final chartColor = isPositive ? tc.gain : tc.loss;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price Chart',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      useLineChart
                          ? Icons.candlestick_chart_rounded
                          : Icons.show_chart_rounded,
                      size: 20,
                      color: cs.accent,
                    ),
                    tooltip: useLineChart
                        ? 'Switch to Candles'
                        : 'Switch to Area Line',
                    onPressed: onToggleChartType,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh Chart',
                    onPressed: onRetry,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Chart Card Container
        Container(
          height: 290,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : chartData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bar_chart_rounded,
                                size: 42, color: cs.onSurfaceVariant),
                            const SizedBox(height: 8),
                            Text(
                              'Chart data unavailable',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: onRetry,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : SfCartesianChart(
                        plotAreaBorderWidth: 0,
                        trackballBehavior: trackball,
                        zoomPanBehavior: zoom,
                        margin: const EdgeInsets.only(top: 12, right: 8),
                        primaryXAxis: const DateTimeAxis(
                          isVisible: true,
                          axisLine: AxisLine(width: 0),
                          majorGridLines: MajorGridLines(width: 0),
                          majorTickLines: MajorTickLines(size: 0),
                        ),
                        primaryYAxis: const NumericAxis(
                          isVisible: true,
                          axisLine: AxisLine(width: 0),
                          majorGridLines: MajorGridLines(
                            width: 0.5,
                            dashArray: <double>[5, 5],
                          ),
                          majorTickLines: MajorTickLines(size: 0),
                          opposedPosition: true,
                        ),
                        series: useLineChart || error
                            ? <CartesianSeries>[
                                SplineAreaSeries<ChartModel, DateTime>(
                                  dataSource: chartData,
                                  xValueMapper: (c, _) =>
                                      DateTime.fromMillisecondsSinceEpoch(
                                          c.time),
                                  yValueMapper: (c, _) =>
                                      c.close ?? c.open ?? 0,
                                  borderColor: chartColor,
                                  borderWidth: 2.5,
                                  gradient: LinearGradient(
                                    colors: [
                                      chartColor.withValues(alpha: 0.35),
                                      chartColor.withValues(alpha: 0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  animationDuration: 400,
                                ),
                              ]
                            : <CartesianSeries>[
                                CandleSeries<ChartModel, DateTime>(
                                  enableSolidCandles: true,
                                  enableTooltip: true,
                                  bullColor: tc.gain,
                                  bearColor: tc.loss,
                                  dataSource: chartData,
                                  xValueMapper: (c, _) =>
                                      DateTime.fromMillisecondsSinceEpoch(
                                          c.time),
                                  lowValueMapper: (c, _) => c.low,
                                  highValueMapper: (c, _) => c.high,
                                  openValueMapper: (c, _) => c.open,
                                  closeValueMapper: (c, _) => c.close,
                                  animationDuration: 400,
                                ),
                              ],
                      ),
          ),
        ),

        // Time Selector Pills
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: timeLabels.length,
            itemBuilder: (_, i) {
              final selected = timeIdx == i;
              return GestureDetector(
                onTap: () => onTimeSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    timeLabels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final CoinModel coin;
  final double livePrice;
  final TradingColors tc;
  final ThemeData theme;

  const _StatsGrid({
    required this.coin,
    required this.livePrice,
    required this.tc,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final low = coin.low24H;
    final high = coin.high24H;
    final cur = livePrice;
    final vol = coin.totalVolume;

    final rangeFill = (high - low) == 0
        ? 0.5
        : ((cur - low) / (high - low)).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Market Overview',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Stat Tiles
          Row(
            children: [
              _StatTile(
                label: '24h Low',
                value: '\$${formatUsd(low)}',
                valueColor: tc.loss,
                icon: Icons.south_rounded,
                iconColor: tc.loss,
                theme: theme,
              ),
              const SizedBox(width: 10),
              _StatTile(
                label: '24h High',
                value: '\$${formatUsd(high)}',
                valueColor: tc.gain,
                icon: Icons.north_rounded,
                iconColor: tc.gain,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatTile(
                label: '24h Volume',
                value: _compact(vol),
                icon: Icons.bar_chart_rounded,
                iconColor: cs.accent,
                theme: theme,
              ),
              const SizedBox(width: 10),
              _StatTile(
                label: 'Market Rank',
                value: '#${coin.marketCapRank}',
                icon: Icons.leaderboard_rounded,
                iconColor: const Color(0xFFFFB300),
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 24h Range Indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '24h Price Range',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Text(
                      '${(rangeFill * 100).toStringAsFixed(0)}% of range',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _GradientRangeBar(
                  fill: rangeFill,
                  gainColor: tc.gain,
                  lossColor: tc.loss,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('\$${formatUsd(low)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: tc.loss,
                            fontWeight: FontWeight.bold)),
                    Text('\$${formatUsd(high)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: tc.gain,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static String _compact(double v) {
    if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(2)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(2)}K';
    return '\$${formatUsd(v)}';
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? valueColor;
  final ThemeData theme;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.valueColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(value,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: valueColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientRangeBar extends StatelessWidget {
  final double fill;
  final Color gainColor;
  final Color lossColor;

  const _GradientRangeBar({
    required this.fill,
    required this.gainColor,
    required this.lossColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const h = 8.0;
      const r = 8.0;
      final w = c.maxWidth;
      return SizedBox(
        height: r * 2,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(h / 2),
                gradient: LinearGradient(colors: [
                  lossColor.withValues(alpha: 0.7),
                  gainColor.withValues(alpha: 0.7),
                ]),
              ),
            ),
            Positioned(
              left: (w * fill - r).clamp(0.0, w - r * 2),
              child: Container(
                width: r * 2,
                height: r * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(lossColor, gainColor, fill),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color.lerp(lossColor, gainColor, fill)!
                          .withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── News Section ──────────────────────────────────────────────────────────────
class _NewsSection extends StatelessWidget {
  final Future<NewsResponse> future;
  final ThemeData theme;
  final Future<void> Function(String) onTap;

  const _NewsSection({
    required this.future,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.newspaper_rounded, size: 20, color: cs.accent),
              const SizedBox(width: 8),
              Text(
                'Related Market News',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<NewsResponse>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()));
              }
              if (snap.hasError || !snap.hasData || snap.data!.articles.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        snap.error is NewsException
                            ? (snap.error as NewsException).message
                            : 'No related market news available right now.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: snap.data!.articles
                    .map((a) => _NewsCard(
                          article: a,
                          theme: theme,
                          onTap: onTap,
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final Article article;
  final ThemeData theme;
  final Future<void> Function(String) onTap;

  const _NewsCard({
    required this.article,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: () => onTap(article.link ?? ''),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  article.imageUrl!,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.newspaper_rounded,
                        color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.newspaper_rounded, color: cs.onSurfaceVariant),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title ?? 'Market News',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.open_in_new_rounded,
                          size: 12, color: cs.accent),
                      const SizedBox(width: 4),
                      Text('Read full story',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.accent, fontWeight: FontWeight.bold)),
                    ],
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

// ── Trade Bar ─────────────────────────────────────────────────────────────────
class _TradeBar extends StatelessWidget {
  final double amount;
  final double cost;
  final double livePrice;
  final double availableWallet;
  final bool amountInvalid;
  final bool submitting;
  final TextEditingController controller;
  final String coinSymbol;
  final TradingColors tc;
  final ThemeData theme;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final ValueChanged<double> onPresetPercent;
  final ValueChanged<double> onPresetUsd;
  final ValueChanged<String> onChanged;
  final VoidCallback onBuy;
  final VoidCallback onShort;

  const _TradeBar({
    required this.amount,
    required this.cost,
    required this.livePrice,
    required this.availableWallet,
    required this.amountInvalid,
    required this.submitting,
    required this.controller,
    required this.coinSymbol,
    required this.tc,
    required this.theme,
    required this.onIncrease,
    required this.onDecrease,
    required this.onPresetPercent,
    required this.onPresetUsd,
    required this.onChanged,
    required this.onBuy,
    required this.onShort,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final canTrade = !amountInvalid && !submitting && cost <= availableWallet;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Balance & Cost Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Available: \$${formatUsd(availableWallet)}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              Text(
                amountInvalid
                    ? 'Invalid Amount'
                    : 'Total Est: \$${formatUsd(cost)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: amountInvalid
                      ? cs.error
                      : (cost > availableWallet ? cs.error : cs.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stepper + Input Row
          Row(
            children: [
              Text('Qty',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _StepBtn(
                          icon: Icons.remove_rounded,
                          onTap: onDecrease,
                          cs: cs),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: coinSymbol.toUpperCase(),
                            suffixStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: onChanged,
                        ),
                      ),
                      _StepBtn(
                          icon: Icons.add_rounded, onTap: onIncrease, cs: cs),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Preset Chips (Percentages + Dollar Presets)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PresetChip(
                    label: '25%', onTap: () => onPresetPercent(0.25), cs: cs),
                _PresetChip(
                    label: '50%', onTap: () => onPresetPercent(0.50), cs: cs),
                _PresetChip(
                    label: '75%', onTap: () => onPresetPercent(0.75), cs: cs),
                _PresetChip(
                    label: 'MAX', onTap: () => onPresetPercent(1.00), cs: cs),
                const SizedBox(width: 8),
                _PresetChip(
                    label: '\$50', onTap: () => onPresetUsd(50), cs: cs),
                _PresetChip(
                    label: '\$100', onTap: () => onPresetUsd(100), cs: cs),
                _PresetChip(
                    label: '\$500', onTap: () => onPresetUsd(500), cs: cs),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Buy (Long) / Short Buttons
          Row(
            children: [
              Expanded(
                child: _TradeButton(
                  label: 'Buy / Long',
                  icon: Icons.trending_up_rounded,
                  color: tc.gain,
                  onColor: tc.onGain,
                  enabled: canTrade,
                  submitting: submitting,
                  onTap: onBuy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TradeButton(
                  label: 'Sell / Short',
                  icon: Icons.trending_down_rounded,
                  color: tc.loss,
                  onColor: tc.onLoss,
                  enabled: canTrade,
                  submitting: submitting,
                  onTap: onShort,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _PresetChip({
    required this.label,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _StepBtn({required this.icon, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: cs.onSurface),
      ),
    );
  }
}

class _TradeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color onColor;
  final bool enabled;
  final bool submitting;
  final VoidCallback onTap;

  const _TradeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onColor,
    required this.enabled,
    required this.submitting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? color : color.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (submitting)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: onColor,
                ),
              )
            else ...[
              Icon(icon, color: onColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: onColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
