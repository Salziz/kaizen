import '../models/project_state.dart';
import 'shortlist_generator.dart';
import 'tool_price_catalogue.dart';

/// Provides intelligent, deterministic project fact extraction and shortlist
/// generation for offline demos or when GROQ_API_KEY is not configured.
///
/// Ensures the app remains 100% functional, responsive, and resilient during
/// live presentations and Demo Day showcases.
class DemoFallbackService {
  const DemoFallbackService();

  static ShortlistResult generateShortlistResult(String prompt) {
    final state = extractDemoFacts(prompt);
    return generateShortlist(state, priceEstimates: kToolPriceCatalogue);
  }

  static ProjectState extractDemoFacts(String prompt) {
    final lower = prompt.toLowerCase();

    // 1. Detect project category
    String? projectType;
    if (lower.contains('storefront') ||
        lower.contains('ecommerce') ||
        lower.contains('e-commerce') ||
        lower.contains('shop') ||
        lower.contains('store') ||
        lower.contains('cart')) {
      projectType = 'Storefront';
    } else if (lower.contains('chat') ||
        lower.contains('messaging') ||
        lower.contains('social') ||
        lower.contains('community') ||
        lower.contains('mobile app') ||
        lower.contains('flutter app') ||
        lower.contains('ios') ||
        lower.contains('android')) {
      projectType = 'Mobile app';
    } else if (lower.contains('agent') ||
        lower.contains('ai') ||
        lower.contains('llm') ||
        lower.contains('research agent') ||
        lower.contains('pulse')) {
      projectType = 'AI Agent';
    } else if (lower.contains('saas') ||
        lower.contains('dashboard') ||
        lower.contains('crm') ||
        lower.contains('analytics') ||
        lower.contains('platform')) {
      projectType = 'SaaS';
    } else if (lower.contains('app') || lower.contains('project') || lower.contains('tool')) {
      projectType = 'Application';
    }

    // If completely vague (e.g. "hello", "hi", "test"), return null projectType
    // so the recommendation gate triggers clarifying questions as designed.
    if (lower == 'hello' || lower == 'hi' || lower == 'hey' || lower.length < 5) {
      projectType = null;
    }

    // 2. Detect platforms
    final platforms = <String>[];
    if (lower.contains('ios') || lower.contains('iphone')) platforms.add('iOS');
    if (lower.contains('android')) platforms.add('Android');
    if (lower.contains('web') || lower.contains('browser')) platforms.add('Web');
    if (lower.contains('mobile') && platforms.isEmpty) {
      platforms.addAll(['iOS', 'Android']);
    }

    // 3. Detect features
    final features = <String>[];
    if (lower.contains('realtime') || lower.contains('real-time') || lower.contains('sync')) {
      features.add('realtime');
    }
    if (lower.contains('auth') || lower.contains('login') || lower.contains('users')) {
      features.add('auth');
    }
    if (lower.contains('payment') || lower.contains('stripe') || lower.contains('checkout')) {
      features.add('payments');
    }
    if (lower.contains('memory') || lower.contains('vector') || lower.contains('pgvector')) {
      features.add('vector memory');
    }
    if (lower.contains('workflow') || lower.contains('background') || lower.contains('job')) {
      features.add('background workflows');
    }
    if (lower.contains('monitor') || lower.contains('error') || lower.contains('logging')) {
      features.add('error monitoring');
    }

    // 4. Detect budget
    Budget? budget;
    if (lower.contains('free') || lower.contains('\$0') || lower.contains('zero cost') || lower.contains('no budget')) {
      budget = const Budget(
        amount: 0,
        currency: 'USD',
        hard: true,
        period: BudgetPeriod.unspecified,
      );
    } else {
      // Look for dollar amounts: e.g. "$50", "$100/mo", "50 dollars", "50/month"
      final regex = RegExp(r'\$(\d+(?:\.\d+)?)|(\d+(?:\.\d+)?)\s*(?:dollars|usd|\/mo|per month)');
      final match = regex.firstMatch(lower);
      if (match != null) {
        final amountStr = match.group(1) ?? match.group(2);
        final amount = double.tryParse(amountStr ?? '');
        if (amount != null) {
          final isMonthly = lower.contains('month') || lower.contains('/mo');
          budget = Budget(
            amount: amount,
            currency: 'USD',
            hard: lower.contains('hard') || lower.contains('max') || lower.contains('cap') || lower.contains('limit'),
            period: isMonthly ? BudgetPeriod.monthly : BudgetPeriod.unspecified,
          );
        }
      }
    }

    return ProjectState(
      projectType: projectType,
      budget: budget,
      platforms: platforms,
      features: features,
    );
  }
}
