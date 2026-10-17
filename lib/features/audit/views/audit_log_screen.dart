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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

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
                ...['all', 'FINANCE', 'SERVICES', 'CUSTOMERS', 'SECURITY'].map((cat) {
                  final selected = _categoryFilter == cat;
                  return ChoiceChip(
                    label: Text(
                      cat == 'all' ? 'Semua Kategori' : cat,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: selected,
                    selectedColor: primaryColor,
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
                    return Center(child: CircularProgressIndicator(color: primaryColor));
                  }

                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return Center(
                      child: Text(
                        'Belum ada catatan aktivitas pada kategori ini.',
                        style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                      ),
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
                          leading: Icon(Icons.history_edu_rounded, color: primaryColor, size: 20),
                          title: Text(log.details, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            'Pelaksana: ${log.actorName} (${log.actorId.substring(0, log.actorId.length > 8 ? 8 : log.actorId.length)}) • ${AppConstants.formatDateTime(log.timestamp)}',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceLightDark : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            child: Text(
                              log.category,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor),
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
