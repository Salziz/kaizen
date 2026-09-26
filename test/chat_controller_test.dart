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

  test(
    'restored pending messages are treated as failed instead of ambiguous',
    () async {
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

      expect(controller.replyState, ReplyState.idle);
      expect(controller.messages.single.status, MessageStatus.failed);
    },
  );

  test('restores a sent user message without a reply as noAnswer', () async {
    final store = ConversationStore();
    await store.saveThread([
      ChatMessage(
        id: 'sent-1',
        text: 'Hello',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ),
    ]);
    final controller = ChatController(store);

    await controller.loadInitialState();

    expect(controller.replyState, ReplyState.noAnswer);
  });

  test('sendMessage resolves before the reply completes', () async {
    final replyCompleter = Completer<String>();
    final controller = ChatController(
      ConversationStore(),
      replySender: (_) => replyCompleter.future,
    );

    final sendFuture = controller.sendMessage('Hello');
    await Future<void>.delayed(Duration.zero);

    expect(controller.messages.single.status, MessageStatus.sent);
    expect(controller.replyState, ReplyState.waiting);

    replyCompleter.complete('Hi there');
    await sendFuture;
  });

  test('a reply appends an assistant message and resolves the slot', () async {
    final store = ConversationStore();
    final controller = ChatController(
      store,
      replySender: (_) async => 'Hi there',
    );

    final sendFuture = controller.sendMessage('Hello');
    await Future<void>.delayed(Duration.zero);

    expect(controller.replyState, ReplyState.received);
    expect(controller.messages.length, 2);
    expect(controller.messages.last.sender, MessageSender.assistant);
    await sendFuture;
  });

  test(
    'recommendation extraction receives prior user facts, not assistant replies',
    () async {
      final prompts = <String>[];
      final controller = ChatController(
        ConversationStore(),
        replySender: (prompt) async {
          prompts.add(prompt);
          return 'Clarifying question';
        },
      );

      await controller.sendMessage('I am building a group chat app.');
      await Future<void>.delayed(Duration.zero);
      await controller.sendMessage(
        'It must support Android and realtime messaging.',
      );
      await Future<void>.delayed(Duration.zero);

      expect(prompts, hasLength(2));
      expect(prompts.last, contains('I am building a group chat app.'));
      expect(prompts.last, contains('Android and realtime messaging.'));
      expect(prompts.last, isNot(contains('Clarifying question')));
    },
  );

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
    expect(controller.messages.single.status, MessageStatus.sent);
    replyCompleter.complete('');
    await send;
  });

  test('a completed exchange records its round-trip duration', () async {
    final store = ConversationStore();
    final controller = ChatController(store, replySender: (_) async => 'reply');

    await controller.sendMessage('Hello');
    await Future<void>.delayed(Duration.zero);

    expect((await store.loadRoundTripLog()), hasLength(1));
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

  test(
    'reused message ids reject stale replies from an earlier exchange',
    () async {
      final firstReply = Completer<String>();
      final secondReply = Completer<String>();
      var calls = 0;
      final controller = ChatController(
        ConversationStore(),
        replySender: (_) {
          calls += 1;
          return calls == 1 ? firstReply.future : secondReply.future;
        },
        timeoutDuration: const Duration(milliseconds: 1),
      );

      final firstSend = controller.sendMessage('A');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final originalId = controller.messages.first.id;
      final retryFuture = controller.retry(originalId);
      await Future<void>.delayed(Duration.zero);

      firstReply.complete('stale reply');
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.messages.where((message) => message.text == 'stale reply'),
        isEmpty,
      );

      secondReply.complete('fresh reply');
      await retryFuture;
      expect(
        controller.messages.where((message) => message.text == 'fresh reply'),
        hasLength(1),
      );

      await firstSend;
    },
  );

  test(
    'a stale exchange error does not poison the active reply state',
    () async {
      final completerA = Completer<String>();
      final completerB = Completer<String>();
      var callCount = 0;

      final controller = ChatController(
        ConversationStore(),
        replySender: (_) {
          callCount++;
          return callCount == 1 ? completerA.future : completerB.future;
        },
      );

      final firstSend = controller.sendMessage('A');
      final secondSend = controller.sendMessage('B');

      completerB.complete('reply to B');
      await Future<void>.delayed(Duration.zero);
      expect(controller.replyState, ReplyState.received);

      completerA.completeError(Exception('A failed'));
      await Future<void>.delayed(Duration.zero);

      final a = controller.messages.firstWhere(
        (message) => message.text == 'A',
      );
      expect(a.status, MessageStatus.sent);
      expect(controller.replyState, ReplyState.received);
      expect(controller.errorMessage, isNull);

      await Future.wait<void>([firstSend, secondSend]);
    },
  );

  test('an active exchange error marks a dispatched message failed', () async {
    final error = Completer<String>();
    final controller = ChatController(
      ConversationStore(),
      replySender: (_) => error.future,
    );

    final send = controller.sendMessage('Hello');
    await Future<void>.delayed(Duration.zero);
    error.completeError(Exception('network failed'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.messages.single.status, MessageStatus.failed);
    expect(controller.replyState, ReplyState.idle);
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
