import 'package:campus_guide/main.dart';
import 'package:campus_guide/widgets/campus_schematic_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the five main screens and campus quick access', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CampusGuideApp());
    await tester.pumpAndSettle();

    expect(find.text('Campus Map & Location Guide'), findsOneWidget);
    expect(find.text('WELCOME TO YOUR CAMPUS'), findsOneWidget);
    expect(find.text('Quick access'), findsOneWidget);
    expect(find.text('Buildings'), findsOneWidget);
    expect(find.text('Campus highlights'), findsOneWidget);

    for (final section in ['Home', 'Map', 'Search', 'Saved', 'Settings']) {
      expect(find.text(section), findsWidgets);
    }

    await tester.tap(find.text('Buildings').first);
    await tester.pumpAndSettle();
    expect(find.text('Search places'), findsOneWidget);
    expect(find.text('Campus directory'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Library');
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsWidgets);

    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.text('Your saved places will show up here'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Campus visitor'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggles dark mode and saves or deletes a custom place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CampusGuideApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SwitchListTile), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );

    await tester.tap(find.text('Map').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final campusMap = find.byType(CampusSchematicMap);
    final mapRect = tester.getRect(campusMap);
    await tester.tapAt(
      Offset(mapRect.right - 8, mapRect.top + mapRect.height / 2),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Pins can only be added inside the campus boundary.'),
      findsOneWidget,
    );
    await tester.tapAt(
      Offset(
        mapRect.left + mapRect.width / 2,
        mapRect.top + mapRect.height * 0.48,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pin ready · tap Add place to save'), findsOneWidget);
    await tester.tap(find.byTooltip('Add a campus place').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byType(TextFormField).first,
      'North Study Room',
    );
    await tester.tap(find.text('Save place'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('North Study Room'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete North Study Room'));
    await tester.pumpAndSettle();
    expect(find.text('Delete saved place?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('North Study Room'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bookmarks a mapped campus place', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CampusGuideApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Library');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Place details').first);
    await tester.pumpAndSettle();
    expect(find.text('Save place'), findsOneWidget);
    await tester.tap(find.text('Save place'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
