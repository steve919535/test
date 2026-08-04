import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/trip.dart';
import '../../data/trip_repository.dart';
import '../../services/geocoding_service.dart';
import 'add_trip_screen.dart';
import 'trip_detail_screen.dart';
import 'widgets/trip_filter_sheet.dart';
import 'widgets/trip_list_tile.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final Set<int> _resolvingAddresses = {};
  TripFilterSelection _filter = TripFilterSelection.none;

  void _resolveAddressesIfNeeded(TripRepository repo, Trip trip) {
    if (trip.id == null) return;
    if (trip.startAddress != null && trip.endAddress != null) return;
    if (!_resolvingAddresses.add(trip.id!)) return;

    Future(() async {
      final startAddress =
          trip.startAddress ??
          await GeocodingService.reverseGeocode(trip.startLat, trip.startLng);
      final endAddress = trip.isOpen
          ? null
          : trip.endAddress ??
                await GeocodingService.reverseGeocode(trip.endLat, trip.endLng);
      if (startAddress != null || endAddress != null) {
        await repo.updateAddresses(
          trip.id!,
          startAddress: startAddress,
          endAddress: endAddress,
        );
      }
    });
  }

  Future<void> _openFilterSheet() async {
    final result = await showTripFilterSheet(context, _filter);
    if (result != null) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TripRepository>();
    final open = repo.openTrip;
    final hasAnyData = repo.trips.isNotEmpty || open != null;

    final (from, to) = _filter.effectiveRange;
    final trips = repo.filteredTrips(
      category: _filter.category,
      from: from,
      to: to,
    );
    final grouped = _groupByDay(trips);

    final Widget body;
    if (!hasAnyData) {
      body = const _EmptyState();
    } else if (trips.isEmpty && open == null) {
      body = _NoMatchState(
        onClearFilters: () =>
            setState(() => _filter = TripFilterSelection.none),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: repo.load,
        child: ListView(
          children: [
            if (open != null) ...[
              _SectionHeader('In progress'),
              TripListTile(trip: open, onTap: () {}, onCategoryChanged: (_) {}),
            ],
            for (final entry in grouped.entries) ...[
              _SectionHeader(entry.key),
              for (final trip in entry.value) ...[
                Builder(
                  builder: (context) {
                    _resolveAddressesIfNeeded(repo, trip);
                    return TripListTile(
                      trip: trip,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TripDetailScreen(tripId: trip.id!),
                        ),
                      ),
                      onCategoryChanged: (category) =>
                          repo.setCategory(trip.id!, category),
                    );
                  },
                ),
              ],
            ],
            const SizedBox(height: 80),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          IconButton(
            icon: Icon(
              _filter.isActive ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            tooltip: 'Filter trips',
            onPressed: _openFilterSheet,
          ),
        ],
        bottom: _filter.isActive
            ? _ActiveFilterBar(
                filter: _filter,
                onClear: () =>
                    setState(() => _filter = TripFilterSelection.none),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddTripScreen())),
        child: const Icon(Icons.add),
      ),
      body: body,
    );
  }

  Map<String, List<Trip>> _groupByDay(List<Trip> trips) {
    final fmt = DateFormat.yMMMEd();
    final map = <String, List<Trip>>{};
    for (final trip in trips) {
      final key = fmt.format(trip.startTime);
      map.putIfAbsent(key, () => []).add(trip);
    }
    return map;
  }
}

class _ActiveFilterBar extends StatelessWidget implements PreferredSizeWidget {
  const _ActiveFilterBar({required this.filter, required this.onClear});

  final TripFilterSelection filter;
  final VoidCallback onClear;

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              filter.summary,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('Clear')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No trips yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Turn on automatic tracking in Settings, or add a trip manually with the + button.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatchState extends StatelessWidget {
  const _NoMatchState({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No trips match these filters',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onClearFilters,
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }
}
