import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/trip.dart';
import '../../data/trip_repository.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late final TextEditingController _notesController;
  bool _notesInitialized = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TripRepository>();
    final trip = repo.findById(widget.tripId);

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Trip deleted')),
      );
    }

    if (!_notesInitialized) {
      _notesController = TextEditingController(text: trip.notes ?? '');
      _notesInitialized = true;
    }

    final dateFmt = DateFormat.yMMMEd();
    final timeFmt = DateFormat.jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, repo, trip),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            dateFmt.format(trip.startTime),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _LocationRow(
            icon: Icons.trip_origin,
            label: 'From',
            time: timeFmt.format(trip.startTime),
            address:
                trip.startAddress ??
                '${trip.startLat.toStringAsFixed(5)}, ${trip.startLng.toStringAsFixed(5)}',
          ),
          const SizedBox(height: 12),
          _LocationRow(
            icon: Icons.flag,
            label: 'To',
            time: trip.endTime == null ? '—' : timeFmt.format(trip.endTime!),
            address:
                trip.endAddress ??
                '${trip.endLat.toStringAsFixed(5)}, ${trip.endLng.toStringAsFixed(5)}',
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Distance',
                  value: '${trip.distanceKm.toStringAsFixed(1)} km',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Recorded',
                  value: trip.autoDetected ? 'Automatically' : 'Manually',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Category', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<TripCategory>(
            segments: const [
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
            selected: {trip.category},
            onSelectionChanged: (selection) =>
                repo.setCategory(trip.id!, selection.first),
          ),
          const SizedBox(height: 24),
          Text('Notes', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g. client visit, supplies run…',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => repo.updateNotes(
              trip.id!,
              value.trim().isEmpty ? null : value.trim(),
            ),
            onEditingComplete: () => repo.updateNotes(
              trip.id!,
              _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TripRepository repo,
    Trip trip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete trip?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && trip.id != null) {
      await repo.deleteTrip(trip.id!);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.label,
    required this.time,
    required this.address,
  });

  final IconData icon;
  final String label;
  final String time;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label · $time',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(address, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
