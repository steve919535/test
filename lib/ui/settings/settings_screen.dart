import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/trip.dart';
import '../../data/trip_repository.dart';
import '../../services/export_service.dart';
import '../../services/tracking_controller.dart';

enum _RangeOption { allTime, thisMonth }

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _toggleTracking(BuildContext context, bool enable) async {
    final tracking = context.read<TrackingController>();
    if (!enable) {
      await tracking.stop();
      return;
    }

    final result = await tracking.start();
    if (!context.mounted) return;

    switch (result) {
      case TrackingStartResult.success:
        break;
      case TrackingStartResult.locationServicesDisabled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Turn on Location Services for this device to enable tracking.',
            ),
          ),
        );
      case TrackingStartResult.permissionDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission (set to "Always allow") is required for automatic tracking.',
            ),
          ),
        );
    }
  }

  Future<void> _export(BuildContext context, {required bool asPdf}) async {
    final repo = context.read<TripRepository>();
    final selection = await showModalBottomSheet<_ExportSelection>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _ExportOptionsSheet(),
    );
    if (selection == null) return;

    final now = DateTime.now();
    final from = selection.range == _RangeOption.thisMonth
        ? DateTime(now.year, now.month)
        : null;
    final trips = repo.trips.where((t) {
      if (from != null && t.startTime.isBefore(from)) return false;
      if (selection.category != null && t.category != selection.category) {
        return false;
      }
      return true;
    }).toList();

    if (trips.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No trips match that filter.')),
        );
      }
      return;
    }

    if (asPdf) {
      await ExportService.sharePdf(trips);
    } else {
      await ExportService.shareCsv(trips);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Automatic trip detection'),
            subtitle: const Text(
              'Records a trip whenever the app detects sustained driving speed, and ends it after a few minutes stopped.',
            ),
            value: tracking.isRunning,
            onChanged: (value) => _toggleTracking(context, value),
          ),
          if (Platform.isAndroid && tracking.isRunning)
            ListTile(
              leading: const Icon(Icons.battery_charging_full),
              title: const Text('Improve tracking reliability'),
              subtitle: const Text(
                'Exempt this app from battery optimization so Android doesn\'t stop tracking.',
              ),
              onTap: () => tracking.requestBatteryOptimizationExemption(),
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Export',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export CSV'),
            subtitle: const Text('Spreadsheet-friendly log of every trip'),
            onTap: () => _export(context, asPdf: false),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Export PDF'),
            subtitle: const Text('Printable mileage log with a summary'),
            onTap: () => _export(context, asPdf: true),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'All trip data stays on this device. Nothing is uploaded, and there\'s no account required.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportSelection {
  const _ExportSelection(this.range, this.category);
  final _RangeOption range;
  final TripCategory? category;
}

class _ExportOptionsSheet extends StatefulWidget {
  const _ExportOptionsSheet();

  @override
  State<_ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<_ExportOptionsSheet> {
  _RangeOption _range = _RangeOption.thisMonth;
  TripCategory? _category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Export trips', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('Date range', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<_RangeOption>(
            segments: const [
              ButtonSegment(
                value: _RangeOption.thisMonth,
                label: Text('This month'),
              ),
              ButtonSegment(
                value: _RangeOption.allTime,
                label: Text('All time'),
              ),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
          ),
          const SizedBox(height: 16),
          Text('Category', style: Theme.of(context).textTheme.labelLarge),
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
            ],
            selected: {_category},
            onSelectionChanged: (s) => setState(() => _category = s.first),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _ExportSelection(_range, _category)),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
