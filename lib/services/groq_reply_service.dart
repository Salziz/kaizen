import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/project_state.dart';
import 'shortlist_generator.dart';

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
          {
            'role': 'system',
            'content':
                'Extract only facts the user explicitly stated about their '
                'project. Do not recommend tools and do not infer missing '
                'details. Return one JSON object with keys projectType '
                '(string or null), budget (object with numeric amount, '
                'currency string, and hard boolean, or null), platforms '
                '(array of strings), and features (array of strings). Use '
                'null for unstated projectType or budget and empty arrays '
                'for unstated platforms or features. If the user says only '
                'that tools must be free, record that phrase as a feature '
                'constraint; do not invent a currency or numeric budget.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = response.body.trim();
      throw StateError(
        'Groq request failed with HTTP ${response.statusCode}'
        '${detail.isEmpty ? '.' : ': $detail'}',
      );
    }

    final Object? decodedResponse;
    try {
      decodedResponse = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw StateError('Groq returned invalid response JSON: ${error.message}');
    }
    if (decodedResponse is! Map<String, dynamic>) {
      throw StateError('Groq returned a response that was not a JSON object.');
    }
    final choices = decodedResponse['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw StateError('Groq returned no valid completion choice.');
    }
    final message = choices.first['message'];
    if (message is! Map || message['content'] is! String) {
      throw StateError('Groq returned a completion without text content.');
    }
    final text = message['content'] as String;
    if (text.trim().isEmpty) {
      throw StateError('Groq returned no text content.');
    }

    final Object? envelope;
    try {
      envelope = jsonDecode(text);
    } on FormatException catch (error) {
      throw StateError(
        'Groq returned invalid project facts JSON: ${error.message}',
      );
    }
    if (envelope is! Map<String, dynamic>) {
      throw StateError(
        'Groq returned project facts that were not a JSON object.',
      );
    }

    final projectState = ProjectState.fromJson(envelope);
    return generateShortlist(projectState).toReplyText();
  }
}
