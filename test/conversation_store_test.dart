import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kaizen/models/chat_message.dart';
import 'package:kaizen/services/conversation_store.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('saves and loads a thread', () async {
    final store = ConversationStore();
    final messages = [
      ChatMessage(
        id: '1',
        text: 'Hello',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ),
    ];

    await store.saveThread(messages);
    final loaded = await store.loadThread();

    expect(loaded.length, 1);
    expect(loaded.first.text, 'Hello');
    expect(loaded.first.status, MessageStatus.sent);
  });

  test('appends to an existing thread across multiple saves', () async {
    final store = ConversationStore();
    final first = [
      ChatMessage(
        id: '1',
        text: 'Hi',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ),
    ];
    await store.saveThread(first);

    final second = [
      ...first,
      ChatMessage(
        id: '2',
        text: 'Reply',
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ),
    ];
    await store.saveThread(second);

    final loaded = await store.loadThread();
    expect(loaded.length, 2);
    expect(loaded.last.text, 'Reply');
  });

  test('resending with the same id does not duplicate the message', () async {
    final store = ConversationStore();
    final message = ChatMessage(
      id: 'abc',
      text: 'Hello',
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
    );

    await store.upsertMessage(message);
    await store.upsertMessage(message.copyWith(status: MessageStatus.sent));

    final loaded = await store.loadThread();
    expect(loaded.length, 1);
    expect(loaded.first.status, MessageStatus.sent);
  });

  test('updating a message preserves its position in the thread', () async {
    final store = ConversationStore();
    final messages = List.generate(
      3,
      (index) => ChatMessage(
        id: '$index',
        text: 'Message $index',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
        status: MessageStatus.pending,
      ),
    );
    await store.saveThread(messages);

    await store.upsertMessage(messages[1].copyWith(status: MessageStatus.sent));

    final loaded = await store.loadThread();
    expect(loaded.map((message) => message.id), ['0', '1', '2']);
    expect(loaded[1].status, MessageStatus.sent);
  });

  test('loads a realistic thread and records the load time', () async {
    final store = ConversationStore();
    final messages = List.generate(
      40,
      (index) => ChatMessage(
        id: '$index',
        text: 'Message $index with realistic conversation content.',
        sender: index.isEven ? MessageSender.user : MessageSender.assistant,
        timestamp: DateTime.now().subtract(Duration(minutes: 40 - index)),
        status: MessageStatus.sent,
      ),
    );
    await store.saveThread(messages);

    final stopwatch = Stopwatch()..start();
    final loaded = await store.loadThread();
    stopwatch.stop();
    debugPrint(
      '[Perf] loaded ${loaded.length} messages in '
      '${stopwatch.elapsedMilliseconds}ms',
    );

    expect(loaded.length, 40);
  });

  test('saves and loads a draft', () async {
    final store = ConversationStore();
    await store.saveDraft('unsent text');
    expect(await store.loadDraft(), 'unsent text');
  });
}
