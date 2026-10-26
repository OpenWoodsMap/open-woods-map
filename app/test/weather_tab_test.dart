import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/map/weather_tab.dart';
import 'package:open_woods_map/weather/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Offline extends WeatherService {
  @override
  Future<WeatherReport> fetch(double latitude, double longitude) async =>
      throw const WeatherUnavailable('Could not reach the weather service.');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeatherTab(
            latitude: 46.5,
            longitude: -81.0,
            service: _Offline(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('legal light still answers when the forecast cannot load', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Could not reach the weather service.'), findsOneWidget);
    expect(find.text('LEGAL LIGHT'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('LEGAL START'), findsOneWidget);
    expect(find.text('SUNSET'), findsOneWidget);
    expect(find.textContaining('needs no connection'), findsOneWidget);
  });

  testWidgets('stepping a day moves legal light off today', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Day after'));
    await tester.pump();
    expect(find.text('Today'), findsNothing);
    await tester.tap(find.byTooltip('Day before'));
    await tester.pump();
    expect(find.text('Today'), findsOneWidget);
  });
}
