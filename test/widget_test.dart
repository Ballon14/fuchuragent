import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/shared/widgets/status_badge.dart';
import 'package:fuchuragent/shared/widgets/stat_card.dart';
import 'package:fuchuragent/shared/widgets/app_card.dart';

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

    testWidgets('AppCard without header supports Expanded flex children like desktop tables', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Top Header'),
                Expanded(
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Container(height: 40, color: Colors.blue, child: const Text('Table Header')),
                        Expanded(
                          child: ListView.builder(
                            itemCount: 10,
                            itemBuilder: (context, index) => ListTile(
                              title: Text('Customer Row $index'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Table Header'), findsOneWidget);
      expect(find.text('Customer Row 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

