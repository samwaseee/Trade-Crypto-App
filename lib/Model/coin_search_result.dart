import 'coinModel.dart';

class CoinSearchResult {
  const CoinSearchResult({
    required this.id,
    required this.name,
    required this.symbol,
    required this.image,
    required this.marketCapRank,
  });

  final String id;
  final String name;
  final String symbol;
  final String image;
  final int? marketCapRank;

  factory CoinSearchResult.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final symbol = json['symbol'];

    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        symbol is! String) {
      throw const FormatException('Invalid CoinGecko search result.');
    }

    final image = json['large'] is String
        ? json['large'] as String
        : json['thumb'] is String
            ? json['thumb'] as String
            : '';
    final rawRank = json['market_cap_rank'];

    return CoinSearchResult(
      id: id,
      name: name,
      symbol: symbol,
      image: image,
      marketCapRank: rawRank is num ? rawRank.toInt() : null,
    );
  }

  CoinModel toCoinModel() => CoinModel(
        id: id,
        symbol: symbol,
        name: name,
        image: image,
        currentPrice: 0,
        marketCapRank: marketCapRank ?? 0,
        totalVolume: 0,
        high24H: 0,
        low24H: 0,
        priceChange24H: 0,
        marketCapChangePercentage24H: 0,
        sparklineIn7D: SparklineIn7D(price: const []),
      );
}
