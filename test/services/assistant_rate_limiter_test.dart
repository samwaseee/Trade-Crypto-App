import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/Services/assistant_service.dart';

void main() {
  test('limits messages to ten in a rolling minute', () {
    var now = DateTime(2026, 11, 26, 12);
    final limiter = AssistantRateLimiter(clock: () => now);

    for (var i = 0; i < 5; i++) {
      limiter.checkAndRecord();
    }
    now = now.add(const Duration(seconds: 30));
    for (var i = 0; i < 5; i++) {
      limiter.checkAndRecord();
    }

    expect(
      () => limiter.checkAndRecord(),
      throwsA(
        isA<AssistantException>().having(
          (error) => error.message,
          'message',
          contains('Please slow down'),
        ),
      ),
    );

    now = now.add(const Duration(seconds: 30));
    for (var i = 0; i < 5; i++) {
      limiter.checkAndRecord();
    }
    expect(
      () => limiter.checkAndRecord(),
      throwsA(isA<AssistantException>()),
    );
  });
}
