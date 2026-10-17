import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_card.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impor Data Spreadsheet')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.white38),
                  const SizedBox(height: 20),
                  const Text(
                    'Fitur Impor Spreadsheet Dinonaktifkan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Fitur penarikan data dari Google Spreadsheet sebelumnya hanya bertujuan untuk menyediakan data sampel awal aplikasi dan bukan sebagai fitur operasional harian.\n\nPengelolaan data pelanggan dan layanan VPS kini dilakukan langsung secara mandiri.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.people_alt_rounded, size: 18),
                    label: const Text('Buka Kelola Pelanggan'),
                    onPressed: () => context.go('/customers'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
