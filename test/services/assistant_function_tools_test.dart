import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/Model/coinModel.dart';
import 'package:my_crypto/Services/assistant_service.dart';
import 'package:my_crypto/Services/market_repository.dart';
import 'package:my_crypto/Services/portfolio_repository.dart';

class _FakeAssistantModel implements AssistantChatModel {
  final calls = <String>[];
  final results = <String, Map<String, Object?>>{};
  bool receivedMutableHistory = false;

  @override
  Stream<String> sendMessage(
    String message, {
    required List<Content> history,
    required List<AutoFunctionDeclaration> functions,
  }) async* {
    final historyLength = history.length;
    try {
      history.add(Content.text('mutable history probe'));
      history.removeLast();
      receivedMutableHistory = history.length == historyLength;
    } on UnsupportedError {
      receivedMutableHistory = false;
    }
    calls.addAll(functions.map((function) => function.name));
    final priceTool = functions.singleWhere((f) => f.name == 'getCoinPrice');
    final portfolioTool = functions.singleWhere((f) => f.name == 'getPortfolio');
    results['getCoinPrice'] = await priceTool.callable({'coinId': 'bitcoin'});
    results['getPortfolio'] = await portfolioTool.callable({});
    yield 'Read-only data received.';
  }
}

class _SilentToolModel implements AssistantChatModel {
  @override
  Stream<String> sendMessage(
    String message, {
    required List<Content> history,
    required List<AutoFunctionDeclaration> functions,
  }) async* {
    final priceTool = functions.singleWhere((f) => f.name == 'getCoinPrice');
    await priceTool.callable({'coinId': 'bitcoin'});
  }
}

class _MalformedResponseModel implements AssistantChatModel {
  @override
  Stream<String> sendMessage(
    String message, {
    required List<Content> history,
    required List<AutoFunctionDeclaration> functions,
  }) async* {
    throw const FormatException('Unexpected HTML response');
  }
}

class _BusyAssistantModel implements AssistantChatModel {
  @override
  Stream<String> sendMessage(
    String message, {
    required List<Content> history,
    required List<AutoFunctionDeclaration> functions,
  }) async* {
    throw FirebaseAIException(
      'This model is currently experiencing high demand. Please try again later.',
    );
  }
}

class _PermissionDeniedFirestore extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }
}

class _FakeMarketRepository extends MarketRepository {
  _FakeMarketRepository(this.coins);

  final List<CoinModel> coins;

  @override
  Future<List<CoinModel>> getMarkets({bool force = false}) async => coins;
}

CoinModel _bitcoin() => CoinModel(
      id: 'bitcoin',
      symbol: 'btc',
      name: 'Bitcoin',
      image: '',
      currentPrice: 65000,
      marketCapRank: 1,
      totalVolume: 0,
      high24H: 66000,
      low24H: 64000,
      priceChange24H: 0,
      priceChangePercentage24h: 0,
      marketCapChangePercentage24H: 0,
      sparklineIn7D: SparklineIn7D(price: const []),
    );

void main() {
  test('empty model response after a tool call returns useful read-only data',
      () async {
    final service = AssistantService(
      chatModel: _SilentToolModel(),
      marketRepository: _FakeMarketRepository([_bitcoin()]),
    );

    final response = await service
        .send('What is Bitcoin worth?', history: const [], userId: null)
        .toList();

    expect(response, ['bitcoin is currently \$65,000.00 USD.']);
  });

  test('high-demand response is not reported as a missing model', () async {
    final service = AssistantService(chatModel: _BusyAssistantModel());

    await expectLater(
      service.send('Hello', history: const [], userId: null).toList(),
      throwsA(
        isA<AssistantException>()
            .having((error) => error.message, 'message', contains('busy'))
            .having(
              (error) => error.message,
              'message',
              isNot(contains('Model not found')),
            ),
      ),
    );
  });

  test('quota permission failure shows friendly retry guidance', () async {
    final service = AssistantService(
      chatModel: _MalformedResponseModel(),
      firestore: _PermissionDeniedFirestore(),
    );

    await expectLater(
      service.send('Hello', history: const [], userId: 'alice').toList(),
      throwsA(
        isA<AssistantException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('Please try again shortly'),
            isNot(contains('Firestore')),
          ),
        ),
      ),
    );
  });

  test('malformed Firebase AI response shows a friendly retry message',
      () async {
    final service = AssistantService(chatModel: _MalformedResponseModel());

    await expectLater(
      service.send('Hello', history: const [], userId: null).toList(),
      throwsA(
        isA<AssistantException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('Please try again shortly'),
            isNot(contains('App Check')),
          ),
        ),
      ),
    );
  });

  test('fake model can call only the read-only market and portfolio tools',
      () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('alice').set({'wallet': 2500});
    await firestore
        .collection('users')
        .doc('alice')
        .collection('transactions')
        .doc('position-1')
        .set({
      'type': 'Buy',
      'coinId': 'bitcoin',
      'amount': 0.1,
      'price': 60000,
      'cost': 6000,
      'date': '2026-11-26T00:00:00.000',
    });
    final model = _FakeAssistantModel();
    final service = AssistantService(
      chatModel: model,
      firestore: firestore,
      marketRepository: _FakeMarketRepository([_bitcoin()]),
      portfolioRepository: PortfolioRepository(firestore: firestore),
    );

    final response = await service
        .send('Check my Bitcoin position.', history: const [], userId: 'alice')
        .toList();

    expect(response, ['Read-only data received.']);
    expect(model.receivedMutableHistory, isTrue);
    expect(model.calls.toSet(), {'getCoinPrice', 'getPortfolio'});
    expect(model.results['getCoinPrice'], {
      'coinId': 'bitcoin',
      'name': 'Bitcoin',
      'symbol': 'btc',
      'priceUsd': 65000,
    });
    expect(model.results['getPortfolio']?['cashBalanceUsd'], 2500.0);
    expect(model.results['getPortfolio']?['openPositions'], [
      {
        'coinId': 'bitcoin',
        'side': 'long',
        'amount': 0.1,
        'entryPriceUsd': 60000.0,
        'costUsd': 6000.0,
      },
    ]);
  });
}
