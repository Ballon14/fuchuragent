import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/activity_log_model.dart';
import '../../../shared/widgets/app_card.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _categoryFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final auditRepo = ref.watch(auditRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Trail & Log Aktivitas Sistem')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Filter Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Kategori Log:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ...['all', 'FINANCE', 'SERVICES', 'CUSTOMERS', 'SECURITY', 'IMPORT'].map((cat) {
                  final selected = _categoryFilter == cat;
                  return ChoiceChip(
                    label: Text(
                      cat == 'all' ? 'Semua Kategori' : cat,
                      style: TextStyle(fontSize: 11, color: selected ? Colors.black : Colors.white),
                    ),
                    selected: selected,
                    onSelected: (s) {
                      if (s) setState(() => _categoryFilter = cat);
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<List<ActivityLogModel>>(
                stream: auditRepo.watchLogs(categoryFilter: _categoryFilter),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
                  }

                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return const Center(
                      child: Text('Belum ada catatan aktivitas pada kategori ini.', style: TextStyle(color: Colors.white38)),
                    );
                  }

                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final log = logs[idx];
                        return ListTile(
                          leading: const Icon(Icons.history_edu_rounded, color: AppColors.cyan, size: 20),
                          title: Text(log.details, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            'Pelaksana: ${log.actorName} (${log.actorId.substring(0, log.actorId.length > 8 ? 8 : log.actorId.length)}) • ${AppConstants.formatDateTime(log.timestamp)}',
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLightDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              log.category,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.cyan),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
