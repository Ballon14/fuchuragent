import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/shared/widgets/app_pagination_bar.dart';

void main() {
  group('AppPaginationBar Widget & Logic Tests', () {
    testWidgets('Renders SizedBox.shrink when totalItems <= itemsPerPage and alwaysShow is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppPaginationBar(
              currentPage: 1,
              totalItems: 8,
              itemsPerPage: 10,
              onPageChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(AppPaginationBar), findsOneWidget);
      expect(find.textContaining('Menampilkan'), findsNothing);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    });

    testWidgets('Renders pagination controls when totalItems > 10', (tester) async {
      int selectedPage = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppPaginationBar(
                  currentPage: selectedPage,
                  totalItems: 25,
                  itemsPerPage: 10,
                  onPageChanged: (newPage) {
                    setState(() => selectedPage = newPage);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify range info: 1-10 of 25
      expect(find.textContaining('1-10'), findsOneWidget);
      expect(find.textContaining('25'), findsOneWidget);

      // Verify page pills (1, 2, 3)
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Tap on page 2
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(selectedPage, equals(2));
      expect(find.textContaining('11-20'), findsOneWidget);
    });

    testWidgets('Next and Previous buttons trigger onPageChanged correctly', (tester) async {
      int selectedPage = 2;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppPaginationBar(
                  currentPage: selectedPage,
                  totalItems: 30,
                  itemsPerPage: 10,
                  onPageChanged: (newPage) {
                    setState(() => selectedPage = newPage);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap Previous button
      await tester.tap(find.text('Sebelumnya'));
      await tester.pumpAndSettle();
      expect(selectedPage, equals(1));

      // Now tap Next button
      await tester.tap(find.text('Berikutnya'));
      await tester.pumpAndSettle();
      expect(selectedPage, equals(2));
    });
  });
}
