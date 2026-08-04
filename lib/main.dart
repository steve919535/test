import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/trip_repository.dart';
import 'services/notification_service.dart';
import 'services/tracking_controller.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';
import 'ui/trips/trip_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = TripRepository();
  await repository.load();

  final tracking = TrackingController(repository);
  await tracking.init();

  // If the app was fully closed and the user tapped a trip-completed
  // notification to open it, jump straight to that trip once the UI is up.
  final initialTripId = await NotificationService.instance
      .consumeLaunchTripId();

  runApp(
    MileageTrackerApp(
      repository: repository,
      tracking: tracking,
      initialTripId: initialTripId,
    ),
  );
}

class MileageTrackerApp extends StatefulWidget {
  const MileageTrackerApp({
    super.key,
    required this.repository,
    required this.tracking,
    this.initialTripId,
  });

  final TripRepository repository;
  final TrackingController tracking;
  final int? initialTripId;

  @override
  State<MileageTrackerApp> createState() => _MileageTrackerAppState();
}

class _MileageTrackerAppState extends State<MileageTrackerApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<int>? _tapSubscription;

  @override
  void initState() {
    super.initState();
    _tapSubscription = NotificationService.instance.onTripTapped.listen(
      _openTrip,
    );

    final initialTripId = widget.initialTripId;
    if (initialTripId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openTrip(initialTripId),
      );
    }
  }

  @override
  void dispose() {
    _tapSubscription?.cancel();
    super.dispose();
  }

  void _openTrip(int tripId) {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: tripId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.repository),
        ChangeNotifierProvider.value(value: widget.tracking),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Mileage Tracker',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
