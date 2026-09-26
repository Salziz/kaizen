import 'shortlist_generator.dart';

/// Rough monthly estimates used to make budget fit/break comparisons
/// reachable. These are not live-verified; generated replies tell users to
/// confirm current provider pricing before committing.
///
/// TODO: Track a source and verification date for each entry before relying on
/// these estimates as current prices.
final Map<String, ToolPriceEstimate> kToolPriceCatalogue = {
  'Supabase': const ToolPriceEstimate(
    monthlyAmount: 0,
    currency: 'USD',
    basis: 'Free tier - 500MB database, 50K monthly active users',
  ),
  'Firebase': const ToolPriceEstimate(
    monthlyAmount: 0,
    currency: 'USD',
    basis: 'Spark (free) plan - capped usage, no billing required',
  ),
  'Vercel': const ToolPriceEstimate(
    monthlyAmount: 0,
    currency: 'USD',
    basis: 'Hobby plan - free for non-commercial/small projects',
  ),
  'Stripe': const ToolPriceEstimate(
    monthlyAmount: 0,
    currency: 'USD',
    basis: 'No fixed monthly fee - 2.9% + 30 cents per transaction only',
  ),
  'Shopify': const ToolPriceEstimate(
    monthlyAmount: 29,
    currency: 'USD',
    basis: 'Basic plan starting price',
  ),
  'Sentry': const ToolPriceEstimate(
    monthlyAmount: 0,
    currency: 'USD',
    basis: 'Free developer plan - 5K events/month',
  ),
  'Unity Gaming Services': const ToolPriceEstimate(
    monthlyAmount: 0,
    currency: 'USD',
    basis: 'Free tier for small/indie projects',
  ),
  'Stream Chat': const ToolPriceEstimate(
    monthlyAmount: 99,
    currency: 'USD',
    basis: 'Maker plan starting price - no free production tier',
  ),
};
