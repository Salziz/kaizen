import 'dart:convert';

import 'package:http/http.dart' as http;

class GroqReplyService {
  GroqReplyService({
    required this.apiKey,
    this.model = 'openai/gpt-oss-120b',
    http.Client? client,
  }) : _client = client ?? http.Client();

  factory GroqReplyService.fromEnvironment({http.Client? client}) {
    return GroqReplyService(
      apiKey: const String.fromEnvironment('GROQ_API_KEY'),
      model: const String.fromEnvironment(
        'GROQ_MODEL',
        defaultValue: 'openai/gpt-oss-120b',
      ),
      client: client,
    );
  }

  final String apiKey;
  final String model;
  final http.Client _client;

  Future<String> generateReply(String prompt) async {
    if (apiKey.isEmpty) {
      throw StateError(
        'GROQ_API_KEY is not configured. Run with '
        '--dart-define=GROQ_API_KEY=your-key.',
      );
    }

    final response = await _client.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = response.body.trim();
      throw StateError(
        'Groq request failed with HTTP ${response.statusCode}'
        '${detail.isEmpty ? '.' : ': $detail'}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    final firstChoice = choices == null || choices.isEmpty
        ? null
        : choices.first as Map<String, dynamic>;
    final message = firstChoice?['message'] as Map<String, dynamic>?;
    final text = message?['content'] as String?;

    if (text == null || text.isEmpty) {
      throw StateError('Groq returned no text content.');
    }
    return text;
  }
}
