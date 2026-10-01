import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kaizen/controllers/chat_controller.dart';
import 'package:kaizen/main.dart';
import 'package:kaizen/models/chat_message.dart';
import 'package:kaizen/services/conversation_store.dart';
import 'package:kaizen/services/groq_reply_service.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('AC01 — Unreachable network detection and exact inline copy', () {
    test(
      'SocketException (Network is unreachable) sets exact copy and marks message failed',
      () async {
        final controller = ChatController(
          ConversationStore(),
          replySender: (_) async {
            throw const SocketException(
              'OS Error: Network is unreachable, errno = 101',
            );
          },
        );

        final sendFuture = controller.sendMessage('Building an offline store');
        await Future<void>.delayed(Duration.zero);
        await sendFuture;

        expect(controller.messages, hasLength(1));
        final message = controller.messages.single;
        expect(message.text, 'Building an offline store');
        expect(message.status, MessageStatus.failed);
        expect(controller.replyState, ReplyState.idle);
        expect(
          controller.errorMessage,
          "Can't reach Kaizen right now. Nothing you typed was lost — check your connection and try again.",
        );
      },
    );

    test('DNS failure and connection refused set exact copy', () async {
      final dnsController = ChatController(
        ConversationStore(),
        replySender: (_) async {
          throw const SocketException('Failed host lookup: "api.groq.com"');
        },
      );

      await dnsController.sendMessage('Test DNS');
      await Future<void>.delayed(Duration.zero);
      expect(
        dnsController.errorMessage,
        ChatController.unreachableErrorMessage,
      );

      final refusedController = ChatController(
        ConversationStore(),
        replySender: (_) async {
          throw const SocketException('Connection refused, errno = 111');
        },
      );

      await refusedController.sendMessage('Test refused');
      await Future<void>.delayed(Duration.zero);
      expect(
        refusedController.errorMessage,
        ChatController.unreachableErrorMessage,
      );
    });

    test('isNetworkUnreachable is strictly SocketException and rejects ClientException, TLS, and server errors', () {
      // Client-side reachability failures (request never got a response)
      expect(
        ChatController.isNetworkUnreachable(
          const SocketException('OS Error: Network is unreachable, errno = 101'),
        ),
        isTrue,
      );
      expect(
        ChatController.isNetworkUnreachable(
          const SocketException('Failed host lookup: "api.groq.com"'),
        ),
        isTrue,
      );

      // http.ClientException is deliberately NOT classified as unreachable:
      // GroqReplyService unwraps exceptions directly from dart:io HttpClient,
      // so genuine reachability failures surface as real SocketExceptions.
      // Any ClientException safely falls through to the generic error path.
      expect(
        ChatController.isNetworkUnreachable(
          http.ClientException('Connection refused', Uri.parse('https://api.groq.com')),
        ),
        isFalse,
      );

      // TLS negotiation / certificate failures are NOT reachability failures
      expect(
        ChatController.isNetworkUnreachable(
          const HandshakeException('CERTIFICATE_VERIFY_FAILED: certificate has expired'),
        ),
        isFalse,
      );
      expect(
        ChatController.isNetworkUnreachable(
          const TlsException('Handshake error: TLS negotiation failed'),
        ),
        isFalse,
      );
      expect(
        ChatController.isNetworkUnreachable(
          const HttpException('Service unavailable'),
        ),
        isFalse,
      );

      // Regression test for Lars's finding: StateError carrying server response bodies
      // containing "network error", "unreachable", or "connection failed" must NOT be classified as unreachable
      expect(
        ChatController.isNetworkUnreachable(
          StateError('Groq request failed with HTTP 502: upstream network error'),
        ),
        isFalse,
      );
      expect(
        ChatController.isNetworkUnreachable(
          StateError('Groq request failed with HTTP 503: host unreachable'),
        ),
        isFalse,
      );
      expect(
        ChatController.isNetworkUnreachable(
          StateError('Groq request failed with HTTP 504: connection failed'),
        ),
        isFalse,
      );
    });

    test(
      'ClientException falls through to generic error path and does NOT show unreachable copy',
      () async {
        final clientException = http.ClientException(
          'Connection closed while receiving data',
          Uri.parse('https://api.groq.com'),
        );
        final controller = ChatController(
          ConversationStore(),
          replySender: (_) async => throw clientException,
        );

        await controller.sendMessage('Test client exception');
        await Future<void>.delayed(Duration.zero);

        expect(
          controller.errorMessage,
          'ClientException: Connection closed while receiving data, uri=https://api.groq.com',
        );
        expect(
          controller.errorMessage,
          isNot(ChatController.unreachableErrorMessage),
        );
      },
    );

    test(
      'Server 502 with upstream network error text does NOT show unreachable copy',
      () async {
        final controller = ChatController(
          ConversationStore(),
          replySender: (_) async {
            throw StateError(
              'Groq request failed with HTTP 502: upstream network error',
            );
          },
        );

        await controller.sendMessage('Test 502 upstream error');
        await Future<void>.delayed(Duration.zero);

        expect(
          controller.errorMessage,
          'Groq request failed with HTTP 502: upstream network error',
        );
        expect(
          controller.errorMessage,
          isNot(ChatController.unreachableErrorMessage),
        );
      },
    );

    test('TLS handshake failure does NOT show unreachable copy', () async {
      final controller = ChatController(
        ConversationStore(),
        replySender: (_) async {
          throw const HandshakeException(
            'Handshake error in client (OS Error: CERTIFICATE_VERIFY_FAILED)',
          );
        },
      );

      await controller.sendMessage('Test TLS failure');
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.errorMessage,
        'HandshakeException: Handshake error in client (OS Error: CERTIFICATE_VERIFY_FAILED)',
      );
      expect(
        controller.errorMessage,
        isNot(ChatController.unreachableErrorMessage),
      );
    });

    test('Non-unreachable server errors do NOT show unreachable copy', () async {
      final controller = ChatController(
        ConversationStore(),
        replySender: (_) async {
          throw StateError(
            'Groq request failed with HTTP 500: Internal Server Error',
          );
        },
      );

      await controller.sendMessage('Test server error');
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.errorMessage,
        'Groq request failed with HTTP 500: Internal Server Error',
      );
      expect(
        controller.errorMessage,
        isNot(ChatController.unreachableErrorMessage),
      );
    });

    testWidgets(
      'UI: Sending in airplane mode shows exact inline banner, empties input, and retains failed message in thread',
      (WidgetTester tester) async {
        final store = ConversationStore();
        final controller = ChatController(
          store,
          replySender: (_) async {
            throw const SocketException(
              'OS Error: Network is unreachable, errno = 101',
            );
          },
        );

        await tester.pumpWidget(KaizenApp(controller: controller));
        await tester.pumpAndSettle();

        const inputMessage = 'I want to build an ecommerce store';
        await tester.enterText(find.byType(TextField), inputMessage);
        await tester.pump();

        // Tap the send button.
        final sendButton = find.byType(ElevatedButton);
        expect(tester.widget<ElevatedButton>(sendButton).onPressed, isNotNull);
        await tester.tap(sendButton);
        await tester.pumpAndSettle();

        // 1. User typed text does NOT stay in the input field.
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text ?? '', isEmpty);

        // 2. User text lives in thread as a failed message with retry affordance.
        expect(find.text(inputMessage), findsOneWidget);
        expect(find.text('Not sent. Tap to send again.'), findsOneWidget);

        // 3. Shows exact inline banner copy.
        expect(
          find.text(
            "Can't reach Kaizen right now. Nothing you typed was lost — check your connection and try again.",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'UI: Server error containing "upstream network error" displays actual server message, not unreachability banner',
      (WidgetTester tester) async {
        final store = ConversationStore();
        final controller = ChatController(
          store,
          replySender: (_) async {
            throw StateError(
              'Groq request failed with HTTP 502: upstream network error',
            );
          },
        );

        await tester.pumpWidget(KaizenApp(controller: controller));
        await tester.pumpAndSettle();

        const inputMessage = 'Server error check';
        await tester.enterText(find.byType(TextField), inputMessage);
        await tester.pump();
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // 1. Input field is cleared.
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text ?? '',
          isEmpty,
        );

        // 2. Failed turn tag shown.
        expect(find.text(inputMessage), findsOneWidget);
        expect(find.text('Not sent. Tap to send again.'), findsOneWidget);

        // 3. Banner displays the actual server error text, NOT the unreachable copy.
        expect(
          find.text('Groq request failed with HTTP 502: upstream network error'),
          findsOneWidget,
        );
        expect(
          find.text(ChatController.unreachableErrorMessage),
          findsNothing,
        );
      },
    );
  });

  group('AC02 — Connection restored, retry flow completes without retyping', () {
    test(
      'Retrying a failed message reuses message ID and completes when connection returns',
      () async {
        var isOnline = false;
        final store = ConversationStore();
        final controller = ChatController(
          store,
          replySender: (_) async {
            if (!isOnline) {
              throw const SocketException('Network unreachable');
            }
            return 'Here is your starter shortlist:\nSupabase';
          },
        );

        await controller.sendMessage('Build an app');
        await Future<void>.delayed(Duration.zero);

        expect(controller.messages, hasLength(1));
        final failedMessage = controller.messages.single;
        final originalId = failedMessage.id;
        expect(failedMessage.status, MessageStatus.failed);
        expect(
          controller.errorMessage,
          ChatController.unreachableErrorMessage,
        );

        // Connection returns.
        isOnline = true;
        await controller.retry(originalId);
        await Future<void>.delayed(Duration.zero);

        expect(controller.replyState, ReplyState.received);
        expect(controller.errorMessage, isNull);
        expect(controller.messages, hasLength(2));

        final userMessage = controller.messages.first;
        expect(userMessage.id, originalId);
        expect(userMessage.text, 'Build an app');
        expect(userMessage.status, MessageStatus.sent);

        final assistantMessage = controller.messages.last;
        expect(assistantMessage.sender, MessageSender.assistant);
        expect(assistantMessage.text, contains('Supabase'));

        // Persistence verification: exactly 2 messages in store.
        final stored = await store.loadThread();
        expect(stored, hasLength(2));
        expect(stored.first.id, originalId);
        expect(stored.first.status, MessageStatus.sent);
      },
    );

    testWidgets(
      'UI: Tapping retry banner dispatches retry and displays reply without retyping',
      (WidgetTester tester) async {
        var isOnline = false;
        final store = ConversationStore();
        final controller = ChatController(
          store,
          replySender: (_) async {
            if (!isOnline) {
              throw const SocketException('No network connection');
            }
            return 'Tailored reply for coffee store';
          },
        );

        await tester.pumpWidget(KaizenApp(controller: controller));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Coffee store app');
        await tester.pump();
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Banner is visible, input is empty.
        expect(
          find.text(ChatController.unreachableErrorMessage),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          isEmpty,
        );

        // Connection restored, tap retry banner.
        isOnline = true;
        await tester.tap(find.text(ChatController.unreachableErrorMessage));
        await tester.pumpAndSettle();

        // Banner gone, reply arrives, input remains untouched.
        expect(find.text(ChatController.unreachableErrorMessage), findsNothing);
        expect(find.text('Tailored reply for coffee store'), findsOneWidget);
        expect(find.text('Coffee store app'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          isEmpty,
        );
      },
    );
  });

  group('AC03 — Flaky connection and exchange-token staleness guards', () {
    testWidgets(
      'Late network failure from superseded exchange does not poison active retry exchange',
      (WidgetTester tester) async {
        // Uses Flutter's FakeAsync zone via testWidgets to control time deterministically.
        // tester.pump(duration) advances the clock past the 30s timeout boundary immediately,
        // eliminating any wall-clock race conditions or CI timing flakiness.
        final attempt1 = Completer<String>();
        final attempt2 = Completer<String>();
        var requestCount = 0;

        final store = ConversationStore();
        final controller = ChatController(
          store,
          replySender: (_) {
            requestCount++;
            return requestCount == 1 ? attempt1.future : attempt2.future;
          },
          timeoutDuration: const Duration(seconds: 30),
        );

        final send = controller.sendMessage('Flaky connection test');
        // Advance fake clock by 31 seconds: deterministically triggers the 30s timeout.
        await tester.pump(const Duration(seconds: 31));
        expect(controller.replyState, ReplyState.noAnswer);

        final originalId = controller.messages.single.id;

        // User retries — starts exchange 2 with a new exchange token.
        final retry = controller.retry(originalId);
        await tester.pump();
        expect(requestCount, 2);
        expect(controller.replyState, ReplyState.waiting);

        // Attempt 1 finally fails with SocketException while attempt 2 is in-flight.
        attempt1.completeError(
          const SocketException('Connection reset by peer'),
        );
        await tester.pump();

        // Staleness guard MUST prevent attempt 1 from poisoning exchange 2.
        expect(controller.replyState, ReplyState.waiting);
        expect(controller.errorMessage, isNull);
        expect(controller.messages.single.status, MessageStatus.sent);

        // Attempt 2 completes successfully.
        attempt2.complete('Successful response on retry');
        await tester.pump();
        await retry;
        await send;

        expect(controller.replyState, ReplyState.received);
        expect(controller.messages, hasLength(2));
        expect(controller.messages.first.id, originalId);
        expect(controller.messages.first.status, MessageStatus.sent);
        expect(
          controller.messages.last.text,
          'Successful response on retry',
        );

        // Persistence has exactly one user message and one reply.
        final thread = await store.loadThread();
        expect(thread, hasLength(2));
        expect(thread.first.id, originalId);
      },
    );

    testWidgets(
      'Late reply from superseded exchange does not duplicate assistant message',
      (WidgetTester tester) async {
        // Uses FakeAsync via testWidgets for deterministic clock advancement past timeout.
        final attempt1 = Completer<String>();
        final attempt2 = Completer<String>();
        var requestCount = 0;

        final store = ConversationStore();
        final controller = ChatController(
          store,
          replySender: (_) {
            requestCount++;
            return requestCount == 1 ? attempt1.future : attempt2.future;
          },
          timeoutDuration: const Duration(seconds: 30),
        );

        final send = controller.sendMessage('Superseded reply test');
        // Advance fake clock deterministically past the 30-second timeout.
        await tester.pump(const Duration(seconds: 31));
        expect(controller.replyState, ReplyState.noAnswer);
        final messageId = controller.messages.single.id;

        final retry = controller.retry(messageId);
        await tester.pump();

        // Attempt 1 arrives late with a reply.
        attempt1.complete('Stale reply from attempt 1');
        await tester.pump();

        // Stale reply must be discarded.
        expect(
          controller.messages.where(
            (m) => m.text == 'Stale reply from attempt 1',
          ),
          isEmpty,
        );

        // Attempt 2 completes.
        attempt2.complete('Fresh reply from attempt 2');
        await tester.pump();
        await retry;
        await send;

        expect(
          controller.messages.where(
            (m) => m.sender == MessageSender.assistant,
          ),
          hasLength(1),
        );
        expect(controller.messages.last.text, 'Fresh reply from attempt 2');
      },
    );

    test(
      'Multiple flaky retry failures leave exactly one user message in thread and store',
      () async {
        var attempts = 0;
        final store = ConversationStore();
        final controller = ChatController(
          store,
          replySender: (_) async {
            attempts++;
            if (attempts <= 2) {
              throw const SocketException('Connection lost partway through');
            }
            return 'Third attempt succeeded';
          },
        );

        await controller.sendMessage('Multiple retry test');
        await Future<void>.delayed(Duration.zero);

        // Attempt 1 failed.
        expect(controller.messages, hasLength(1));
        final originalId = controller.messages.single.id;
        expect(controller.messages.single.status, MessageStatus.failed);

        // Attempt 2 failed.
        await controller.retry(originalId);
        await Future<void>.delayed(Duration.zero);
        expect(controller.messages, hasLength(1));
        expect(controller.messages.single.id, originalId);
        expect(controller.messages.single.status, MessageStatus.failed);

        // Attempt 3 succeeded.
        await controller.retry(originalId);
        await Future<void>.delayed(Duration.zero);

        expect(controller.messages, hasLength(2));
        expect(controller.messages.first.id, originalId);
        expect(controller.messages.first.status, MessageStatus.sent);
        expect(controller.messages.last.text, 'Third attempt succeeded');

        final stored = await store.loadThread();
        expect(stored, hasLength(2));
        expect(stored.first.id, originalId);
        expect(stored.first.status, MessageStatus.sent);
      },
    );
  });

  group('AC04 — No fallback/cached/mock recommendations when unreachable', () {
    test(
      'Unreachable network produces no mock or cached recommendations in controller',
      () async {
        final controller = ChatController(
          ConversationStore(),
          replySender: (_) async {
            throw const SocketException('No internet');
          },
        );

        await controller.sendMessage('Need recommendations');
        await Future<void>.delayed(Duration.zero);

        // Zero assistant messages.
        final assistantMessages = controller.messages.where(
          (m) => m.sender == MessageSender.assistant,
        );
        expect(assistantMessages, isEmpty);
      },
    );

    test(
      'GroqReplyService throws network error and never returns fallback shortlist',
      () async {
        final client = _FailingClient(
          const SocketException('Failed host lookup: "api.groq.com"'),
        );
        final service = GroqReplyService(apiKey: 'real-key', client: client);

        expect(
          () => service.generateReply('I want to build an ecommerce store'),
          throwsA(isA<SocketException>()),
        );
      },
    );

    testWidgets(
      'UI: Unreachable state displays no recommendation content in the thread',
      (WidgetTester tester) async {
        final controller = ChatController(
          ConversationStore(),
          replySender: (_) async {
            throw const SocketException('Network is down');
          },
        );

        await tester.pumpWidget(KaizenApp(controller: controller));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'E-commerce store with Stripe',
        );
        await tester.pump();
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // No recommendation names, no starter shortlist phrases.
        expect(find.textContaining('Starter shortlist'), findsNothing);
        expect(find.textContaining('Shopify'), findsNothing);
        expect(find.textContaining('Supabase'), findsNothing);
        expect(find.textContaining('Firebase'), findsNothing);
        expect(find.textContaining('Vercel'), findsNothing);
      },
    );
  });
}

class _FailingClient extends http.BaseClient {
  _FailingClient(this.error);

  final Object error;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw error;
  }
}
