import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/shared/widgets/status_badge.dart';
import 'package:fuchuragent/shared/widgets/stat_card.dart';

void main() {
  group('Widget Tests for Fuchur Agent', () {
    testWidgets('StatusBadge renders active status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'active'),
          ),
        ),
      );

      expect(find.text('AKTIF'), findsOneWidget);
    });

    testWidgets('StatusBadge normalizes "actice" typo to "AKTIF"', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'actice'),
          ),
        ),
      );

      expect(find.text('AKTIF'), findsOneWidget);
    });

    testWidgets('StatusBadge renders paid status as "LUNAS"', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'lunas'),
          ),
        ),
      );

      expect(find.text('LUNAS'), findsOneWidget);
    });

    testWidgets('StatCard displays title and value properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Total Pelanggan',
              value: '19',
              subtitle: '10 Aktif',
              icon: Icons.people,
            ),
          ),
        ),
      );

      expect(find.text('Total Pelanggan'), findsOneWidget);
      expect(find.text('19'), findsOneWidget);
      expect(find.text('10 Aktif'), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
    });
  });
}
