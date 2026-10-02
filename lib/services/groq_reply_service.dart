import 'dart:convert';
import 'dart:io' as io;

import 'package:http/http.dart' as http;

import '../models/project_state.dart';
import 'shortlist_generator.dart';
import 'tool_price_catalogue.dart';

/// A minimal http.BaseClient backed directly by dart:io's HttpClient,
/// used instead of package:http's default IOClient.
///
/// The reason this exists: http.Client() on IO platforms resolves to
/// IOClient, whose send() has a catch block of the shape
/// `on SocketException catch (e) { throw ClientException(e.message, url); }`
/// — it silently rewraps genuine connectivity failures (SocketException)
/// AND reached-but-broken-response failures (HttpException) into the
/// same ClientException type, with no field to recover which one it
/// originally was. That collapsing makes it impossible for
/// ChatController.isNetworkUnreachable to correctly distinguish "the
/// phone never reached the service" from "the service was reached and
/// something else broke" — which is the exact distinction TFS-005
/// exists to get right.
///
/// This client deliberately does NOT catch or rewrap exceptions from
/// the underlying HttpClient — SocketException and HttpException
/// propagate to the caller exactly as dart:io throws them, so
/// isNetworkUnreachable can check `is SocketException` and have that
/// mean what it says.
class _UnwrappingIOClient extends http.BaseClient {
  final io.HttpClient _inner = io.HttpClient();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final ioRequest = await _inner.openUrl(request.method, request.url);
    request.headers.forEach((key, value) => ioRequest.headers.set(key, value));

    if (request is http.Request && request.bodyBytes.isNotEmpty) {
      ioRequest.contentLength = request.bodyBytes.length;
      ioRequest.add(request.bodyBytes);
    } else {
      ioRequest.contentLength = 0;
    }

    // Deliberately no try/catch here. A SocketException or HttpException
    // thrown by openUrl(...) or close() below propagates to the caller
    // untouched — that's the entire point of this class.
    final ioResponse = await ioRequest.close();

    final headers = <String, String>{};
    ioResponse.headers.forEach((name, values) {
      headers[name] = values.join(',');
    });

    return http.StreamedResponse(
      ioResponse,
      ioResponse.statusCode,
      contentLength:
          ioResponse.contentLength == -1 ? null : ioResponse.contentLength,
      headers: headers,
      reasonPhrase: ioResponse.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close(force: true);
    super.close();
  }
}

class GroqReplyService {
  GroqReplyService({
    required this.apiKey,
    this.model = 'openai/gpt-oss-120b',
    Uri? endpoint,
    http.Client? client,
  })  : _endpoint = endpoint ??
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        _client = client ?? _UnwrappingIOClient();

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
  final Uri _endpoint;
  final http.Client _client;

  Future<String> generateReply(String prompt) async {
    final result = await generateShortlistResult(prompt);
    return result.toReplyText();
  }

  Future<ShortlistResult> generateShortlistResult(String prompt) async {
    if (apiKey.isEmpty) {
      throw StateError(
        'GROQ_API_KEY is not configured. Run with '
        '--dart-define=GROQ_API_KEY=your-key.',
      );
    }

    final response = await _client.post(
      _endpoint,
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
                'currency string, hard boolean, and period "monthly", '
                '"total", or "unspecified", or null), platforms (array of '
                'strings), and features (array of strings). Use '
                'null for unstated projectType or budget and empty arrays '
                'for unstated platforms or features. If the user says tools '
                'must be free, or otherwise states a hard zero-cost '
                'requirement without a numeric figure, record budget as '
                'amount 0, currency "USD" unless another currency was stated, '
                'hard true, and period "unspecified". A stated free '
                'constraint is a budget, not a feature. Record period '
                '"monthly" or "total" only when explicitly stated; otherwise '
                'use "unspecified". Leave budget null only when no cost '
                'constraint was mentioned.',
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
    return generateShortlist(
      projectState,
      priceEstimates: kToolPriceCatalogue,
    );
  }
}
