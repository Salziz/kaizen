import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

class ConversationStore {
  static const _threadKey = 'conversation_thread';
  static const _draftKey = 'draft_text';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  Future<void> _writeLock = Future.value();

  Future<List<ChatMessage>> loadThread() async {
    final raw = await _prefs.getString(_threadKey);
    if (raw == null) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('thread payload must be a list');
      }

      final messages = <ChatMessage>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        try {
          messages.add(
            ChatMessage.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          continue;
        }
      }
      return messages;
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

  Future<void> upsertMessage(ChatMessage message) {
    final result = _writeLock.then((_) async {
      final thread = await loadThread();
      final index = thread.indexWhere((existing) => existing.id == message.id);
      if (index >= 0) {
        thread[index] = message;
      } else {
        thread.add(message);
      }
      await saveThread(thread);
    });

    _writeLock = result.catchError((_) {});
    return result;
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
