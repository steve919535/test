import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/trip.dart';

enum TripDatePreset { allTime, thisMonth, thisYear, custom }

/// The Trips screen's current filter state. Immutable -- edits produce a
/// new instance via [copyWith], same pattern as [Trip].
@immutable
class TripFilterSelection {
  const TripFilterSelection({
    this.category,
    this.datePreset = TripDatePreset.allTime,
    this.customRange,
  });

  final TripCategory? category;
  final TripDatePreset datePreset;
  final DateTimeRange? customRange;

  static const TripFilterSelection none = TripFilterSelection();

  bool get isActive => category != null || datePreset != TripDatePreset.allTime;

  /// The `[from, to)` bounds implied by [datePreset], for
  /// [TripRepository.filteredTrips]. Both null means unbounded.
  (DateTime?, DateTime?) get effectiveRange {
    final now = DateTime.now();
    switch (datePreset) {
      case TripDatePreset.allTime:
        return (null, null);
      case TripDatePreset.thisMonth:
        return (DateTime(now.year, now.month), null);
      case TripDatePreset.thisYear:
        return (DateTime(now.year), null);
      case TripDatePreset.custom:
        final range = customRange;
        if (range == null) return (null, null);
        // The picker returns date-only bounds; treat the end date as
        // covering the whole day by making the upper bound exclusive and
        // one day past it.
        return (
          range.start,
          DateTime(range.end.year, range.end.month, range.end.day + 1),
        );
    }
  }

  /// Human-readable date range only (no category), e.g. "This year" or
  /// "Jan 1 – Mar 31". Used both in [summary] and standalone wherever a
  /// report needs to state its covered period (e.g. the business tax
  /// report's "Period: ..." line).
  String get dateRangeLabel {
    switch (datePreset) {
      case TripDatePreset.allTime:
        return 'All time';
      case TripDatePreset.thisMonth:
        return 'This month';
      case TripDatePreset.thisYear:
        return 'This year';
      case TripDatePreset.custom:
        final range = customRange;
        if (range == null) return 'All time';
        final fmt = DateFormat.MMMd();
        return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
    }
  }

  String get summary {
    final parts = <String>[];
    if (category != null) parts.add(category!.label);
    if (datePreset != TripDatePreset.allTime) parts.add(dateRangeLabel);
    return parts.join(' · ');
  }

  TripFilterSelection copyWith({
    TripCategory? category,
    bool clearCategory = false,
    TripDatePreset? datePreset,
    DateTimeRange? customRange,
  }) {
    return TripFilterSelection(
      category: clearCategory ? null : (category ?? this.category),
      datePreset: datePreset ?? this.datePreset,
      customRange: customRange ?? this.customRange,
    );
  }
}

/// Opens the filter sheet and resolves with the user's new selection, or
/// null if they dismissed it without confirming.
///
/// [lockCategory] hides the Type selector entirely and always returns
/// [current]'s category unchanged -- used by the dedicated business-trip
/// export, where the category isn't a choice, only the date range is.
Future<TripFilterSelection?> showTripFilterSheet(
  BuildContext context,
  TripFilterSelection current, {
  bool lockCategory = false,
}) {
  return showModalBottomSheet<TripFilterSelection>(
    context: context,
    showDragHandle: true,
    builder: (context) =>
        _TripFilterSheet(initial: current, lockCategory: lockCategory),
  );
}

class _TripFilterSheet extends StatefulWidget {
  const _TripFilterSheet({required this.initial, this.lockCategory = false});

  final TripFilterSelection initial;
  final bool lockCategory;

  @override
  State<_TripFilterSheet> createState() => _TripFilterSheetState();
}

class _TripFilterSheetState extends State<_TripFilterSheet> {
  late TripCategory? _category = widget.initial.category;
  late TripDatePreset _datePreset = widget.initial.datePreset;
  late DateTimeRange? _customRange = widget.initial.customRange;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now,
      initialDateRange: _customRange,
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _datePreset = TripDatePreset.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter trips', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('Date range', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All time'),
                selected: _datePreset == TripDatePreset.allTime,
                onSelected: (_) =>
                    setState(() => _datePreset = TripDatePreset.allTime),
              ),
              ChoiceChip(
                label: const Text('This month'),
                selected: _datePreset == TripDatePreset.thisMonth,
                onSelected: (_) =>
                    setState(() => _datePreset = TripDatePreset.thisMonth),
              ),
              ChoiceChip(
                label: const Text('This year'),
                selected: _datePreset == TripDatePreset.thisYear,
                onSelected: (_) =>
                    setState(() => _datePreset = TripDatePreset.thisYear),
              ),
              ChoiceChip(
                label: Text(
                  _customRange == null
                      ? 'Custom…'
                      : '${DateFormat.MMMd().format(_customRange!.start)} – ${DateFormat.MMMd().format(_customRange!.end)}',
                ),
                selected: _datePreset == TripDatePreset.custom,
                onSelected: (_) => _pickCustomRange(),
              ),
            ],
          ),
          if (!widget.lockCategory) ...[
            const SizedBox(height: 20),
            Text('Type', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<TripCategory?>(
              segments: const [
                ButtonSegment(value: null, label: Text('All')),
                ButtonSegment(
                  value: TripCategory.business,
                  label: Text('Business'),
                ),
                ButtonSegment(
                  value: TripCategory.personal,
                  label: Text('Personal'),
                ),
                ButtonSegment(
                  value: TripCategory.unclassified,
                  label: Text('Unset'),
                ),
              ],
              selected: {_category},
              onSelectionChanged: (s) => setState(() => _category = s.first),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              if (!widget.lockCategory)
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, TripFilterSelection.none),
                  child: const Text('Clear'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  TripFilterSelection(
                    category: widget.lockCategory
                        ? widget.initial.category
                        : _category,
                    datePreset: _datePreset,
                    customRange: _customRange,
                  ),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
