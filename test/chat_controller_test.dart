import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kaizen/controllers/chat_controller.dart';
import 'package:kaizen/models/chat_message.dart';
import 'package:kaizen/services/conversation_store.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('restored pending messages resolve to noAnswer', () async {
    final store = ConversationStore();
    await store.saveThread([
      ChatMessage(
        id: 'pending-1',
        text: 'Hello',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
        status: MessageStatus.pending,
      ),
    ]);
    final controller = ChatController(store);

    await controller.loadInitialState();

    expect(controller.replyState, ReplyState.noAnswer);
    expect(controller.messages.single.status, MessageStatus.pending);
  });

  test('a reply appends an assistant message and resolves the slot', () async {
    final store = ConversationStore();
    final controller = ChatController(
      store,
      replySender: (_) async => 'Hi there',
    );

    await controller.sendMessage('Hello');

    expect(controller.replyState, ReplyState.received);
    expect(controller.messages.length, 2);
    expect(controller.messages.last.sender, MessageSender.assistant);
  });

  test('a waiting exchange becomes noAnswer after the timeout', () async {
    final replyCompleter = Completer<String>();
    final controller = ChatController(
      ConversationStore(),
      replySender: (_) => replyCompleter.future,
      timeoutDuration: const Duration(milliseconds: 1),
    );

    final send = controller.sendMessage('Hello');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.replyState, ReplyState.noAnswer);
    expect(controller.messages.single.status, MessageStatus.pending);
    replyCompleter.complete('');
    await send;
  });

  test('retry after noAnswer starts one replacement request', () async {
    final firstReply = Completer<String>();
    final secondReply = Completer<String>();
    var requests = 0;
    final controller = ChatController(
      ConversationStore(),
      replySender: (_) {
        requests++;
        return requests == 1 ? firstReply.future : secondReply.future;
      },
      timeoutDuration: const Duration(milliseconds: 1),
    );

    final send = controller.sendMessage('Hello');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final messageId = controller.messages.single.id;

    final retry = controller.retry(messageId);
    final secondRetry = controller.retry(messageId);
    await Future<void>.delayed(Duration.zero);

    expect(requests, 2);
    expect(controller.replyState, ReplyState.waiting);
    secondReply.complete('');
    firstReply.complete('');
    await Future.wait([send, retry, secondRetry]);
  });

  test('late reply from a superseded exchange is dropped', () async {
    final firstReply = Completer<String>();
    final secondReply = Completer<String>();
    var requests = 0;
    final controller = ChatController(
      ConversationStore(),
      replySender: (_) {
        requests++;
        return requests == 1 ? firstReply.future : secondReply.future;
      },
      timeoutDuration: const Duration(milliseconds: 1),
    );

    final send = controller.sendMessage('Hello');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final messageId = controller.messages.single.id;
    final retry = controller.retry(messageId);
    await Future<void>.delayed(Duration.zero);

    firstReply.complete('Old reply');
    await Future<void>.delayed(Duration.zero);
    expect(
      controller.messages.where((message) => message.text == 'Old reply'),
      isEmpty,
    );

    secondReply.complete('New reply');
    await retry;
    expect(controller.messages.last.text, 'New reply');
    await send;
  });

  test('retry does not start another request while one is in flight', () async {
    final replyCompleter = Completer<String>();
    var requests = 0;
    final controller = ChatController(
      ConversationStore(),
      replySender: (_) {
        requests++;
        return replyCompleter.future;
      },
      timeoutDuration: const Duration(seconds: 1),
    );

    final send = controller.sendMessage('Hello');
    await Future<void>.delayed(Duration.zero);
    final messageId = controller.messages.single.id;

    await controller.retry(messageId);

    expect(requests, 1);
    replyCompleter.complete('');
    await send;
  });
}
