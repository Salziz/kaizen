import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

class ConversationStore {
  static const _threadKey = 'conversation_thread';
  static const _draftKey = 'draft_text';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<List<ChatMessage>> loadThread() async {
    final raw = await _prefs.getString(_threadKey);
    if (raw == null) {
      return [];
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (message) => ChatMessage.fromJson(message as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      await _prefs.remove(_threadKey);
      return [];
    }
  }

  Future<void> saveThread(List<ChatMessage> messages) async {
    final encoded = jsonEncode(
      messages.map((message) => message.toJson()).toList(),
    );
    await _prefs.setString(_threadKey, encoded);
  }

  Future<void> upsertMessage(ChatMessage message) async {
    final thread = await loadThread();
    final index = thread.indexWhere((existing) => existing.id == message.id);
    if (index >= 0) {
      thread[index] = message;
    } else {
      thread.add(message);
    }
    await saveThread(thread);
  }

  Future<String> loadDraft() async {
    return await _prefs.getString(_draftKey) ?? '';
  }

  Future<void> saveDraft(String text) async {
    await _prefs.setString(_draftKey, text);
  }

  Future<void> clearDraft() async {
    await _prefs.remove(_draftKey);
  }
}
