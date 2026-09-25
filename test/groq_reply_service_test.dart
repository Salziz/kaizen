import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:kaizen/services/groq_reply_service.dart';

void main() {
  test('parses Groq text from a successful response', () async {
    final client = _FakeClient(
      http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'Hello from Groq'},
            },
          ],
        }),
        200,
      ),
    );
    final service = GroqReplyService(apiKey: 'test-key', client: client);

    expect(await service.generateReply('Hello'), 'Hello from Groq');
    expect(client.lastRequest?.headers['authorization'], 'Bearer test-key');
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
