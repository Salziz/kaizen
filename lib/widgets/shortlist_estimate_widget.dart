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
/// - AC06: Comprehensive breakdown per tool and total
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
  late final Set<String> _markedTools;
  UsageLevel _selectedLevel = UsageLevel.growth;

  @override
  void initState() {
    super.initState();
    _markedTools = widget.shortlist.recommendations
        .map((tool) => tool.name)
        .toSet();
  }

  void _toggleTool(String toolName) {
    setState(() {
      if (_markedTools.contains(toolName)) {
        _markedTools.remove(toolName);
      } else {
        _markedTools.add(toolName);
      }
    });
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
              color: Color(0xFF1B2B27),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'Recommended shortlist',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F6B5C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Mark tools to include or exclude them from your project estimate:',
          style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMarked ? const Color(0xFF0F6B5C) : const Color(0xFFDFE3E9),
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
                activeColor: const Color(0xFF0F6B5C),
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
                            color: Color(0xFF1B2B27),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F3F1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tool.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F6B5C),
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
                        color: Color(0xFF2C3E38),
                      ),
                    ),
                    if (tool.tradeoff.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Tradeoff: ${tool.tradeoff}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    if (tool.budgetAssessment.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tool.budgetAssessment,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF55655E),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDFE3E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.calculate_outlined,
                size: 20,
                color: Color(0xFF0F6B5C),
              ),
              SizedBox(width: 8),
              Text(
                'Upfront Cost Estimate',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B2B27),
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
                children: [
                  const Text(
                    'No tools marked',
                    key: Key('empty_selection_heading'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Color(0xFF8A5A00),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mark one or more tools above to calculate your project estimate. '
                    'Choosing tools will show an upfront monthly cost breakdown and '
                    'total based on your assumed usage.',
                    key: const Key('empty_selection_message'),
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Usage level selector (AC03)
        Text(
          'Usage assumption ladder:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
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
                            isSelected ? Colors.white : const Color(0xFF1B2B27),
                      ),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0F6B5C),
                  backgroundColor: const Color(0xFFF3F5F8),
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
          style: TextStyle(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: Colors.grey[700],
          ),
        ),
        const Divider(height: 20),
        // Per-tool breakdown (AC04 & AC06)
        Text(
          'Tool contributions (${estimate.contributions.length}):',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B2B27),
          ),
        ),
        const SizedBox(height: 6),
        ...estimate.contributions.map((contribution) {
          final costText = contribution.monthlyCost != null
              ? '\$${contribution.monthlyCost!.toStringAsFixed(contribution.monthlyCost! % 1 == 0 ? 0 : 2)}/mo'
              : 'Unknown';
          final cadenceText =
              contribution.isRecurring ? 'recurring' : 'one-time';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
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
                        color: Color(0xFF1B2B27),
                      ),
                    ),
                    Text(
                      '$costText ($cadenceText)',
                      key: Key('contribution_cost_${contribution.toolName}'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: contribution.monthlyCost != null
                            ? const Color(0xFF0F6B5C)
                            : const Color(0xFF8A5A00),
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
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        const Divider(height: 20),
        // Grand total (AC02, AC03, AC04)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total project estimate:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B2B27),
              ),
            ),
            if (estimate.total != null)
              Text(
                '\$${estimate.total!.toStringAsFixed(estimate.total! % 1 == 0 ? 0 : 2)} / mo',
                key: const Key('project_estimate_total'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F6B5C),
                ),
              )
            else
              const Text(
                'Unknown',
                key: Key('project_estimate_total'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8A5A00),
                ),
              ),
          ],
        ),
        if (estimate.total != null) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${estimate.currency ?? 'USD'}, recurring',
              key: const Key('project_estimate_cadence'),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            'Total cannot be calculated because pricing for one or more chosen tools is unknown at this usage level.',
            key: const Key('project_estimate_caveat'),
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: Colors.grey[700],
            ),
          ),
        ],
      ],
    );
  }
}
