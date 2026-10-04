import 'shortlist_generator.dart';
import '../models/variable_rate.dart';

/// Rough monthly estimates reviewed against provider pricing pages on
/// 2026-09-26. They are not quotes; replies include the source and review
/// date. Amounts are USD.
///
/// NOTE ON STRIPE PRICING (AC04):
/// Stripe's published rate is "2.9% + 30 cents per transaction."
/// While the flat 30-cent fee is known per request, the 2.9% transaction-value
/// component requires knowing the monetary volume per transaction, which
/// the request-volume ladder does not collect.
/// Per AC04 ("any value the catalogue does not hold reads as unknown, never as
/// a number"), Stripe's estimate is classified as unknown (`isPriceUnknown: true`,
/// `monthlyCost: null`) at every ladder rung rather than displaying an incomplete
/// flat-fee number that misrepresents the actual cost to the user.
const Map<String, ToolPriceEstimate> kToolPriceCatalogue = {
  'Supabase': ToolPriceEstimate(
    monthlyAmount: 0,
    currency: 'USD',
    basis: 'Free tier - 500MB database, 50K monthly active users',
    sourceUrl: 'https://supabase.com/pricing',
    lastChecked: '2026-09-26',
  ),
  'Firebase': ToolPriceEstimate(
    monthlyAmount: 0,
    currency: 'USD',
    basis: 'Spark (free) plan - capped usage, no billing required',
    sourceUrl: 'https://firebase.google.com/pricing',
    lastChecked: '2026-09-26',
  ),
  'Vercel': ToolPriceEstimate(
    monthlyAmount: 0,
    currency: 'USD',
    basis: 'Hobby plan - free for non-commercial/small projects',
    sourceUrl: 'https://vercel.com/pricing',
    lastChecked: '2026-09-26',
  ),
  'Stripe': ToolPriceEstimate(
    monthlyAmount: 0,
    currency: 'USD',
    basis:
        'No fixed monthly fee; US domestic online card pricing is 2.9% + \$0.30 '
        'per transaction. Total cost depends on transaction dollar volume, which '
        'is unstated, so cost at all usage rungs reads as unknown per AC04.',
    sourceUrl: 'https://stripe.com/pricing',
    lastChecked: '2026-09-26',
    variableRate: VariableRate(
      freeAllowanceRequests: 0,
      ratePerRequest: 0.30,
      maxKnownRequests: null,
    ),
    isRecurring: true,
    isPriceUnknown: true,
    knownLimitation:
        'Excludes 2.9% transaction-value fee which requires transaction volume; total cost is unknown.',
  ),
  'Shopify': ToolPriceEstimate(
    monthlyAmount: 29,
    currency: 'USD',
    basis: 'Basic plan starting price',
    sourceUrl: 'https://www.shopify.com/pricing',
    lastChecked: '2026-09-26',
  ),
  'Sentry': ToolPriceEstimate(
    monthlyAmount: 0,
    currency: 'USD',
    basis: 'Free developer plan - 5K events/month',
    sourceUrl: 'https://sentry.io/pricing/',
    lastChecked: '2026-09-26',
  ),
  'Unity Gaming Services': ToolPriceEstimate(
    monthlyAmount: 0,
    currency: 'USD',
    basis: 'Free tier for small/indie projects',
    sourceUrl: 'https://unity.com/solutions/gaming-services/pricing',
    lastChecked: '2026-09-26',
  ),
  'Stream Chat': ToolPriceEstimate(
    monthlyAmount: 99,
    currency: 'USD',
    basis: 'Maker plan starting price - no free production tier',
    sourceUrl: 'https://getstream.io/chat/pricing/',
    lastChecked: '2026-09-26',
  ),
};
