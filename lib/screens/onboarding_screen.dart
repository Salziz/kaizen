import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/chat_controller.dart';
import 'projects_screen.dart';

/// Models a tool showcase card on Screen 1 of onboarding.
class OnboardingToolCard {
  const OnboardingToolCard({
    required this.id,
    required this.name,
    required this.tier,
    required this.category,
    required this.price,
    required this.cadence,
    required this.accentColor,
    required this.gradientColors,
    required this.icon,
    required this.highlightFeatures,
  });

  final String id;
  final String name;
  final String tier;
  final String category;
  final String price;
  final String cadence;
  final Color accentColor;
  final List<Color> gradientColors;
  final IconData icon;
  final List<String> highlightFeatures;
}

const List<OnboardingToolCard> kHeroTools = [
  OnboardingToolCard(
    id: 'supabase',
    name: 'Supabase',
    tier: 'Pro',
    category: 'Backend & DB',
    price: '\$25',
    cadence: '/month',
    accentColor: Color(0xFF34D399),
    gradientColors: [Color(0xFF0F3B2C), Color(0xFF06241B)],
    icon: Icons.storage_rounded,
    highlightFeatures: [
      'Dedicated Postgres instance',
      'Row Level Security & Auth',
      'Realtime subscriptions',
      '100 GB file storage',
    ],
  ),
  OnboardingToolCard(
    id: 'vercel',
    name: 'Vercel',
    tier: 'Pro',
    category: 'Frontend & Edge',
    price: '\$20',
    cadence: '/month',
    accentColor: Color(0xFFE2E8F0),
    gradientColors: [Color(0xFF23252E), Color(0xFF14151B)],
    icon: Icons.change_history_rounded,
    highlightFeatures: [
      'Global Edge Network',
      'Fast preview deployments',
      'Serverless compute & ISR',
      '1 TB egress allowance',
    ],
  ),
  OnboardingToolCard(
    id: 'sentry',
    name: 'Sentry',
    tier: 'Team',
    category: 'Observability',
    price: '\$26',
    cadence: '/month',
    accentColor: Color(0xFFA78BFA),
    gradientColors: [Color(0xFF2E1B54), Color(0xFF170E2C)],
    icon: Icons.crisis_alert_rounded,
    highlightFeatures: [
      'Crash reporting & stack traces',
      'Distributed performance tracing',
      'Session replays & vitals',
      'Realtime anomaly alerts',
    ],
  ),
  OnboardingToolCard(
    id: 'trigger',
    name: 'Trigger.dev',
    tier: 'Pro',
    category: 'Background Jobs',
    price: '\$50',
    cadence: '/month',
    accentColor: Color(0xFFFB923C),
    gradientColors: [Color(0xFF3D1E0C), Color(0xFF1D0E06)],
    icon: Icons.bolt_rounded,
    highlightFeatures: [
      'Serverless background workers',
      'No-timeout long executions',
      'Durable steps & retries',
      'Real-time job observability',
    ],
  ),
];

const List<Map<String, String>> kProjectDomains = [
  {'id': 'saas', 'label': 'B2B SaaS', 'icon': '🚀'},
  {'id': 'mobile', 'label': 'Mobile App', 'icon': '📱'},
  {'id': 'ai', 'label': 'AI & LLM Agent', 'icon': '🤖'},
  {'id': 'ecommerce', 'label': 'E-Commerce', 'icon': '🛍️'},
  {'id': 'devtools', 'label': 'DevTools & Infra', 'icon': '⚡'},
  {'id': 'fintech', 'label': 'FinTech & Payments', 'icon': '💳'},
  {'id': 'marketplace', 'label': 'Marketplace', 'icon': '👥'},
  {'id': 'analytics', 'label': 'Data & Analytics', 'icon': '📊'},
];

