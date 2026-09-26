import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen/services/groq_reply_service.dart';

void main() {
  final apiKey = Platform.environment['GROQ_LIVE_TEST_KEY'] ?? '';
  test(
    'real Groq structured extraction parses and generates a constrained shortlist',
    () async {
      final service = GroqReplyService(apiKey: apiKey);

      final reply = await service
          .generateReply(
            'I am building a group chat app for a small community. '
            'It must work on Android and support realtime group messaging. '
            'My hard budget is 25 US dollars per month.',
          )
          .timeout(const Duration(seconds: 60));

      expect(reply, contains('Here is a starter shortlist'));
      expect(reply, contains('Tradeoff:'));
      final normalizedReply = reply.toLowerCase();
      expect(normalizedReply, contains('android'));
      expect(normalizedReply, contains('realtime group messaging'));
      expect(reply, contains('hard cap'));
      expect(reply, contains('25'));
    },
    skip: apiKey.isEmpty
        ? 'Set GROQ_LIVE_TEST_KEY at test runtime to enable this live API check.'
        : false,
  );

  test(
    'real Groq extracts a free-only constraint as a zero hard budget',
    () async {
      final service = GroqReplyService(apiKey: apiKey);

      final reply = await service
          .generateReply(
            'I am building a small online storefront. Only free tools, please.',
          )
          .timeout(const Duration(seconds: 60));

      expect(reply, contains('hard cap of USD 0'));
      expect(reply, contains('fits within'));
      expect(reply, contains('exceeds'));
      expect(reply, contains('Shopify'));
    },
    skip: apiKey.isEmpty
        ? 'Set GROQ_LIVE_TEST_KEY at test runtime to enable this live API check.'
        : false,
  );
}
