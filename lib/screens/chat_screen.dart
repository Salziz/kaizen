import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/chat_controller.dart';
import '../models/chat_message.dart';
import '../models/project_item.dart';
import '../models/project_state.dart';
import '../services/conversation_store.dart';
import '../services/recommendation_gate.dart';
import '../services/shortlist_generator.dart';
import '../widgets/shortlist_estimate_widget.dart';
import '../widgets/groq_api_key_modal.dart';

const _characterLimit = 2000;
const _warningThreshold = 1800;

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.controller,
    this.project,
    this.projectTitle = 'New project',
  });

  final ChatController? controller;
  final ProjectItem? project;
  final String projectTitle;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, RestorationMixin {
  static const _backgroundedAtKey = 'backgrounded_at';

  late final ConversationStore _store;
  late final ChatController _controller;
  late final bool _ownsController;
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final RestorableDateTimeN _backgroundedAt = RestorableDateTimeN(null);
  final RestorableString _lastEvent = RestorableString('App launched');
  bool _resumeHandled = false;
  bool _showNewReplyPill = false;
  int _lastMessageCount = 0;
  bool _initialized = false;
  bool _isSending = false;
  bool _hasGroqKey = false;

  @override
  String get restorationId => 'chat_screen';

  @override
  void initState() {
    super.initState();
    _store = ConversationStore();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ChatController(_store);
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restorePersistedBackgroundTime());
    unawaited(_initialize());
    unawaited(_checkGroqKeyStatus());
  }

  Future<void> _checkGroqKeyStatus() async {
    final key = await _preferences.getString('groq_api_key');
    if (mounted) {
      setState(() {
        _hasGroqKey = key != null && key.trim().isNotEmpty;
      });
    }
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
    if (_controller.messages.isEmpty && widget.project != null) {
      _seedProjectConversation(widget.project!);
    }
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

  void _seedProjectConversation(ProjectItem project) {
    final (String userPrompt, ShortlistResult shortlist) = switch (project.title) {
      'Pulse AI' => (
        'Building an autonomous research agent for finance analysts. It needs Python/Dart execution, long-term memory with pgvector, error monitoring, and workflow scheduling. Hard budget of \$100/mo.',
        const ShortlistResult(
          gate: GateResult(verdict: GateVerdict.enough),
          budgetAcknowledgment:
              'Based on your hard budget of USD 100/mo, here is a tailored architecture stack:',
          budget: Budget(
            amount: 100,
            currency: 'USD',
            hard: true,
            period: BudgetPeriod.monthly,
          ),
          recommendations: [
            ToolRecommendation(
              name: 'Supabase',
              category: 'Database & Vector',
              rationale:
                  'Postgres with pgvector extension for long-term agent memory and retrieval.',
              tradeoff:
                  'Requires SQL knowledge and index tuning.',
              budgetAssessment:
                  'Fits within your hard cap of USD 100 (Starter free, Pro \$25/mo).',
            ),
            ToolRecommendation(
              name: 'Sentry',
              category: 'Monitoring',
              rationale:
                  'Captures runtime exceptions and execution traces in agent jobs.',
              tradeoff:
                  'Event quota limits on high-frequency loops.',
              budgetAssessment:
                  'Fits within your hard cap (Developer free tier, Team \$26/mo).',
            ),
            ToolRecommendation(
              name: 'Trigger.dev',
              category: 'Background Jobs',
              rationale:
                  'Serverless background jobs with long timeouts for financial report generation.',
              tradeoff:
                  'Higher rung costs at scale.',
              budgetAssessment:
                  'Fits within your hard cap (Free hobby tier, Pro \$50/mo).',
            ),
          ],
        ),
      ),
      'Kite Mobile' => (
        'Building a cross-platform Flutter app for real-time team messaging on iOS and Android. Hard budget of \$50/month.',
        const ShortlistResult(
          gate: GateResult(verdict: GateVerdict.enough),
          budgetAcknowledgment:
              'Based on your hard budget of USD 50/mo, here is a tailored starter shortlist:',
          budget: Budget(
            amount: 50,
            currency: 'USD',
            hard: true,
            period: BudgetPeriod.monthly,
          ),
          recommendations: [
            ToolRecommendation(
              name: 'Supabase',
              category: 'Backend & Sync',
              rationale:
                  'Managed Postgres, instant real-time websockets, and built-in auth.',
              tradeoff:
                  'Connection pooling limits on lower tiers.',
              budgetAssessment:
                  'Fits within your hard cap of USD 50 (Pro \$25/mo).',
            ),
            ToolRecommendation(
              name: 'Sentry',
              category: 'Crash Reporting',
              rationale:
                  'Real-time crash reporting and ANR tracking across iOS and Android.',
              tradeoff:
                  'Sampling configuration needed for high traffic.',
              budgetAssessment:
                  'Fits within your hard cap (Developer free tier, Team \$26/mo).',
            ),
          ],
        ),
      ),
      'Nova Storefront' => (
        'Building a high-conversion mobile storefront with checkout and product catalog. Hard budget of \$150/mo.',
        const ShortlistResult(
          gate: GateResult(verdict: GateVerdict.enough),
          budgetAcknowledgment:
              'Based on your hard budget of USD 150/mo, here is a tailored starter shortlist:',
          budget: Budget(
            amount: 150,
            currency: 'USD',
            hard: true,
            period: BudgetPeriod.monthly,
          ),
          recommendations: [
            ToolRecommendation(
              name: 'Shopify',
              category: 'Ecommerce Platform',
              rationale:
                  'Hosted storefront engine with headless Storefront API for Flutter.',
              tradeoff:
                  'Monthly platform subscription.',
              budgetAssessment:
                  'Fits within your hard cap (Basic plan \$29/mo).',
            ),
            ToolRecommendation(
              name: 'Stripe',
              category: 'Payments',
              rationale:
                  'Apple Pay, Google Pay, and international card checkout processing.',
              tradeoff:
                  'Transaction percentage and flat fees.',
              budgetAssessment:
                  'Transaction-based fees. Base fee is \$0.30/txn + 2.9%.',
            ),
            ToolRecommendation(
              name: 'Sentry',
              category: 'Performance',
              rationale:
                  'Monitors checkout latency and mobile cart abandonment errors.',
              tradeoff:
                  'Transaction tracing quota.',
              budgetAssessment:
                  'Fits within your hard cap (Free tier or Team \$26/mo).',
            ),
          ],
        ),
      ),
      _ => (
        'Evaluating architecture and stack for ${project.title} (${project.domain}).',
        ShortlistResult(
          gate: const GateResult(verdict: GateVerdict.enough),
          budgetAcknowledgment:
              'Starter recommendations based on your selected tools:',
          recommendations: project.tools.map((toolName) {
            return ToolRecommendation(
              name: toolName,
              category: 'Infrastructure',
              rationale: 'Primary component selected for ${project.title}.',
              tradeoff: 'Consider operational requirements as user volume grows.',
              budgetAssessment: 'Evaluating pricing against usage rungs.',
            );
          }).toList(),
        ),
      ),
    };

    final userMsg = ChatMessage(
      id: 'seed-user-${project.id}',
      text: userPrompt,
      sender: MessageSender.user,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      status: MessageStatus.sent,
    );

    final assistantMsg = ChatMessage(
      id: 'seed-assistant-${project.id}',
      text: shortlist.toReplyText(),
      sender: MessageSender.assistant,
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
      status: MessageStatus.sent,
      shortlist: shortlist,
    );

    _controller.messages.addAll([userMsg, assistantMsg]);
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

  Future<void> _send() async {
    if (_isSending) {
      return;
    }
    final text = _textController.text;
    if (text.trim().isEmpty || text.characters.length > _characterLimit) {
      return;
    }

    setState(() => _isSending = true);
    try {
      await _controller.sendMessage(text);
      if (!mounted) {
        return;
      }
      _textController.clear();
      await _store.saveDraft('');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _retryLatest() {
    final userMessages = _controller.messages.where(
      (item) =>
          item.sender == MessageSender.user &&
          (item.status == MessageStatus.pending ||
              item.status == MessageStatus.sent ||
              item.status == MessageStatus.failed),
    );
    if (userMessages.isEmpty) {
      return;
    }
    unawaited(_controller.retry(userMessages.last.id));
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
    if (_ownsController) {
      _controller.dispose();
    }
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
        backgroundColor: const Color(0xFF0A0A0C),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0A0C),
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFFA1A1AA)),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFF27272A)),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.project?.title ?? widget.projectTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Last reply: ${_controller.lastRoundTripMs == null ? '—' : '${(_controller.lastRoundTripMs! / 1000).toStringAsFixed(1)}s'}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFA1A1AA)),
              ),
            ],
          ),
          actions: [
            Tooltip(
              message: _hasGroqKey
                  ? 'Groq Live Mode (Active)'
                  : 'Configure Groq API Key',
              child: IconButton(
                key: const Key('chat_api_key_button'),
                icon: Icon(
                  _hasGroqKey ? Icons.bolt_rounded : Icons.key_outlined,
                  color: _hasGroqKey
                      ? const Color(0xFF10B981)
                      : const Color(0xFFA1A1AA),
                ),
                onPressed: () async {
                  await showGroqApiKeyModal(context,
                      onKeyChanged: _checkGroqKeyStatus);
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
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
          (_controller.replyState == ReplyState.waiting ||
                  _controller.replyState == ReplyState.overdue
              ? 1
              : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return _ReplyDots(
            overdue: _controller.replyState == ReplyState.overdue,
          );
        }
        final message = messages[index];
        if (message.sender == MessageSender.user) {
          return _UserBubble(
            message: message,
            showSending:
                message.status == MessageStatus.pending &&
                _controller.replyState != ReplyState.noAnswer,
            showNoAnswer:
                message.status == MessageStatus.sent &&
                _controller.replyState == ReplyState.noAnswer,
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
    final characterCount = text.characters.length;
    final over = characterCount > _characterLimit;
    final waiting =
        _controller.replyState == ReplyState.waiting ||
        _controller.replyState == ReplyState.overdue;
    final canSend = text.trim().isNotEmpty && !over && !waiting && !_isSending;
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
                    color: const Color(0xFF14151B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: over ? Colors.red : const Color(0xFF27272A),
                    ),
                  ),
                  child: Scrollbar(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 5,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Describe the app you want to build',
                        hintStyle: TextStyle(color: Color(0xFF52525B)),
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
              _SendButton(enabled: canSend, onTap: () => unawaited(_send())),
            ],
          ),
          if (characterCount >= _warningThreshold)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Text(
                over
                    ? '$characterCount / $_characterLimit   ${characterCount - _characterLimit} over'
                    : '$characterCount / $_characterLimit',
                style: TextStyle(
                  fontSize: 11.5,
                  color: over ? Colors.red : const Color(0xFFFBBF24),
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
            if (lifecycleMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  lifecycleMessage!,
                  style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                ),
              ),
            const Text(
              'Describe the app you want to build.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: Color(0xFFE4E4E7),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Three or four sentences is plenty to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF71717A), fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.message,
    required this.showSending,
    required this.showNoAnswer,
    this.onRetry,
  });

  final ChatMessage message;
  final bool showSending;
  final bool showNoAnswer;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = message.status == MessageStatus.failed;
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
                      ? const Color(0xFF2D1515)
                      : const Color(0xFF0F6B5C),
                  border: failed
                      ? Border.all(color: Colors.red.shade700)
                      : Border.all(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.3)),
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
                    color: failed ? const Color(0xFFFCA5A5) : Colors.white,
                    fontSize: 14.5,
                  ),
                ),
              ),
              if (showSending)
                const Text(
                  'Sending',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFFA1A1AA)),
                ),
              if (showNoAnswer)
                const Text(
                  'No response',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFFA1A1AA)),
                ),
              if (failed)
                Text(
                  'Not sent. Tap to send again.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.red.shade400,
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
    if (message.shortlist != null && message.shortlist!.canRecommend) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF14151B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: ShortlistEstimateWidget(shortlist: message.shortlist!),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14151B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Text(
        message.text,
        style: const TextStyle(fontSize: 14.5, color: Color(0xFFE4E4E7)),
      ),
    );
  }
}

class _ReplyDots extends StatelessWidget {
  const _ReplyDots({required this.overdue});

  final bool overdue;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•••',
                style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 16)),
            if (overdue)
              const Text(
                'Still working on it...',
                style: TextStyle(fontSize: 11.5, color: Color(0xFFA1A1AA)),
              ),
          ],
        ),
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
              ? const Color(0xFF10B981)
              : const Color(0xFF27272A),
        ),
        child: Icon(
          Icons.arrow_upward,
          color: enabled ? Colors.black : const Color(0xFF52525B),
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
          color: const Color(0xFF2D1515),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade800),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12.5),
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
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '1 new reply',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
