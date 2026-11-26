import 'package:cloud_firestore/cloud_firestore.dart';

class AssistantHistoryMessage {
  const AssistantHistoryMessage({required this.role, required this.text});

  final String role;
  final String text;
}

class AssistantHistoryRepository {
  AssistantHistoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static final AssistantHistoryRepository instance =
      AssistantHistoryRepository();

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _messages(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('assistantMessages');

  Future<List<AssistantHistoryMessage>> loadLast30(String userId) async {
    final snapshot = await _messages(userId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();
    final messages = snapshot.docs.map((document) {
      final data = document.data();
      final role = data['role'];
      final text = data['text'];
      final createdAt = data['createdAt'];
      if ((role != 'user' && role != 'assistant') ||
          text is! String ||
          createdAt is! Timestamp) {
        throw const FormatException('Invalid assistant history message.');
      }
      return AssistantHistoryMessage(role: role as String, text: text);
    }).toList();
    return messages.reversed.toList(growable: false);
  }

  Future<void> addMessage({
    required String userId,
    required String role,
    required String text,
  }) async {
    await _messages(userId).add({
      'role': role,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAll(String userId) async {
    final messages = _messages(userId);
    while (true) {
      final snapshot = await messages.limit(400).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }
}
