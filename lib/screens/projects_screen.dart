import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../controllers/chat_controller.dart';
import '../models/project_item.dart';
import 'chat_screen.dart';
import 'onboarding_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    this.controller,
  });

  final ChatController? controller;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  List<ProjectItem> _projects = [];
  String _selectedFilter = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProjects());
  }

  Future<void> _loadProjects() async {
    final raw = await _preferences.getString('saved_projects');
    if (raw != null && raw.isNotEmpty) {
      try {
        final loaded = ProjectItem.decodeList(raw);
        if (mounted) {
          setState(() {
            _projects = loaded;
            _isLoading = false;
          });
          return;
        }
      } catch (_) {
        // Fall back to sample projects
      }
    }

    final samples = ProjectItem.sampleProjects();
    await _preferences.setString('saved_projects', ProjectItem.encodeList(samples));
    if (mounted) {
      setState(() {
        _projects = samples;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProjects() async {
    await _preferences.setString('saved_projects', ProjectItem.encodeList(_projects));
  }

  void _openProject(ProjectItem project) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(controller: widget.controller),
      ),
    );
  }

  void _showNewProjectModal() {
    final titleController = TextEditingController();
    String selectedDomain = 'AI & LLM Agent';
    String selectedStage = 'Building MVP';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14151B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New Project',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalContext),
                        icon: const Icon(Icons.close, color: Color(0xFFA1A1AA)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PROJECT NAME',
                    style: TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('new_project_title_input'),
                    controller: titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'e.g. Apex Studio, Pulse Agent',
                      hintStyle: const TextStyle(color: Color(0xFF52525B)),
                      filled: true,
                      fillColor: const Color(0xFF1C1D24),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF27272A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF818CF8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'DOMAIN',
                    style: TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'AI & LLM Agent',
                      'Mobile App',
                      'B2B SaaS',
                      'E-Commerce',
                      'DevTools',
                    ].map((d) {
                      final isSelected = selectedDomain == d;
                      return ChoiceChip(
                        label: Text(d),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedDomain = d);
                        },
                        selectedColor: const Color(0xFF6366F1),
                        backgroundColor: const Color(0xFF1C1D24),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF27272A),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      key: const Key('confirm_create_project_button'),
                      onPressed: () {
                        final title = titleController.text.trim().isEmpty
                            ? 'Untitled Project'
                            : titleController.text.trim();
                        final newProj = ProjectItem(
                          id: 'proj-${const Uuid().v4().substring(0, 8)}',
                          title: title,
                          description: 'Architecting stack for $selectedDomain.',
                          domain: selectedDomain,
                          stage: selectedStage,
                          tools: ['Evaluating tools...'],
                          estimatedMonthlyCost: '\$0',
                          updatedAt: DateTime.now(),
                          status: 'Evaluating Stack',
                        );
                        setState(() {
                          _projects.insert(0, newProj);
                        });
                        unawaited(_saveProjects());
                        Navigator.pop(modalContext);
                        _openProject(newProj);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Launch Architecture Chat',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _replayOnboarding() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingScreen(
          controller: widget.controller,
          onCompleted: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF090A0F);

    final filteredProjects = _selectedFilter == 'All'
        ? _projects
        : _projects
            .where((p) =>
                p.domain.toLowerCase().contains(_selectedFilter.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF818CF8)),
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(),
                          const SizedBox(height: 20),
                          _buildHeroHeader(),
                          const SizedBox(height: 18),
                          _buildStatsRow(),
                          const SizedBox(height: 20),
                          _buildNewProjectHeroCard(),
                          const SizedBox(height: 22),
                          _buildFilterTabs(),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                  if (filteredProjects.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'No projects in this category.',
                            style: TextStyle(color: Color(0xFF71717A), fontSize: 14),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final project = filteredProjects[index];
                            return _buildProjectCard(project);
                          },
                          childCount: filteredProjects.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top App Bar
  // ---------------------------------------------------------------------------
  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
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
            const SizedBox(width: 10),
            const Text(
              'KAIZEN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
          ],
        ),
        // Replay onboarding trigger (useful for demo day presentation)
        TextButton.icon(
          key: const Key('replay_onboarding_button'),
          onPressed: _replayOnboarding,
          icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFA1A1AA)),
          label: const Text(
            'Intro Demo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFA1A1AA),
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            backgroundColor: const Color(0xFF14151B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF27272A)),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Hero Title
  // ---------------------------------------------------------------------------
  Widget _buildHeroHeader() {
    return Text.rich(
      key: const Key('projects_heading'),
      const TextSpan(
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        children: [
          TextSpan(text: 'Active '),
          TextSpan(
            text: 'Projects',
            style: TextStyle(
              fontFamily: 'serif',
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              color: Color(0xFFE2E8F0),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats Row
  // ---------------------------------------------------------------------------
  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14151B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: _buildStatItem('WORKSPACES', '${_projects.length}', const Color(0xFF818CF8))),
          Container(height: 24, width: 1, color: const Color(0xFF27272A)),
          Expanded(child: _buildStatItem('EST. BURN', '~\$195/mo', Colors.white)),
          Container(height: 24, width: 1, color: const Color(0xFF27272A)),
          Expanded(child: _buildStatItem('CATALOGUE', 'Verified', const Color(0xFF10B981))),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF71717A),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Hero "+ New Project" Card
  // ---------------------------------------------------------------------------
  Widget _buildNewProjectHeroCard() {
    return GestureDetector(
      key: const Key('create_new_project_card'),
      onTap: _showNewProjectModal,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF181822),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.6),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start New Architecture',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Scope tools, calculate upfront burn & trade-offs',
                    style: TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFA1A1AA),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter Tabs
  // ---------------------------------------------------------------------------
  Widget _buildFilterTabs() {
    final filters = ['All', 'AI', 'Mobile', 'E-Commerce', 'B2B SaaS'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              key: Key('filter_tab_$f'),
              onTap: () => setState(() => _selectedFilter = f),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFF14151B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.white : const Color(0xFF27272A),
                  ),
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    color: isSelected ? Colors.black : const Color(0xFFA1A1AA),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Project Card
  // ---------------------------------------------------------------------------
  Widget _buildProjectCard(ProjectItem project) {
    Color statusColor = const Color(0xFF818CF8);
    if (project.status == 'Architecture Ready') statusColor = const Color(0xFF10B981);
    if (project.status == 'In Production') statusColor = const Color(0xFF38BDF8);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF14151B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openProject(project),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: domain & status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        project.domain.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            project.status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Title
                Text(
                  project.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                // Description
                Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                // Tools stack pills
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: project.tools.map((tool) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2029),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF2E303E)),
                      ),
                      child: Text(
                        tool,
                        style: const TextStyle(
                          color: Color(0xFFD4D4D8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Divider(color: Color(0xFF27272A), height: 1),
                const SizedBox(height: 12),
                // Bottom row: cost & relative time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Est. burn: ',
                          style: TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${project.estimatedMonthlyCost}/mo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          _formatTime(project.updatedAt),
                          style: const TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: Color(0xFF71717A),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
