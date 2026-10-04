/// Replaces the old `variablePricing: String?` free-text field. The
/// prose string was the actual root cause of a real bug: code could
/// only detect THAT a tool had variable pricing, never compute HOW
/// MUCH it would cost at a given usage level — so the zero-hard-cap
/// check treated the mere presence of any variable pricing as
/// automatically exceeding a $0 cap, which is wrong for a tool with a
/// free allowance before its rate kicks in (free up to N requests,
/// then charged per request beyond that).
///
/// With a unit and a rate, the cost at any given usage level is exact
/// arithmetic over catalogue-held numbers — not a guess, not an
/// interpolation, and able to correctly resolve to $0 when usage is
/// within the free allowance.
class VariableRate {
  /// Requests included at no charge before the per-unit rate applies.
  final int freeAllowanceRequests;

  /// Cost per request beyond the free allowance, in the same currency
  /// as the tool's fixed monthlyAmount.
  final double ratePerRequest;

  /// Beyond this many requests/month, the catalogue does not have
  /// confident pricing (e.g. the provider moves to custom/enterprise
  /// pricing past this point). A usage level beyond this reads as
  /// unknown for this tool, not as a computed (and likely wrong)
  /// extrapolation.
  final int? maxKnownRequests;

  const VariableRate({
    required this.freeAllowanceRequests,
    required this.ratePerRequest,
    this.maxKnownRequests,
  });

  factory VariableRate.fromJson(Map<String, dynamic> json) => VariableRate(
        freeAllowanceRequests: json['freeAllowanceRequests'] as int,
        ratePerRequest: (json['ratePerRequest'] as num).toDouble(),
        maxKnownRequests: json['maxKnownRequests'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'freeAllowanceRequests': freeAllowanceRequests,
        'ratePerRequest': ratePerRequest,
        'maxKnownRequests': maxKnownRequests,
      };

  /// Exact cost of the variable component at a given request volume —
  /// arithmetic, not a guess. Returns null if requestsPerMonth exceeds
  /// what the catalogue confidently knows pricing for.
  double? costAt(int requestsPerMonth) {
    if (maxKnownRequests != null && requestsPerMonth > maxKnownRequests!) {
      return null;
    }
    final billable = requestsPerMonth - freeAllowanceRequests;
    if (billable <= 0) return 0;
    return billable * ratePerRequest;
  }
}
