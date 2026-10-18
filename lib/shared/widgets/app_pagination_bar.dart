import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class AppPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onItemsPerPageChanged;
  final List<int> availableItemsPerPage;
  final bool alwaysShow;

  const AppPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalItems,
    this.itemsPerPage = 10,
    required this.onPageChanged,
    this.onItemsPerPageChanged,
    this.availableItemsPerPage = const [10, 20, 50],
    this.alwaysShow = false,
  });

  int get totalPages {
    if (totalItems <= 0) return 1;
    return (totalItems / itemsPerPage).ceil();
  }

  int get startItem {
    if (totalItems <= 0) return 0;
    return (currentPage - 1) * itemsPerPage + 1;
  }

  int get endItem {
    if (totalItems <= 0) return 0;
    final end = currentPage * itemsPerPage;
    return end > totalItems ? totalItems : end;
  }

  List<int> _buildPageList() {
    if (totalPages <= 7) {
      return List.generate(totalPages, (i) => i + 1);
    }

    final pages = <int>[];
    pages.add(1);

    if (currentPage > 3) {
      pages.add(-1); // Ellipsis
    }

    final start = (currentPage - 1).clamp(2, totalPages - 1);
    final end = (currentPage + 1).clamp(2, totalPages - 1);

    for (int i = start; i <= end; i++) {
      if (!pages.contains(i)) {
        pages.add(i);
      }
    }

    if (currentPage < totalPages - 2) {
      pages.add(-2); // Ellipsis
    }

    if (!pages.contains(totalPages)) {
      pages.add(totalPages);
    }

    return pages;
  }

  @override
  Widget build(BuildContext context) {
    if (!alwaysShow && totalItems <= itemsPerPage) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    final containerBg = isDark ? AppColors.surfaceLightDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final textBold = isDark ? Colors.white : const Color(0xFF0F172A);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 680;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 16,
            vertical: isCompact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: containerBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isCompact
              ? _buildMobileLayout(context, primaryColor, textMuted, textBold, borderColor, containerBg)
              : _buildDesktopLayout(context, primaryColor, textMuted, textBold, borderColor, containerBg),
        );
      },
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    Color primaryColor,
    Color textMuted,
    Color textBold,
    Color borderColor,
    Color containerBg,
  ) {
    final pages = _buildPageList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left info + Items per page selector
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.layers_rounded, size: 16, color: primaryColor),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: 'Menampilkan ',
                    style: TextStyle(fontSize: 13, color: textMuted),
                    children: [
                      TextSpan(
                        text: '$startItem-$endItem',
                        style: TextStyle(fontWeight: FontWeight.bold, color: textBold),
                      ),
                      const TextSpan(text: ' dari '),
                      TextSpan(
                        text: '$totalItems',
                        style: TextStyle(fontWeight: FontWeight.bold, color: textBold),
                      ),
                      const TextSpan(text: ' data'),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onItemsPerPageChanged != null) ...[
                const SizedBox(width: 10),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: availableItemsPerPage.contains(itemsPerPage)
                          ? itemsPerPage
                          : availableItemsPerPage.first,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: textMuted),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                      dropdownColor: isDark ? AppColors.surfaceLightDark : Colors.white,
                      items: availableItemsPerPage.map((val) {
                        return DropdownMenuItem(
                          value: val,
                          child: Text('$val / hal'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) onItemsPerPageChanged!(val);
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Right controls
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous button
              _buildNavButton(
                icon: Icons.chevron_left_rounded,
                label: 'Sebelumnya',
                enabled: currentPage > 1,
                onTap: () => onPageChanged(currentPage - 1),
                isDark: isDark,
                borderColor: borderColor,
                primaryColor: primaryColor,
              ),
              const SizedBox(width: 6),

              // Page pills
              ...pages.map((p) {
                if (p < 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('...', style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
                  );
                }

                final isSelected = p == currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => onPageChanged(p),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                              ),
                      ),
                      child: Text(
                        '$p',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(width: 6),
              // Next button
              _buildNavButton(
                icon: Icons.chevron_right_rounded,
                label: 'Berikutnya',
                enabled: currentPage < totalPages,
                onTap: () => onPageChanged(currentPage + 1),
                isDark: isDark,
                borderColor: borderColor,
                primaryColor: primaryColor,
                isTrailingIcon: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    Color primaryColor,
    Color textMuted,
    Color textBold,
    Color borderColor,
    Color containerBg,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Compact info
        Flexible(
          child: Text.rich(
            TextSpan(
              text: '$startItem-$endItem',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textBold),
              children: [
                TextSpan(
                  text: ' / $totalItems data',
                  style: TextStyle(fontWeight: FontWeight.normal, color: textMuted),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Compact navigation + Quick Jump
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (totalPages > 2) ...[
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 20),
                tooltip: 'Halaman Pertama',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              tooltip: 'Sebelumnya',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
            ),
            const SizedBox(width: 2),
            InkWell(
              onTap: totalPages > 1 ? () => _showPagePicker(context, isDark, primaryColor) : null,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$currentPage / $totalPages',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    if (totalPages > 1) ...[
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down, size: 14, color: primaryColor),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              tooltip: 'Berikutnya',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
            ),
            if (totalPages > 2) ...[
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 20),
                tooltip: 'Halaman Terakhir',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: currentPage < totalPages ? () => onPageChanged(totalPages) : null,
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _showPagePicker(BuildContext context, bool isDark, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pilih Halaman',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: totalPages,
                    itemBuilder: (context, index) {
                      final page = index + 1;
                      final isSelected = page == currentPage;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          onPageChanged(page);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? primaryColor : (isDark ? AppColors.surfaceLightDark : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? primaryColor : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Text(
                            '$page',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (onItemsPerPageChanged != null) ...[
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Data per halaman:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Wrap(
                        spacing: 6,
                        children: availableItemsPerPage.map((val) {
                          final isSelected = val == itemsPerPage;
                          return ChoiceChip(
                            label: Text('$val'),
                            selected: isSelected,
                            selectedColor: primaryColor,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (_) {
                              Navigator.pop(ctx);
                              onItemsPerPageChanged!(val);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    required bool isDark,
    required Color borderColor,
    required Color primaryColor,
    bool isTrailingIcon = false,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: enabled
              ? (isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? borderColor : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isTrailingIcon) ...[
              Icon(
                icon,
                size: 16,
                color: enabled
                    ? (isDark ? Colors.white70 : const Color(0xFF475569))
                    : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: enabled
                    ? (isDark ? Colors.white70 : const Color(0xFF475569))
                    : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
              ),
            ),
            if (isTrailingIcon) ...[
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 16,
                color: enabled
                    ? (isDark ? Colors.white70 : const Color(0xFF475569))
                    : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
