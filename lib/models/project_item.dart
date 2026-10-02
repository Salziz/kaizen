import 'dart:convert';

/// Represents a project on the Projects hub screen.
class ProjectItem {
  const ProjectItem({
    required this.id,
    required this.title,
    required this.description,
    required this.domain,
    required this.stage,
    required this.tools,
    required this.estimatedMonthlyCost,
    required this.updatedAt,
    this.status = 'Evaluating Stack',
  });

  final String id;
  final String title;
  final String description;
  final String domain;
  final String stage;
  final List<String> tools;
  final String estimatedMonthlyCost;
  final DateTime updatedAt;
  final String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'domain': domain,
        'stage': stage,
        'tools': tools,
        'estimatedMonthlyCost': estimatedMonthlyCost,
        'updatedAt': updatedAt.toIso8601String(),
        'status': status,
      };

  factory ProjectItem.fromJson(Map<String, dynamic> json) => ProjectItem(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        domain: json['domain'] as String,
        stage: json['stage'] as String? ?? 'MVP',
        tools: (json['tools'] as List<dynamic>).map((e) => e as String).toList(),
        estimatedMonthlyCost: json['estimatedMonthlyCost'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        status: json['status'] as String? ?? 'Evaluating Stack',
      );

  static List<ProjectItem> sampleProjects() {
    final now = DateTime.now();
    return [
      ProjectItem(
        id: 'proj-pulse-ai',
        title: 'Pulse AI',
        description:
            'Autonomous customer support & workflow agent with streaming LLM replies.',
        domain: 'AI & LLM Agent',
        stage: 'Building MVP',
        tools: ['Supabase Pro', 'Vercel Pro', 'Trigger.dev'],
        estimatedMonthlyCost: '\$95',
        updatedAt: now.subtract(const Duration(minutes: 42)),
        status: 'Architecture Ready',
      ),
      ProjectItem(
        id: 'proj-kite-mobile',
        title: 'Kite Mobile',
        description:
            'Cross-platform wellness & habit tracking app with cloud sync.',
        domain: 'Mobile App',
        stage: 'Idea & Architecture',
        tools: ['Supabase Pro', 'Sentry Team'],
        estimatedMonthlyCost: '\$51',
        updatedAt: now.subtract(const Duration(hours: 3)),
        status: 'Evaluating Stack',
      ),
      ProjectItem(
        id: 'proj-nova-commerce',
        title: 'Nova Storefront',
        description:
            'Headless e-commerce shop with global checkout and edge caching.',
        domain: 'E-Commerce',
        stage: 'Scaling & Optimization',
        tools: ['Shopify', 'Vercel Pro', 'Stripe'],
        estimatedMonthlyCost: '\$49',
        updatedAt: now.subtract(const Duration(days: 1)),
        status: 'In Production',
      ),
    ];
  }

  static String encodeList(List<ProjectItem> list) =>
      jsonEncode(list.map((p) => p.toJson()).toList());

  static List<ProjectItem> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => ProjectItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
