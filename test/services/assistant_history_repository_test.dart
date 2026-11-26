import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/Services/assistant_history_repository.dart';

void main() {
  test('loads the latest 30 assistant messages in chronological order',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = AssistantHistoryRepository(firestore: firestore);
    final messages = firestore
        .collection('users')
        .doc('alice')
        .collection('assistantMessages');

    for (var i = 0; i < 35; i++) {
      await messages.doc('message-$i').set({
        'role': i.isEven ? 'user' : 'assistant',
        'text': 'Message $i',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(i),
      });
    }

    final history = await repository.loadLast30('alice');

    expect(history, hasLength(30));
    expect(history.first.text, 'Message 5');
    expect(history.last.text, 'Message 34');
  });

  test('deletes saved assistant messages for a new chat', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = AssistantHistoryRepository(firestore: firestore);
    final messages = firestore
        .collection('users')
        .doc('alice')
        .collection('assistantMessages');
    await messages.doc('message-1').set({
      'role': 'user',
      'text': 'Hello',
      'createdAt': Timestamp.now(),
    });

    await repository.deleteAll('alice');

    expect((await messages.get()).docs, isEmpty);
  });
}
