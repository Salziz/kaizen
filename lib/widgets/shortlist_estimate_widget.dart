import 'package:flutter/material.dart';

import '../models/usage_level.dart';
import '../services/project_estimate.dart';
import '../services/shortlist_generator.dart';
import '../services/tool_price_catalogue.dart';

/// Interactive UI delivering TFS-007 (The Number).
///
/// Fulfills user-facing acceptance criteria:
/// - AC01: Mark one or more tools in the shortlist
/// - AC02: View upfront estimate for project with plain-words basis
/// - AC03: Moving along usage ladder (Starter/Growth/Scale) updates the total
/// - AC04: All figures are catalogue-held; unknown reads as "Unknown", never as a number;
///         carries one-time vs recurring attribute from the catalogue
/// - AC05: Empty selection shows clear prompt explaining what choosing will produce,
///         never treating an empty selection as a real $0 estimate
/// - AC06: Comprehensive breakdown per tool and total, including verification dates
class ShortlistEstimateWidget extends StatefulWidget {
  const ShortlistEstimateWidget({
    super.key,
    required this.shortlist,
    this.catalogue = kToolPriceCatalogue,
  });

  final ShortlistResult shortlist;
  final Map<String, ToolPriceEstimate> catalogue;

  @override
  State<ShortlistEstimateWidget> createState() =>
      _ShortlistEstimateWidgetState();
}

class _ShortlistEstimateWidgetState extends State<ShortlistEstimateWidget> {
  // AC05: Starts empty so no estimate is displayed until the user chooses tools.
  final Set<String> _markedTools = <String>{};
  UsageLevel _selectedLevel = UsageLevel.growth;

  void _toggleTool(String toolName) {
    setState(() {
      if (_markedTools.contains(toolName)) {
        _markedTools.remove(toolName);
      } else {
        _markedTools.add(toolName);
      }
    });
  }

  String _currencySymbol(String currency) {
    return switch (currency) {
      'USD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      _ => '$currency ',
    };
  }

