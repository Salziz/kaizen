import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen/controllers/chat_controller.dart';
import 'package:kaizen/services/groq_reply_service.dart';

void main() {
  // This test deliberately does NOT inject a fake client or a fake
  // exception, and does NOT hit the real Groq endpoint. It uses the
  // real production GroqReplyService (no `client:` override, so the
  // actual _UnwrappingIOClient is exercised), pointed at a local port
  // guaranteed to have nothing listening on it — a genuine "connection
  // refused" from the real OS socket layer, fast and offline-safe.
  //
  // This is the test Lars's review said was missing: earlier tests
  // injected SocketException directly, which proves nothing about
  // whether the real client stack still surfaces it unwrapped.
  test(
    'the production client surfaces a real, unwrapped SocketException '
    'on genuine connection refusal, and isNetworkUnreachable correctly '
    'classifies it',
    () async {
      // Port 1 is a reserved, essentially-never-bound port — connecting
      // to localhost on it reliably produces "connection refused"
      // without needing internet access or airplane mode simulation.
      final service = GroqReplyService(
        apiKey: 'test-key',
        endpoint: Uri.parse('http://127.0.0.1:1/'),
      );

      Object? caught;
      try {
        await service.generateReply('test prompt');
      } catch (error) {
        caught = error;
      }

      expect(caught, isNotNull);
      expect(
        caught,
        isA<SocketException>(),
        reason:
            'The real client must surface an unwrapped SocketException '
            'for a genuine connection failure. If this fails, either '
            'the production client is wrapping exceptions again (the '
            'bug this fix addresses), or the test environment resolved '
            'this connection differently than expected.',
      );
      expect(ChatController.isNetworkUnreachable(caught!), isTrue);
    },
  );
}
