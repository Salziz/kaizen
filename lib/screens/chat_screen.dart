import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/chat_controller.dart';
import '../models/chat_message.dart';
import '../services/conversation_store.dart';

const _characterLimit = 2000;
const _warningThreshold = 1800;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, RestorationMixin {
  static const _backgroundedAtKey = 'backgrounded_at';

  late final ConversationStore _store;
  late final ChatController _controller;
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final RestorableDateTimeN _backgroundedAt = RestorableDateTimeN(null);
  final RestorableString _lastEvent = RestorableString('App launched');
  bool _resumeHandled = false;
  bool _showNewReplyPill = false;
  int _lastMessageCount = 0;
  bool _initialized = false;

  @override
  String get restorationId => 'chat_screen';

  @override
  void initState() {
    super.initState();
    _store = ConversationStore();
    _controller = ChatController(_store);
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restorePersistedBackgroundTime());
    unawaited(_initialize());
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_backgroundedAt, 'backgrounded_at');
    registerForRestoration(_lastEvent, 'last_event');
    if (initialRestore && _backgroundedAt.value != null) {
      _recordResumeFromBackground();
    }
  }

  Future<void> _initialize() async {
    await _controller.loadInitialState();
    final draft = await _store.loadDraft();
    if (!mounted) {
      return;
    }
    _textController.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
    setState(() => _initialized = true);
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    final grew = _controller.messages.length > _lastMessageCount;
    _lastMessageCount = _controller.messages.length;
    if (grew) {
      if (_isAtBottom()) {
        _scrollToBottom();
      } else {
        _showNewReplyPill = true;
      }
    }
    setState(() {});
  }

  bool _isAtBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    return _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 40;
  }

  void _scrollToBottom() {
    _showNewReplyPill = false;
    if (!_scrollController.hasClients) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _textController.text;
    if (text.trim().isEmpty || text.length > _characterLimit) {
      return;
    }

    _textController.clear();
    unawaited(_store.saveDraft(''));
    unawaited(_controller.sendMessage(text));
  }

  void _retryLatest() {
    final message = _controller.messages.lastWhere(
      (item) =>
          item.sender == MessageSender.user &&
          (item.status == MessageStatus.pending ||
              item.status == MessageStatus.sent ||
              item.status == MessageStatus.failed),
    );
    unawaited(_controller.retry(message.id));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        _saveBackgroundTime();
        break;
      case AppLifecycleState.resumed:
        if (_backgroundedAt.value != null) {
          setState(_recordResumeFromBackground);
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _saveBackgroundTime() {
    _resumeHandled = false;
    _backgroundedAt.value ??= DateTime.now();
    final backgroundedAt = _backgroundedAt.value;
    unawaited(
      _store.saveDraft(_textController.text).then((_) async {
        if (backgroundedAt != null) {
          await _preferences.setString(
            _backgroundedAtKey,
            backgroundedAt.toIso8601String(),
          );
        }
      }),
    );
  }

  void _recordResumeFromBackground() {
    if (_resumeHandled || _backgroundedAt.value == null) {
      return;
    }
    _resumeHandled = true;
    final elapsed = DateTime.now().difference(_backgroundedAt.value!);
    _lastEvent.value = 'Resumed after ${elapsed.inSeconds}s backgrounded';
    _backgroundedAt.value = null;
    unawaited(_preferences.remove(_backgroundedAtKey));
  }

  Future<void> _restorePersistedBackgroundTime() async {
    final savedValue = await _preferences.getString(_backgroundedAtKey);
    final backgroundedAt = savedValue == null
        ? null
        : DateTime.tryParse(savedValue);
    if (!mounted ||
        _resumeHandled ||
        backgroundedAt == null ||
        _backgroundedAt.value != null) {
      return;
    }
    setState(() {
      _backgroundedAt.value = backgroundedAt;
      _recordResumeFromBackground();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _backgroundedAt.dispose();
    _lastEvent.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3EE),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F3EE),
          elevation: 0,
          title: const Text('New project'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _buildThread(),
                    if (_showNewReplyPill)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _NewReplyPill(onTap: _scrollToBottom),
                        ),
                      ),
                  ],
                ),
              ),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThread() {
    final messages = _controller.messages;
    if (!_initialized && messages.isEmpty) {
      return const _EmptyState();
    }
    if (messages.isEmpty) {
      return _EmptyState(lifecycleMessage: _lastEvent.value);
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      itemCount:
          messages.length +
          (_controller.replyState == ReplyState.waiting ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return const _ReplyDots();
        }
        final message = messages[index];
        if (message.sender == MessageSender.user) {
          return _UserBubble(
            message: message,
            onRetry: message.status == MessageStatus.failed
                ? () => unawaited(_controller.retry(message.id))
                : null,
          );
        }
        return _AssistantBlock(message: message);
      },
    );
  }

  Widget _buildComposer() {
    final text = _textController.text;
    final over = text.length > _characterLimit;
    final waiting = _controller.replyState == ReplyState.waiting;
    final canSend = text.trim().isNotEmpty && !over && !waiting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_controller.replyState == ReplyState.noAnswer ||
              _controller.errorMessage != null)
            _RetryBanner(
              label:
                  _controller.errorMessage ??
                  "Kaizen didn't answer. Tap to try again.",
              onTap: _retryLatest,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: over ? Colors.red : const Color(0xFFDFE3E9),
                    ),
                  ),
                  child: Scrollbar(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Describe the app you want to build',
                        isDense: true,
                      ),
                      onChanged: (value) {
                        unawaited(_store.saveDraft(value));
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(enabled: canSend, onTap: _send),
            ],
          ),
          if (text.length >= _warningThreshold)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Text(
                over
                    ? '${text.length} / $_characterLimit   ${text.length - _characterLimit} over'
                    : '${text.length} / $_characterLimit',
                style: TextStyle(
                  fontSize: 11.5,
                  color: over ? Colors.red : const Color(0xFF8A5A00),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.lifecycleMessage});

  final String? lifecycleMessage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lifecycleMessage != null) Text(lifecycleMessage!),
            const Text(
              'Describe the app you want to build.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Three or four sentences is plenty to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = message.status == MessageStatus.failed;
    final pending = message.status == MessageStatus.pending;
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: failed ? onRetry : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .82,
                ),
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: failed
                      ? const Color(0xFFFDECEB)
                      : const Color(0xFF0F6B5C),
                  border: failed ? Border.all(color: Colors.red) : null,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: failed ? Colors.red : Colors.white,
                    fontSize: 14.5,
                  ),
                ),
              ),
              if (pending)
                const Text(
                  'Sending',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              if (failed)
                const Text(
                  'Not sent. Tap to send again.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantBlock extends StatelessWidget {
  const _AssistantBlock({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      color: const Color(0xFFF3F5F8),
      child: Text(message.text, style: const TextStyle(fontSize: 14.5)),
    );
  }
}

class _ReplyDots extends StatelessWidget {
  const _ReplyDots();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('•••', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          backgroundColor: enabled
              ? const Color(0xFF0F6B5C)
              : const Color(0xFFF3F5F8),
        ),
        child: Icon(
          Icons.arrow_upward,
          color: enabled ? Colors.white : Colors.grey,
          size: 20,
        ),
      ),
    );
  }
}

class _RetryBanner extends StatelessWidget {
  const _RetryBanner({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.red, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _NewReplyPill extends StatelessWidget {
  const _NewReplyPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F6B5C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '1 new reply',
          style: TextStyle(color: Colors.white, fontSize: 12.5),
        ),
      ),
    );
  }
}
