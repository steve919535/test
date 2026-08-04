import 'package:flutter_test/flutter_test.dart';

import 'package:mileage_tracker/data/trip_repository.dart';
import 'package:mileage_tracker/main.dart';
import 'package:mileage_tracker/services/tracking_controller.dart';

void main() {
  testWidgets('shows the trips screen with bottom navigation', (
    WidgetTester tester,
  ) async {
    // Built directly (skipping repository.load()/tracking.init()) so the
    // test doesn't need real sqflite/location platform bindings.
    final repository = TripRepository();
    final tracking = TrackingController(repository);

    await tester.pumpWidget(
      MileageTrackerApp(repository: repository, tracking: tracking),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trips'), findsWidgets);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('No trips yet'), findsOneWidget);
  });
}