const List<Map<String, String>> kProjectStages = [
  {
    'id': 'prototype',
    'title': 'Idea & Architecture',
    'subtitle': 'Evaluating tech stacks, architectural fit, and upfront costs.',
    'badge': 'Day 0',
  },
  {
    'id': 'mvp',
    'title': 'Building MVP',
    'subtitle': 'Actively coding. Need reliable, fast-to-ship production tools.',
    'badge': 'In Progress',
  },
  {
    'id': 'scale',
    'title': 'Scaling & Optimization',
    'subtitle': 'Live in production. Looking to replace bottlenecks & cut bills.',
    'badge': 'Production',
  },
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.controller,
    this.onCompleted,
  });

  final ChatController? controller;
  final VoidCallback? onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  int _currentPage = 0;
  final Set<String> _selectedDomains = {'saas', 'ai'};
  String _selectedStage = 'mvp';
  int _activeHeroCardIndex = 0;

  // Completion animation
  late final AnimationController _sparkleRotationController;
  late final AnimationController _pulseController;
  final List<Timer> _completionTimers = [];
  String _completionStatusText = 'Calibrating stack catalogue...';

  @override
  void initState() {
    super.initState();
    _sparkleRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      lowerBound: 0.95,
      upperBound: 1.05,
      value: 1.0,
    );
  }

  void _cancelTimers() {
    for (final timer in _completionTimers) {
      timer.cancel();
    }
    _completionTimers.clear();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sparkleRotationController.dispose();
    _pulseController.dispose();
    _cancelTimers();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    _cancelTimers();
    _sparkleRotationController.stop();
    _pulseController.stop();
    await _preferences.setBool('onboarding_completed', true);
    await _preferences.setStringList(
      'user_domains',
      _selectedDomains.toList(),
    );
    await _preferences.setString('user_stage', _selectedStage);

    if (!mounted) return;

    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ProjectsScreen(controller: widget.controller),
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < 4) {
      final target = _currentPage + 1;
      setState(() => _currentPage = target);
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          target,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
        );
      }
      if (target == 4) {
        _startCompletionSequence();
      }
    } else {
      _completeOnboarding();
    }
  }

  void _startCompletionSequence() {
    _cancelTimers();
    if (!_sparkleRotationController.isAnimating) {
      _sparkleRotationController.repeat();
    }
    if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }

    setState(() {
      _completionStatusText = 'Calibrating stack catalogue...';
    });

    _completionTimers.add(
      Timer(const Duration(milliseconds: 900), () {
        if (mounted && _currentPage == 4) {
          setState(() {
            _completionStatusText = 'Personalising your workspace...';
          });
        }
      }),
    );

    _completionTimers.add(
      Timer(const Duration(milliseconds: 1900), () {
        if (mounted && _currentPage == 4) {
          setState(() {
            _completionStatusText = 'Ready to build.';
          });
        }
      }),
    );

    _completionTimers.add(
      Timer(const Duration(milliseconds: 2700), () {
        if (mounted && _currentPage == 4) {
          _completeOnboarding();
        }
      }),
    );
  }

  void _skip() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF090A0F);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  _buildScreen1HeroStack(),
                  _buildScreen2Estimates(),
                  _buildScreen3DomainPicker(),
                  _buildScreen4StagePicker(),
                  _buildScreen5Completion(),
                ],
              ),
            ),
            if (_currentPage < 4) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Bar & Progress Stepper
  // ---------------------------------------------------------------------------
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo / Brand Mark
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.change_history_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'KAIZEN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                    ),
                  ),
                ],
              ),
              // Skip Button
              if (_currentPage < 4)
                TextButton(
                  key: const Key('onboarding_skip_button'),
                  onPressed: _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFA1A1AA),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Skip'),
                )
              else
                const SizedBox(height: 36),
            ],
          ),
          const SizedBox(height: 12),
          // Segmented Progress Indicator (4 segments for the 4 interactive steps)
          if (_currentPage < 4)
            Row(
              children: List.generate(4, (index) {
                final isFilled = index <= _currentPage;
                return Expanded(
                  child: Container(
                    height: 3.5,
                    margin: EdgeInsets.only(
                      right: index < 3 ? 6.0 : 0.0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isFilled
                          ? Colors.white
                          : const Color(0xFF27272A),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Screen 1: Hero Stack with Fanned Tool Cards (Supabase, Vercel, Sentry, Trigger)
  // ---------------------------------------------------------------------------
  Widget _buildScreen1HeroStack() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Editorial Headline
          Text.rich(
            key: const Key('onboarding_heading_screen_1'),
            textAlign: TextAlign.center,
            const TextSpan(
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
                letterSpacing: -0.6,
              ),
              children: [
                TextSpan(text: 'Architect your '),
                TextSpan(
                  text: 'Stack',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore production-grade tools, honest monthly costs, '
            'and trade-offs before typing Day 1 code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFA1A1AA),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          // Interactive Fanned Cards Deck
          _buildFannedDeck(),
          const SizedBox(height: 16),
          // Card selector dots/pills
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(kHeroTools.length, (index) {
              final isCurrent = index == _activeHeroCardIndex;
              final tool = kHeroTools[index];
              return GestureDetector(
                onTap: () {
                  setState(() => _activeHeroCardIndex = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isCurrent ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isCurrent ? tool.accentColor : const Color(0xFF3F3F46),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap any card to inspect pricing & specs',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF71717A).withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFannedDeck() {
    return SizedBox(
      height: 310,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 0; i < kHeroTools.length; i++)
              _buildFannedCardItem(i),
          ],
        ),
      ),
    );
  }

  Widget _buildFannedCardItem(int index) {
    final tool = kHeroTools[index];
    final isActive = index == _activeHeroCardIndex;

    // Symmetrical fanning relative to active card
    final int offsetFromActive = index - _activeHeroCardIndex;
    final double rotation = offsetFromActive * 0.08;
    final double translationX = offsetFromActive * 26.0;
    final double translationY = (offsetFromActive.abs() * 12.0) - (isActive ? 10.0 : 0.0);
    final double scale = isActive ? 1.0 : 0.91;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      top: 15 + translationY,
      left: 30 + translationX,
      right: 30 - translationX,
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: () {
              setState(() => _activeHeroCardIndex = index);
            },
            child: Container(
              height: 275,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: tool.gradientColors,
                ),
                border: Border.all(
                  color: isActive
                      ? tool.accentColor.withValues(alpha: 0.7)
                      : const Color(0xFF3F3F46).withValues(alpha: 0.5),
                  width: isActive ? 1.8 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isActive
                        ? tool.accentColor.withValues(alpha: 0.22)
                        : Colors.black.withValues(alpha: 0.5),
                    blurRadius: isActive ? 24 : 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Category Pill & Tier
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tool.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: tool.accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tool.tier,
                          style: TextStyle(
                            color: tool.accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Icon & Name
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(tool.icon, color: tool.accentColor, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tool.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        tool.price,
                        style: TextStyle(
                          color: tool.accentColor,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tool.cadence,
                        style: const TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Color(0x33FFFFFF), height: 1),
                  const SizedBox(height: 10),
                  // Feature list
                  ...tool.highlightFeatures.take(2).map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: tool.accentColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              feature,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD4D4D8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Screen 2: Cost Clarity & Live Estimates Hook
  // ---------------------------------------------------------------------------
  Widget _buildScreen2Estimates() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text.rich(
            key: const Key('onboarding_heading_screen_2'),
            textAlign: TextAlign.center,
            const TextSpan(
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
                letterSpacing: -0.6,
              ),
              children: [
                TextSpan(text: 'Honest '),
                TextSpan(
                  text: 'Estimates',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No guessed formulas or hidden surprise tiers. '
            'See verified catalogue figures before you swipe a card.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFA1A1AA),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          // Estimate Sample Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF14151B),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF27272A)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ladder header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ESTIMATED MONTHLY TOTAL',
                      style: TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_rounded, size: 12, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'Verified catalogue',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Big Total
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '\$71',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '/ month',
                      style: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'assumes around 10,000 requests a month (Growth rung)',
                  style: TextStyle(
                    color: Color(0xFF818CF8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF27272A), height: 1),
                const SizedBox(height: 14),
                // Stack items
                _buildEstimateLine('Supabase Pro', '\$25/mo', 'Backend & DB'),
                _buildEstimateLine('Vercel Pro', '\$20/mo', 'Frontend & Edge'),
                _buildEstimateLine('Sentry Team', '\$26/mo', 'Observability'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Quote badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_clock_rounded, size: 18, color: Color(0xFFA1A1AA)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Values the catalogue does not hold read as Unknown, never as an invented guess.',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateLine(String name, String price, String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· $category',
                style: const TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Text(
            price,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Screen 3: Interest / Domain Selection
  // ---------------------------------------------------------------------------
  Widget _buildScreen3DomainPicker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text.rich(
            key: const Key('onboarding_heading_screen_3'),
            textAlign: TextAlign.center,
            const TextSpan(
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
                letterSpacing: -0.6,
              ),
              children: [
                TextSpan(text: 'What are you '),
                TextSpan(
                  text: 'building',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                TextSpan(text: '?'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select your project domains. Kaizen tailors architectural '
            'shortlists and benchmarks around these constraints.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFA1A1AA),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          // Multi-select chip grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: kProjectDomains.map((domain) {
              final isSelected = _selectedDomains.contains(domain['id']);
              return GestureDetector(
                key: Key('domain_chip_${domain['id']}'),
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      if (_selectedDomains.length > 1) {
                        _selectedDomains.remove(domain['id']);
                      }
                    } else {
                      _selectedDomains.add(domain['id']!);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1E1B4B)
                        : const Color(0xFF14151B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF818CF8)
                          : const Color(0xFF27272A),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        domain['icon']!,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        domain['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFD4D4D8),
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Color(0xFF818CF8),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Screen 4: Stage & Scale Picker
  // ---------------------------------------------------------------------------
  Widget _buildScreen4StagePicker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text.rich(
            key: const Key('onboarding_heading_screen_4'),
            textAlign: TextAlign.center,
            const TextSpan(
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
                letterSpacing: -0.6,
              ),
              children: [
                TextSpan(text: 'What stage is your '),
                TextSpan(
                  text: 'project',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                TextSpan(text: '?'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We balance early development velocity against long-term '
            'maintenance and migration friction.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFA1A1AA),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          // Stage selector cards
          for (final stage in kProjectStages) ...[
            _buildStageCard(stage),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildStageCard(Map<String, String> stage) {
    final isSelected = _selectedStage == stage['id'];

    return GestureDetector(
      key: Key('stage_card_${stage['id']}'),
      onTap: () {
        setState(() => _selectedStage = stage['id']!);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1B4B) : const Color(0xFF14151B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF27272A),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radio-like indicator
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF818CF8)
                      : const Color(0xFF52525B),
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF818CF8) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stage['title']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          stage['badge']!,
                          style: const TextStyle(
                            color: Color(0xFFA1A1AA),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stage['subtitle']!,
                    style: const TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Screen 5: Celebration & Space Creation ("You have done your part :)")
  // ---------------------------------------------------------------------------
  Widget _buildScreen5Completion() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Satya-inspired headline
          Text.rich(
            key: const Key('onboarding_heading_screen_5'),
            textAlign: TextAlign.center,
            const TextSpan(
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.25,
                letterSpacing: -0.6,
              ),
              children: [
                TextSpan(text: 'You have done\n'),
                TextSpan(
                  text: 'your part :)',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFC7D2FE),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          // Animated Sparkling Emblem
          ScaleTransition(
            scale: _pulseController,
            child: SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating orbital gradient ring
                  RotationTransition(
                    turns: _sparkleRotationController,
                    child: CustomPaint(
                      size: const Size(160, 160),
                      painter: _OrbitalRingPainter(),
                    ),
                  ),
                  // Central glowing 4-point radiant diamond
                  CustomPaint(
                    size: const Size(64, 64),
                    painter: _SparkleStarPainter(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
          // Animated Status Subtitle
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _completionStatusText,
              key: ValueKey(_completionStatusText),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFA1A1AA),
                letterSpacing: 0.2,
              ),
            ),
          ),
          const Spacer(),
          // Direct CTA if user does not want to wait for auto-transition
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              key: const Key('onboarding_enter_workspace_button'),
              onPressed: _completeOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Enter Workspace',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Bar (Next / Continue Button)
  // ---------------------------------------------------------------------------
  Widget _buildBottomBar() {
    String buttonLabel = 'Next';
    if (_currentPage == 2) buttonLabel = 'Continue';
    if (_currentPage == 3) buttonLabel = 'Build My Space';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          key: const Key('onboarding_next_button'),
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(27),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Custom Painters for the Satya-style Completion Screen
// -----------------------------------------------------------------------------
class _OrbitalRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0x00818CF8),
          Color(0xFF6366F1),
          Color(0xFFA78BFA),
          Color(0xFFF472B6),
          Color(0x00F472B6),
        ],
        stops: [0.0, 0.35, 0.65, 0.85, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Draw an arc (270 degrees sweep)
    canvas.drawArc(rect, 0, math.pi * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SparkleStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final w = size.width;
    final h = size.height;

    // 4-pointed radiant sparkle star path
    final path = Path()
      ..moveTo(center.dx, 0)
      ..quadraticBezierTo(center.dx, center.dy, w, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, h)
      ..quadraticBezierTo(center.dx, center.dy, 0, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, 0)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          Color(0xFFE0E7FF),
          Color(0xFFA78BFA),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    // Subtle glow
    final glowPaint = Paint()
      ..color = const Color(0xFF818CF8).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
