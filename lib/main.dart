import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/trip_repository.dart';
import 'services/tracking_controller.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = TripRepository();
  await repository.load();

  final tracking = TrackingController(repository);
  await tracking.init();

  runApp(MileageTrackerApp(repository: repository, tracking: tracking));
}

class MileageTrackerApp extends StatelessWidget {
  const MileageTrackerApp({
    super.key,
    required this.repository,
    required this.tracking,
  });

  final TripRepository repository;
  final TrackingController tracking;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: repository),
        ChangeNotifierProvider.value(value: tracking),
      ],
      child: MaterialApp(
        title: 'Mileage Tracker',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
