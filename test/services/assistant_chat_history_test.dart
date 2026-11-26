import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto/Services/assistant_service.dart';

List<String> _roles(List<Content> history) =>
    history.map((content) => content.role!).toList();

List<String> _texts(List<Content> history) => history
    .map((content) => content.parts.whereType<TextPart>().single.text)
    .toList();

void main() {
  test('drops leading assistant messages', () {
    final history = buildChatHistory([
      (fromUser: false, text: 'Orphaned response'),
      (fromUser: true, text: 'Question'),
      (fromUser: false, text: 'Answer'),
    ]);

    expect(_roles(history), ['user', 'model']);
    expect(_texts(history), ['Question', 'Answer']);
  });

  test('merges consecutive user messages to alternate roles', () {
    final history = buildChatHistory([
      (fromUser: true, text: 'First question'),
      (fromUser: true, text: 'Follow-up'),
      (fromUser: false, text: 'Answer'),
    ]);

    expect(_roles(history), ['user', 'model']);
    expect(_texts(history), ['First question\n\nFollow-up', 'Answer']);
  });

  test('returns an empty history for an empty list', () {
    expect(buildChatHistory(const []), isEmpty);
  });

  test('excludes error messages and their partial replies', () {
    final history = buildChatHistoryFromMessages([
      (fromUser: true, text: 'Question', isError: false),
      (fromUser: false, text: 'Partial reply', isError: false),
      (fromUser: false, text: 'Stream failed', isError: true),
    ]);

    expect(_roles(history), ['user']);
    expect(_texts(history), ['Question']);
  });
}
