import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:my_crypto/Model/coinModel.dart';
import 'package:my_crypto/Model/coin_search_result.dart';
import 'package:my_crypto/View/Components/state_widgets.dart';

typedef CoinSearchRequest = Future<List<CoinSearchResult>> Function(
  String query, {
  Future<void>? abortTrigger,
});

class CoinSearchList extends StatefulWidget {
  const CoinSearchList({
    super.key,
    required this.marketCoins,
    required this.search,
    required this.onRefresh,
    required this.onResultSelected,
    required this.coinTileBuilder,
  });

  final List<CoinModel> marketCoins;
  final CoinSearchRequest search;
  final Future<void> Function() onRefresh;
  final ValueChanged<CoinSearchResult> onResultSelected;
  final Widget Function(CoinModel coin) coinTileBuilder;

  @override
  State<CoinSearchList> createState() => _CoinSearchListState();
}

class _CoinSearchListState extends State<CoinSearchList> {
  static const _debounceDuration = Duration(milliseconds: 400);

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  Completer<void>? _activeAborter;
  int _requestId = 0;
  String _query = '';
  List<CoinSearchResult> _results = [];
  bool _isLoading = false;
  Object? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelActiveSearch();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _cancelActiveSearch();
    final requestId = ++_requestId;
    final query = value.trim();

    setState(() {
      _query = query;
      _results = [];
      _error = null;
      _isLoading = query.isNotEmpty;
    });

    if (query.isEmpty) return;

    _debounce = Timer(
      _debounceDuration,
      () => unawaited(_runSearch(query, requestId)),
    );
  }

  void _cancelActiveSearch() {
    final aborter = _activeAborter;
    if (aborter != null && !aborter.isCompleted) aborter.complete();
    _activeAborter = null;
  }

  Future<void> _runSearch(String query, int requestId) async {
    final aborter = Completer<void>();
    _activeAborter = aborter;
    try {
      final results = await widget.search(
        query,
        abortTrigger: aborter.future,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = [];
        _isLoading = false;
        _error = error;
      });
    } finally {
      if (identical(_activeAborter, aborter)) _activeAborter = null;
    }
  }

  void _retrySearch() {
    if (_query.isEmpty) return;
    _debounce?.cancel();
    _cancelActiveSearch();
    final requestId = ++_requestId;
    setState(() {
      _results = [];
      _error = null;
      _isLoading = true;
    });
    unawaited(_runSearch(_query, requestId));
  }

  void _clearSearch() {
    _controller.clear();
    _onQueryChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _controller,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search coins',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: _buildContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_query.isEmpty) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: widget.marketCoins.length,
        itemBuilder: (context, index) =>
            widget.coinTileBuilder(widget.marketCoins[index]),
      );
    }

    if (_isLoading) return const CoinListSkeleton(count: 4);

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 240,
            child: ErrorState(error: _error, onRetry: _retrySearch),
          ),
        ],
      );
    }

    if (_results.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 240,
            child: EmptyState(message: 'No coins found for "$_query".'),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        final rank = result.marketCapRank;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: SizedBox(
              width: 40,
              height: 40,
              child: result.image.isEmpty
                  ? const Icon(Icons.currency_bitcoin)
                  : Image.network(
                      result.image,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.currency_bitcoin),
                    ),
            ),
            title: Text(result.name),
            subtitle: Text(
              '${result.symbol.toUpperCase()}${rank == null ? '' : ' · Rank #$rank'}',
            ),
            onTap: () => widget.onResultSelected(result),
          ),
        );
      },
    );
  }
}
