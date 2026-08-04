import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/trip.dart';
import '../../data/trip_repository.dart';
import '../../services/export_service.dart';
import '../../services/tracking_controller.dart';
import '../trips/widgets/trip_filter_sheet.dart';

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

  List<Trip> _tripsInRange(TripRepository repo, TripFilterSelection selection) {
    final (from, to) = selection.effectiveRange;
    return repo.filteredTrips(category: selection.category, from: from, to: to);
  }

  Future<void> _export(BuildContext context, {required bool asPdf}) async {
    final repo = context.read<TripRepository>();
    final selection = await showTripFilterSheet(
      context,
      TripFilterSelection.none,
    );
    if (selection == null) return;

    final trips = _tripsInRange(repo, selection);
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

  Future<void> _exportBusinessTaxReport(
    BuildContext context, {
    required bool asPdf,
  }) async {
    final repo = context.read<TripRepository>();
    const initial = TripFilterSelection(
      category: TripCategory.business,
      datePreset: TripDatePreset.thisYear,
    );
    final selection = await showTripFilterSheet(
      context,
      initial,
      lockCategory: true,
    );
    if (selection == null) return;

    final trips = _tripsInRange(repo, selection);
    if (trips.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No business trips in that period.')),
        );
      }
      return;
    }

    if (asPdf) {
      await ExportService.shareBusinessTaxReportPdf(
        trips,
        periodLabel: selection.dateRangeLabel,
      );
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
            subtitle: const Text(
              'Spreadsheet-friendly log of trips, filtered however you like',
            ),
            onTap: () => _export(context, asPdf: false),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Export PDF'),
            subtitle: const Text(
              'Printable mileage log with a business/personal summary',
            ),
            onTap: () => _export(context, asPdf: true),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Tax records',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Export business trips (CSV)'),
            subtitle: const Text('Business trips only, for a chosen period'),
            onTap: () => _exportBusinessTaxReport(context, asPdf: false),
          ),
          ListTile(
            leading: const Icon(Icons.summarize_outlined),
            title: const Text('Export business trips (tax report)'),
            subtitle: const Text(
              'A signed-off PDF report of business trips, ready to hand to an accountant',
            ),
            onTap: () => _exportBusinessTaxReport(context, asPdf: true),
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
