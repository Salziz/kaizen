import 'shortlist_generator.dart';
import '../models/variable_rate.dart';

/// Rough monthly estimates reviewed against provider pricing pages on
/// 2026-09-26. They are not quotes; replies include the source and review
/// date. Amounts are USD.
///
/// FLAGGED LIMITATION — read before extending this file further:
/// Stripe's real published rate is "2.9% + 30 cents per transaction."
/// VariableRate can represent the flat 30-cent-per-request component
/// exactly (it's a real, catalogue-held number), but NOT the 2.9%
/// percentage-of-value component — that requires knowing the dollar
/// value per transaction, which this catalogue does not collect and
/// has no honest way to estimate without guessing. So Stripe's
/// variableRate below models ONLY the flat per-transaction fee; any
/// total computed from it is a real lower bound, not the full cost.
/// This needs an explicit decision from Adaeze/the team: is a
/// request-count-only usage ladder simply insufficient for
/// percentage-of-volume pricing models, and if so, should Stripe (and
/// any future percentage-fee tool) be marked as "unknown" at every
/// rung instead of silently showing a partial number? Left as-is for
/// now (flat fee only, nothing invented) pending that decision.
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
        'No fixed monthly fee; US domestic online card pricing. Variable '
        'rate below covers only the flat per-transaction component — see '
        'the flagged limitation note at the top of this file.',
    sourceUrl: 'https://stripe.com/pricing',
    lastChecked: '2026-09-26',
    variableRate: VariableRate(
      freeAllowanceRequests: 0,
      ratePerRequest: 0.30, // the flat 30-cent component only
      maxKnownRequests: null,
    ),
    knownLimitation:
        'Flat fee only; excludes 2.9% transaction-value fee which requires transaction volume.',
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