  String _formatContributionCost(ToolContribution contribution) {
    if (contribution.monthlyCost == null) {
      return 'Unknown';
    }
    final symbol = _currencySymbol(contribution.currency);
    final amount = contribution.monthlyCost!;
    final amountStr = amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2);
    final unit = contribution.isRecurring ? '/month' : '';
    return '$symbol$amountStr$unit';
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = widget.shortlist.recommendations;
    final budgetAcknowledgment = widget.shortlist.budgetAcknowledgment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (budgetAcknowledgment != null &&
            budgetAcknowledgment.trim().isNotEmpty) ...[
          Text(
            budgetAcknowledgment,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFAFAFA),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'Recommended shortlist',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF10B981),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Mark tools to include or exclude them from your project estimate:',
          style: TextStyle(fontSize: 12.5, color: Color(0xFFA1A1AA)),
        ),
        const SizedBox(height: 10),
        ...recommendations.map((tool) => _buildToolTile(tool)),
        const SizedBox(height: 16),
        _buildEstimateSection(),
      ],
    );
  }

  Widget _buildToolTile(ToolRecommendation tool) {
    final isMarked = _markedTools.contains(tool.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1D24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMarked ? const Color(0xFF10B981) : const Color(0xFF27272A),
          width: isMarked ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        key: Key('tool_tile_${tool.name}'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => _toggleTool(tool.name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: Key('tool_checkbox_${tool.name}'),
                value: isMarked,
                activeColor: const Color(0xFF10B981),
                checkColor: Colors.black,
                side: const BorderSide(color: Color(0xFF71717A)),
                onChanged: (_) => _toggleTool(tool.name),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tool.name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x2610B981),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tool.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF34D399),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tool.rationale,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFD4D4D8),
                      ),
                    ),
                    if (tool.tradeoff.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Tradeoff: ${tool.tradeoff}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFFA1A1AA),
                        ),
                      ),
                    ],
                    if (tool.budgetAssessment.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tool.budgetAssessment,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF71717A),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstimateSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14151B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.calculate_outlined,
                size: 20,
                color: Color(0xFF10B981),
              ),
              SizedBox(width: 8),
              Text(
                'Upfront Cost Estimate',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_markedTools.isEmpty) ...[
            // AC05: Empty selection must not invoke buildProjectEstimate
            // and must not treat empty selection as a real $0 estimate.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'No tools marked',
                    key: Key('empty_selection_heading'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Mark one or more tools above to calculate your project estimate. '
                    'Choosing tools will show an upfront monthly cost breakdown and '
                    'total based on your assumed usage.',
                    key: Key('empty_selection_message'),
                    style: TextStyle(fontSize: 12.5, color: Color(0xFFA1A1AA)),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildEstimateDetails(),
          ],
        ],
      ),
    );
  }

  Widget _buildEstimateDetails() {
    final estimate = buildProjectEstimate(
      chosenToolNames: _markedTools.toList(),
      usageLevel: _selectedLevel,
      catalogue: widget.catalogue,
    );

    final isAllRecurring = estimate.contributions.isNotEmpty &&
        estimate.contributions.every((c) => c.isRecurring);
    final isAllOneTime = estimate.contributions.isNotEmpty &&
        estimate.contributions.every((c) => !c.isRecurring);
    final totalCadence = isAllRecurring
        ? 'recurring'
        : isAllOneTime
            ? 'one-time'
            : 'mixed cadence';
    final totalUnit = isAllRecurring ? ' / month' : '';
    final totalCurrencySymbol = _currencySymbol(estimate.currency ?? 'USD');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Usage level selector (AC03)
        const Text(
          'Usage assumption ladder:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFA1A1AA),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: UsageLevel.values.map((level) {
            final isSelected = level == _selectedLevel;
            final label = switch (level) {
              UsageLevel.starter => 'Starter (1k)',
              UsageLevel.growth => 'Growth (10k)',
              UsageLevel.scale => 'Scale (100k)',
            };
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  key: Key('usage_rung_${level.name}'),
                  label: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color:
                            isSelected ? Colors.black : const Color(0xFFA1A1AA),
                      ),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF10B981),
                  backgroundColor: const Color(0xFF1C1D24),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF10B981)
                        : const Color(0xFF27272A),
                  ),
                  onSelected: (_) {
                    setState(() => _selectedLevel = level);
                  },
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Plain-words basis (AC02)
        Text(
          estimate.usageAssumptionLabel,
          key: const Key('usage_assumption_label'),
          style: const TextStyle(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: Color(0xFFA1A1AA),
          ),
        ),
        const Divider(height: 20, color: Color(0xFF27272A)),
        // Per-tool breakdown (AC04 & AC06)
        Text(
          'Tool contributions (${estimate.contributions.length}):',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        ...estimate.contributions.map((contribution) {
          final costText = _formatContributionCost(contribution);
          final cadenceText =
              contribution.isRecurring ? 'recurring' : 'one-time';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      contribution.toolName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$costText ($cadenceText)',
                      key: Key('contribution_cost_${contribution.toolName}'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: contribution.monthlyCost != null
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
                if (contribution.knownLimitation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      contribution.knownLimitation!,
                      key: Key(
                        'contribution_limitation_${contribution.toolName}',
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFB923C),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    contribution.lastChecked.isNotEmpty
                        ? 'Price verified: ${contribution.lastChecked}'
                        : 'Price unverified',
                    key: Key('contribution_verified_${contribution.toolName}'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF71717A),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const Divider(height: 20, color: Color(0xFF27272A)),
        // Grand total (AC02, AC03, AC04)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total project estimate:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (estimate.total != null)
              Text(
                '$totalCurrencySymbol${estimate.total!.toStringAsFixed(estimate.total! % 1 == 0 ? 0 : 2)}$totalUnit',
                key: const Key('project_estimate_total'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              )
            else
              const Text(
                'Unknown',
                key: Key('project_estimate_total'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFBBF24),
                ),
              ),
          ],
        ),
        if (estimate.total != null) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${estimate.currency ?? 'USD'}, $totalCadence',
              key: const Key('project_estimate_cadence'),
              style: const TextStyle(fontSize: 11, color: Color(0xFFA1A1AA)),
            ),
          ),
        ] else ...[
          const SizedBox(height: 4),
          const Text(
            'Total cannot be calculated because pricing for one or more chosen tools is unknown at this usage level.',
            key: Key('project_estimate_caveat'),
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: Color(0xFFA1A1AA),
            ),
          ),
        ],
      ],
    );
  }
}
