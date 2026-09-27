import 'shortlist_generator.dart';

/// Rough monthly estimates reviewed against provider pricing pages on
/// 2026-09-26. They are not quotes; replies include the source and review date.
/// Amounts are USD. A non-USD budget gets a fit/break verdict only when no
/// exchange rate is required (zero listed fixed cost, or a zero cap against a
/// strictly positive listed cost or positive variable fee). Variable fees are
/// otherwise unknown unless the stated cap itself settles the comparison.
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
    basis: 'No fixed monthly fee; US domestic online card pricing',
    sourceUrl: 'https://stripe.com/pricing',
    lastChecked: '2026-09-26',
    variablePricing: '2.9% + 30 cents per transaction',
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
