import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:kaizen/services/groq_reply_service.dart';

void main() {
  test(
    'extracts project facts and returns a deterministic shortlist',
    () async {
      final client = _FakeClient(
        http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'projectType': 'group chat app',
                    'budget': null,
                    'platforms': ['android'],
                    'features': ['realtime messaging'],
                  }),
                },
              },
            ],
          }),
          200,
        ),
      );
      final service = GroqReplyService(apiKey: 'test-key', client: client);

      final reply = await service.generateReply(
        'I am building a group chat app for Android with realtime messaging.',
      );
      expect(reply, contains('Here is a starter shortlist'));
      expect(reply, contains('Supabase'));
      expect(reply, contains('Tradeoff:'));
      expect(reply, contains('No usable budget was available'));
      expect(
        client.lastRequest?.headers['authorization']?.startsWith('Bearer '),
        isTrue,
      );

      final request =
          jsonDecode((client.lastRequest! as http.Request).body)
              as Map<String, dynamic>;
      final messages = request['messages'] as List<dynamic>;
      final systemMessage = messages.first as Map<String, dynamic>;
      expect(systemMessage['role'], 'system');
      expect(
        systemMessage['content'],
        contains('do not infer missing details'),
      );
      expect(
        systemMessage['content'],
        contains('A stated free constraint is a budget, not a feature'),
      );
      expect(request['response_format'], {'type': 'json_object'});
    },
  );

  test(
    'a free-only budget is extracted and compared against the catalogue',
    () async {
      final client = _FakeClient(
        http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'projectType': 'small storefront',
                    'budget': {'amount': 0, 'currency': 'USD', 'hard': true},
                    'platforms': [],
                    'features': [],
                  }),
                },
              },
            ],
          }),
          200,
        ),
      );
      final service = GroqReplyService(apiKey: 'test-key', client: client);

      final reply = await service.generateReply('Only free tools, please.');

      expect(reply, contains('Budget: Estimated at USD 29/month'));
      expect(reply, contains('exceeds your hard cap of USD 0'));
      expect(reply, contains('fits within your hard cap of USD 0'));
      expect(reply, isNot(contains('is unverified')));
    },
  );

  test(
    'asks for clarification when extracted facts have no constraints',
    () async {
      final service = GroqReplyService(
        apiKey: 'test-key',
        client: _FakeClient(
          http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content':
                        '{"projectType":"chat app","platforms":[],"features":[]}',
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );

      final reply = await service.generateReply('I want to build a chat app.');
      expect(reply, contains('What constraint should I prioritize?'));
      expect(reply, isNot(contains('Here is a starter shortlist')));
    },
  );

  test('reports invalid extractor JSON rather than treating it as a reply', () {
    final service = GroqReplyService(
      apiKey: 'test-key',
      client: _FakeClient(
        http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'A chat app needs a backend.'},
              },
            ],
          }),
          200,
        ),
      ),
    );

    expect(
      service.generateReply('I want to build a chat app.'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('invalid project facts JSON'),
        ),
      ),
    );
  });

  test('fails clearly when the API key is missing', () async {
    final service = GroqReplyService(apiKey: '', client: _FakeClient());

    expect(service.generateReply('Hello'), throwsA(isA<StateError>()));
  });

  test('surfaces non-successful Groq responses', () async {
    final service = GroqReplyService(
      apiKey: 'test-key',
      client: _FakeClient(http.Response('quota exceeded', 429)),
    );

    expect(service.generateReply('Hello'), throwsA(isA<StateError>()));
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient([this.response]);

  final http.Response? response;
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    final result = response ?? http.Response('{}', 200);
    return http.StreamedResponse(
      Stream<List<int>>.value(result.bodyBytes),
      result.statusCode,
      headers: result.headers,
      request: request,
    );
  }
}
