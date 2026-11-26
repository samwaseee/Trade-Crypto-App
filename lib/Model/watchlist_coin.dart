class WatchlistCoin {
  const WatchlistCoin({
    required this.id,
    required this.name,
    required this.symbol,
    required this.image,
  });

  final String id;
  final String name;
  final String symbol;
  final String image;

  static WatchlistCoin? fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final name = data['name'];
    final symbol = data['symbol'];
    final image = data['image'];

    if (name is! String ||
        name.isEmpty ||
        name.length > 100 ||
        symbol is! String ||
        symbol.isEmpty ||
        symbol.length > 20 ||
        image is! String ||
        image.length > 2048) {
      return null;
    }

    return WatchlistCoin(
      id: id,
      name: name,
      symbol: symbol,
      image: image,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'symbol': symbol,
        'image': image,
      };
}
