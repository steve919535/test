import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/trip.dart';
import '../../data/trip_repository.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TripRepository>();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);

    final monthBusinessKm = repo.totalKm(
      category: TripCategory.business,
      from: monthStart,
    );
    final monthPersonalKm = repo.totalKm(
      category: TripCategory.personal,
      from: monthStart,
    );
    final allBusinessKm = repo.totalKm(category: TripCategory.business);
    final allPersonalKm = repo.totalKm(category: TripCategory.personal);
    final unclassifiedCount = repo.tripCount(
      category: TripCategory.unclassified,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            DateFormat.yMMMM().format(now),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _BigStat(
                  label: 'Business km this month',
                  value: monthBusinessKm,
                  emphasize: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigStat(
                  label: 'Personal km this month',
                  value: monthPersonalKm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('All time', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _BigStat(
                  label: 'Business km',
                  value: allBusinessKm,
                  emphasize: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigStat(label: 'Personal km', value: allPersonalKm),
              ),
            ],
          ),
          if (unclassifiedCount > 0) ...[
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: Text(
                  '$unclassifiedCount trip${unclassifiedCount == 1 ? '' : 's'} not yet categorized',
                ),
                subtitle: const Text(
                  'Open the Trips tab to mark them Business or Personal.',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: emphasize ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: emphasize ? scheme.onPrimaryContainer : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${value.toStringAsFixed(1)} km',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: emphasize ? scheme.onPrimaryContainer : null,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
