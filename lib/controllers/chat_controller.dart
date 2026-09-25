import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../services/conversation_store.dart';
import '../services/groq_reply_service.dart';

enum ReplyState { idle, waiting, overdue, received, noAnswer }

typedef ReplySender = Future<String> Function(String text);

class ChatController extends ChangeNotifier {
  ChatController(
    this._store, {
    ReplySender? replySender,
    this._timeoutDuration = const Duration(seconds: 30),
  }) : _replySender =
           replySender ?? GroqReplyService.fromEnvironment().generateReply;

  final ConversationStore _store;
  final ReplySender _replySender;
  final Duration _timeoutDuration;
  final Uuid _uuid = Uuid();

  final List<ChatMessage> messages = [];
  final Set<String> _inFlightIds = {};
  final Set<String> _retryingIds = {};
  Timer? _timeoutTimer;
  String? _waitingForMessageId;
  int _exchangeToken = 0;
  int? _activeExchangeToken;
  ReplyState? replyState;
  String? errorMessage;
  int? lastRoundTripMs;

  Future<void> loadInitialState() async {
    messages
      ..clear()
      ..addAll(await _store.loadThread());
    lastRoundTripMs = (await _store.loadLastRoundTrip())?.milliseconds;

    var changed = false;
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].status == MessageStatus.pending) {
        messages[i] = messages[i].copyWith(status: MessageStatus.failed);
        changed = true;
      }
    }

    if (changed) {
      await _store.saveThread(messages);
    }

    final lastSentIndex = messages.lastIndexWhere(
      (message) =>
          message.sender == MessageSender.user &&
          message.status == MessageStatus.sent,
    );
    _waitingForMessageId = null;
    _activeExchangeToken = null;
    replyState = ReplyState.idle;
    if (lastSentIndex != -1 &&
        !messages
            .skip(lastSentIndex + 1)
            .any((message) => message.sender == MessageSender.assistant)) {
      _waitingForMessageId = messages[lastSentIndex].id;
      replyState = ReplyState.noAnswer;
    }
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final message = ChatMessage(
      id: _generateId(),
      text: trimmed,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
    );
    messages.add(message);
    await _store.upsertMessage(message);
    await _store.clearDraft();
    notifyListeners();

    unawaited(_dispatch(message));
  }

  Future<void> retry(String messageId) async {
    if (_inFlightIds.contains(messageId)) {
      return;
    }

    final index = messages.indexWhere((message) => message.id == messageId);
    if (index == -1) {
      return;
    }
    if (!_retryingIds.add(messageId)) {
      return;
    }

    final resent = messages[index].copyWith(status: MessageStatus.pending);
    messages[index] = resent;
    try {
      await _store.upsertMessage(resent);
    } finally {
      _retryingIds.remove(messageId);
    }
    notifyListeners();

    await _dispatch(resent);
  }

  Future<void> _dispatch(ChatMessage message) async {
    if (_inFlightIds.contains(message.id)) {
      return;
    }

    _inFlightIds.add(message.id);
    _waitingForMessageId = message.id;
    final exchangeToken = ++_exchangeToken;
    _activeExchangeToken = exchangeToken;
    replyState = ReplyState.waiting;
    errorMessage = null;
    notifyListeners();

    final index = messages.indexWhere((item) => item.id == message.id);
    if (index != -1 && messages[index].status != MessageStatus.sent) {
      final sent = messages[index].copyWith(status: MessageStatus.sent);
      messages[index] = sent;
      await _store.upsertMessage(sent);
      notifyListeners();
    }

    _timeoutTimer?.cancel();
    Timer? budgetTimer;
    budgetTimer = Timer(const Duration(seconds: 10), () {
      if (_activeExchangeToken == exchangeToken &&
          replyState == ReplyState.waiting) {
        replyState = ReplyState.overdue;
        notifyListeners();
      }
    });
    _timeoutTimer = Timer(_timeoutDuration, () {
      if (_activeExchangeToken == exchangeToken &&
          _waitingForMessageId == message.id &&
          (replyState == ReplyState.waiting ||
              replyState == ReplyState.overdue)) {
        replyState = ReplyState.noAnswer;
        _inFlightIds.remove(message.id);
        budgetTimer?.cancel();
        notifyListeners();
      }
    });

    try {
      final stopwatch = Stopwatch()..start();
      final replyText = await _replySender(message.text);
      stopwatch.stop();
      budgetTimer.cancel();
      lastRoundTripMs = stopwatch.elapsedMilliseconds;
      notifyListeners();
      unawaited(
        _store
            .recordRoundTrip(stopwatch.elapsedMilliseconds)
            .catchError((_) {}),
      );

      if (replyText.isNotEmpty) {
        await _receiveReply(message.id, exchangeToken, replyText);
      }
    } catch (error) {
      budgetTimer.cancel();
      if (exchangeToken != _activeExchangeToken) {
        return;
      }

      final index = messages.indexWhere(
        (existing) => existing.id == message.id,
      );
      if (index != -1) {
        final failed = messages[index].copyWith(status: MessageStatus.failed);
        messages[index] = failed;
        await _store.upsertMessage(failed);
      }

      _inFlightIds.remove(message.id);
      _timeoutTimer?.cancel();
      if (_waitingForMessageId == message.id) {
        replyState = ReplyState.idle;
      }

      errorMessage = error.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
    }
  }

  Future<void> _receiveReply(
    String forMessageId,
    int exchangeToken,
    String replyText,
  ) async {
    if (exchangeToken != _activeExchangeToken) {
      return;
    }

    final index = messages.indexWhere((message) => message.id == forMessageId);
    if (index != -1) {
      final reply = ChatMessage(
        id: _generateId(),
        text: replyText,
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );
      messages.add(reply);
      await _store.upsertMessage(reply);
    }

    _timeoutTimer?.cancel();
    replyState = ReplyState.received;
    _waitingForMessageId = null;
    _activeExchangeToken = null;
    _inFlightIds.remove(forMessageId);
    notifyListeners();
  }

  String _generateId() => _uuid.v4();

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }
}
