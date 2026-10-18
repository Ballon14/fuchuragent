import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/shared/widgets/confirmation_dialog.dart';

void main() {
  group('CRUD Confirmation Dialog Tests', () {
    testWidgets('showCreateConfirmation renders correct content and handles confirm/cancel', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await ConfirmationDialog.showCreateConfirmation(
                    context: context,
                    title: 'Tambah Pelanggan Baru',
                    itemName: 'PT Inovasi Digital',
                    detail: 'Telepon: 08123456789',
                  );
                },
                child: const Text('Buka Create Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Buka Create Dialog'));
      await tester.pumpAndSettle();

      // Verify widgets
      expect(find.text('Tambah Pelanggan Baru'), findsOneWidget);
      expect(find.text('Apakah Anda yakin ingin menyimpan dan menambahkan "PT Inovasi Digital" ke sistem?'), findsOneWidget);
      expect(find.text('Telepon: 08123456789'), findsOneWidget);
      expect(find.text('Ya, Tambahkan Data'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(result, false);

      // Reopen and confirm
      await tester.tap(find.text('Buka Create Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, Tambahkan Data'));
      await tester.pumpAndSettle();
      expect(result, true);
    });

    testWidgets('showUpdateConfirmation renders correct content and handles confirm/cancel', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await ConfirmationDialog.showUpdateConfirmation(
                    context: context,
                    title: 'Edit Layanan VPS',
                    itemName: 'server.cloud.id',
                    detail: 'Biaya Sewa: Rp 250.000/bln',
                  );
                },
                child: const Text('Buka Update Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Buka Update Dialog'));
      await tester.pumpAndSettle();

      // Verify widgets
      expect(find.text('Edit Layanan VPS'), findsOneWidget);
      expect(find.text('Apakah Anda yakin ingin menyimpan perubahan pada "server.cloud.id"?'), findsOneWidget);
      expect(find.text('Biaya Sewa: Rp 250.000/bln'), findsOneWidget);
      expect(find.text('Ya, Simpan Perubahan'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(result, false);

      // Reopen and confirm
      await tester.tap(find.text('Buka Update Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, Simpan Perubahan'));
      await tester.pumpAndSettle();
      expect(result, true);
    });

    testWidgets('showDeleteConfirmation renders destructive deletion and archive variants', (tester) async {
      bool? deleteResult;
      bool? archiveResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      deleteResult = await ConfirmationDialog.showDeleteConfirmation(
                        context: context,
                        title: 'Hapus Pengeluaran',
                        itemName: 'Pembelian Lisensi cPanel',
                        detail: 'Nominal: Rp 450.000',
                        isArchive: false,
                      );
                    },
                    child: const Text('Buka Delete Dialog'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      archiveResult = await ConfirmationDialog.showDeleteConfirmation(
                        context: context,
                        title: 'Arsipkan Pelanggan',
                        itemName: 'Budi Raharjo',
                        detail: 'Pelanggan tidak lagi aktif',
                        isArchive: true,
                      );
                    },
                    child: const Text('Buka Archive Dialog'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // 1. Test Delete
      await tester.tap(find.text('Buka Delete Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Hapus Pengeluaran'), findsOneWidget);
      expect(find.text('Apakah Anda yakin ingin menghapus "Pembelian Lisensi cPanel" secara permanen?'), findsOneWidget);
      expect(find.text('Nominal: Rp 450.000'), findsOneWidget);
      expect(find.text('Ya, Hapus Data'), findsOneWidget);

      await tester.tap(find.text('Ya, Hapus Data'));
      await tester.pumpAndSettle();
      expect(deleteResult, true);

      // 2. Test Archive
      await tester.tap(find.text('Buka Archive Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Arsipkan Pelanggan'), findsOneWidget);
      expect(find.text('Apakah Anda yakin ingin mengarsipkan "Budi Raharjo"?'), findsOneWidget);
      expect(find.text('Pelanggan tidak lagi aktif'), findsOneWidget);
      expect(find.text('Ya, Arsipkan'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(archiveResult, false);
    });
  });
}
