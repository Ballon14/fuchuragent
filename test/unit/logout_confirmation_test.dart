import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/shared/widgets/confirmation_dialog.dart';

void main() {
  group('Logout Confirmation Dialog Tests', () {
    testWidgets('ConfirmationDialog renders title, message, detail, and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmationDialog(
              title: 'Keluar dari Akun',
              icon: Icons.logout_rounded,
              message: 'Apakah Anda yakin ingin keluar dari sesi aplikasi Fuchur Agent?',
              detail: 'Anda harus memasukkan email dan kata sandi kembali untuk masuk.',
              confirmText: 'Ya, Keluar Akun',
              cancelText: 'Batal',
              isDestructive: true,
            ),
          ),
        ),
      );

      expect(find.text('Keluar dari Akun'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
      expect(find.text('Apakah Anda yakin ingin keluar dari sesi aplikasi Fuchur Agent?'), findsOneWidget);
      expect(find.text('Anda harus memasukkan email dan kata sandi kembali untuk masuk.'), findsOneWidget);
      expect(find.text('Ya, Keluar Akun'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
    });

    testWidgets('Tapping Batal returns false from show dialog', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await ConfirmationDialog.showLogoutDialog(context);
                },
                child: const Text('Buka Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Keluar dari Akun'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(result, false);
      expect(find.text('Keluar dari Akun'), findsNothing);
    });

    testWidgets('Tapping Ya, Keluar Akun returns true from show dialog', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await ConfirmationDialog.showLogoutDialog(context);
                },
                child: const Text('Buka Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Keluar dari Akun'), findsOneWidget);

      await tester.tap(find.text('Ya, Keluar Akun'));
      await tester.pumpAndSettle();

      expect(result, true);
      expect(find.text('Keluar dari Akun'), findsNothing);
    });
  });
}
