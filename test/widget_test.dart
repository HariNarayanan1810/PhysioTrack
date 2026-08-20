import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:physiotrack/main.dart';

void main() {
  testWidgets('shows role choices on startup', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PhysioTrackApp());
    await tester.pump();

    expect(find.text('PhysioTrack'), findsOneWidget);
    expect(find.text('Choose your role'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
    expect(find.text('Patient'), findsOneWidget);
  });
}
