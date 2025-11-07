import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rajlaxmi_myhub_app/main.dart';

void main() {
  testWidgets('App loads with correct structure', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // ✅ From sim_detect project - Verify main app components
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // ✅ Add your specific app title/text verification based on your actual app
    // Replace these with your actual app's text elements:
    expect(find.text('Rajlaxmi MyHub'), findsOneWidget);
    
    // If you have SIM detection features in your UI, add:
     expect(find.text('SIM Detection'), findsOneWidget);
     expect(find.text('Call Logs'), findsOneWidget);
    
    // If you have other main features, add their text:
    // expect(find.text('Home'), findsOneWidget);
    // expect(find.text('Profile'), findsOneWidget);
  });

  // ✅ Optional: Keep counter test if your app actually has counter functionality
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}