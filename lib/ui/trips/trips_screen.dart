import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/trip.dart';
import '../../data/trip_repository.dart';
import '../../services/geocoding_service.dart';
import 'add_trip_screen.dart';
import 'trip_detail_screen.dart';
import 'widgets/trip_list_tile.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final Set<int> _resolvingAddresses = {};

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

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TripRepository>();
    final open = repo.openTrip;
    final trips = repo.trips;
    final grouped = _groupByDay(trips);

    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddTripScreen())),
        child: const Icon(Icons.add),
      ),
      body: trips.isEmpty && open == null
          ? const _EmptyState()
          : RefreshIndicator(
              onRefresh: repo.load,
              child: ListView(
                children: [
                  if (open != null) ...[
                    _SectionHeader('In progress'),
                    TripListTile(
                      trip: open,
                      onTap: () {},
                      onCategoryChanged: (_) {},
                    ),
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
                                builder: (_) =>
                                    TripDetailScreen(tripId: trip.id!),
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
            ),
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
